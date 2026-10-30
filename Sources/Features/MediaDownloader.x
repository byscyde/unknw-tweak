// Media Downloader — original UNKNW implementation.
//
// Version-independent strategy (the Swift reel/profile models are not reliably
// KVC-introspectable):
//   * Video: record the URL of whatever an AVPlayer is told to play; a
//     long-press on a reel saves that URL via UNKNWVault.
//   * Image: grab the already-rendered UIImage out of the view hierarchy and
//     save it to the vault + Photos.

#import "../UNKNW.h"
#import "../Core/UNKNWVault.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <AVFoundation/AVFoundation.h>

@interface IGSundialViewerVideoCell : UIView
@end
@interface IGSundialViewerCarouselSectionController : NSObject
@end
@interface IGSundialViewerPhotoSectionController : NSObject
@end
@interface IGProfilePictureImageView : UIImageView
@end
@interface IGFeedPhotoView : UIView
@end
@interface IGStoryFullscreenCell : UIView
@end

// Declares the %new save selectors so cross-calls like [self unknw_doSave]
// resolve at compile time (each hooked class supplies its own implementation).
@interface NSObject (UNKNWSave)
- (void)unknw_doSave;
- (void)unknw_save:(UILongPressGestureRecognizer *)g;
- (void)unknw_saveTap:(id)sender;
@end

static const void *kUNKNWDLInstalled  = &kUNKNWDLInstalled;
static const void *kUNKNWBtnInstalled = &kUNKNWBtnInstalled;
static NSURL *gUNKNWLastVideoURL = nil;  // most recently played AV video (fallback)
static id gUNKNWCurrentReelMedia = nil;  // IGMedia of the most-recently-bound reel

// Save-control mode: 0 = button + long-press, 1 = long-press only, 2 = off.
static NSInteger UNKNWDLMode(void) { return (NSInteger)UNKNWPrefNumber(kUNKNWDownloadUIModeKey, 0); }

#pragma mark - toast

static void UNKNWToast(NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
            if ([s isKindOfClass:UIWindowScene.class])
                for (UIWindow *w in ((UIWindowScene *)s).windows) if (w.isKeyWindow) { win = w; break; }
        if (!win) return;
        UILabel *l = [UILabel new];
        l.text = [NSString stringWithFormat:@"  UNKNW: %@  ", msg];
        l.textColor = UIColor.whiteColor;
        l.backgroundColor = [UIColor colorWithWhite:0 alpha:0.82];
        l.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        l.textAlignment = NSTextAlignmentCenter; l.layer.cornerRadius = 16; l.clipsToBounds = YES; l.alpha = 0;
        [l sizeToFit]; CGRect f = l.frame; f.size.height = 32; f.size.width += 16; l.frame = f;
        l.center = CGPointMake(win.bounds.size.width/2, win.safeAreaInsets.top + 60);
        [win addSubview:l];
        [UIView animateWithDuration:0.22 animations:^{ l.alpha = 1; } completion:^(BOOL _){
            [UIView animateWithDuration:0.3 delay:1.5 options:0 animations:^{ l.alpha = 0; }
                             completion:^(BOOL __){ [l removeFromSuperview]; }]; }];
    });
}

#pragma mark - find the playing video URL inside a view's layer subtree

static NSURL *UNKNWURLFromLayer(CALayer *layer, int depth) {
    if (!layer || depth > 8) return nil;
    if ([layer isKindOfClass:AVPlayerLayer.class]) {
        @try {
            AVPlayer *p = ((AVPlayerLayer *)layer).player;
            AVAsset *a = p.currentItem.asset;
            if ([a isKindOfClass:AVURLAsset.class]) {
                NSURL *u = ((AVURLAsset *)a).URL;
                if ([u.scheme hasPrefix:@"http"]) return u;
            }
        } @catch (__unused id e) {}
    }
    for (CALayer *sub in layer.sublayers) { NSURL *u = UNKNWURLFromLayer(sub, depth + 1); if (u) return u; }
    return nil;
}

static NSURL *UNKNWVideoURLInView(UIView *v, int depth) {
    if (!v || depth > 8) return nil;
    NSURL *u = UNKNWURLFromLayer(v.layer, 0);
    if (u) return u;
    for (UIView *sv in v.subviews) { NSURL *r = UNKNWVideoURLInView(sv, depth + 1); if (r) return r; }
    return nil;
}

#pragma mark - save helpers

static void UNKNWSaveVideoURL(NSURL *url) {
    if (!url) { UNKNWToast(@"No video playing"); return; }
    UNKNWToast(@"Downloading…");
    [UNKNWVault.shared downloadURL:url completion:^(BOOL ok, NSError *e){
        UNKNWToast(ok ? @"Saved ✓" : @"Download failed");
    }];
}

// Find the largest rendered UIImage inside a view subtree. Buttons (incl. our
// own save button and IG's small glyph buttons) are skipped so we never grab an
// icon instead of the media.
static UIImage *UNKNWLargestImage(UIView *v, int depth) {
    if (!v || depth > 6 || [v isKindOfClass:UIButton.class]) return nil;
    UIImage *best = nil; CGFloat bestArea = 0;
    if ([v isKindOfClass:UIImageView.class]) {
        UIImage *img = ((UIImageView *)v).image;
        if (img) { best = img; bestArea = img.size.width * img.size.height; }
    }
    for (UIView *sv in v.subviews) {
        UIImage *i = UNKNWLargestImage(sv, depth + 1);
        if (i && i.size.width * i.size.height > bestArea) { bestArea = i.size.width * i.size.height; best = i; }
    }
    return best;
}

static void UNKNWSaveImage(UIImage *image) {
    if (!image) { UNKNWToast(@"No image found"); return; }
    NSData *data = UIImageJPEGRepresentation(image, 0.95) ?: UIImagePNGRepresentation(image);
    if (!data) { UNKNWToast(@"No image found"); return; }
    NSURL *f = [UNKNWVault.shared saveData:data suggestedName:@"image.jpg" error:nil];
    if (!f) { UNKNWToast(@"Download failed"); return; }
    UNKNWToast(@"Saved ✓");
    // Default destination is Photos; export unless the user chose Vault-only.
    if ((NSInteger)UNKNWPrefNumber(kUNKNWMediaDestKey, 1) == 1)
        [UNKNWVault.shared exportToPhotos:f albumName:@"UNKNW" completion:nil];
}

#pragma mark - reel video URL from the IGMedia model (version-robust, ObjC-only)

// IG backs every reel with an IGMedia model object. Unlike the Swift playback
// views (which are not safe to introspect), IGMedia is a plain ObjC model whose
// generated accessors return ObjC objects — safe to call when -respondsToSelector:
// is YES. We never use KVC / raw-ivar reads here, so there is no SIGSEGV path.

static id UNKNWMsgSend(id obj, SEL sel) {
    return ((id (*)(id, SEL))objc_msgSend)(obj, sel);
}

// Is this object an IGMedia-like model (responds to media content accessors)?
static BOOL UNKNWIsMediaModel(id o) {
    return o && ([o respondsToSelector:@selector(videoVersions)] ||
                 [o respondsToSelector:@selector(progressiveDownloadUrl)] ||
                 [o respondsToSelector:NSSelectorFromString(@"imageVersions2")] ||
                 [o respondsToSelector:NSSelectorFromString(@"displayURL")]);
}

// Resolve the IGMedia model from whatever object a bind/responder exposes
// (the object itself, or a reel/section-controller/view-model that wraps it).
static id UNKNWMediaFromObject(id obj) {
    if (!obj) return nil;
    if (UNKNWIsMediaModel(obj)) return obj;
    for (NSString *name in @[@"media", @"currentMedia", @"reelMedia", @"currentItem",
                             @"feedItem", @"item", @"object", @"post", @"activeMedia", @"focusedMedia"]) {
        SEL s = NSSelectorFromString(name);
        if (![obj respondsToSelector:s]) continue;
        @try {
            id m = UNKNWMsgSend(obj, s);
            if (m && m != obj && UNKNWIsMediaModel(m)) return m;
        } @catch (__unused id e) {}
    }
    return nil;
}

static NSURL *UNKNWCoerceURL(id v) {
    if ([v isKindOfClass:NSURL.class]) return v;
    if ([v isKindOfClass:NSString.class] && [(NSString *)v length]) return [NSURL URLWithString:v];
    return nil;
}

// Pull the best downloadable video URL out of an IGMedia model.
static NSURL *UNKNWVideoURLFromMedia(id media) {
    if (!media) return nil;
    @try {
        // 1) A single progressive MP4 — the simplest, no DASH assembly needed.
        if ([media respondsToSelector:@selector(progressiveDownloadUrl)]) {
            NSURL *u = UNKNWCoerceURL(UNKNWMsgSend(media, @selector(progressiveDownloadUrl)));
            if (u) return u;
        }
        if ([media respondsToSelector:@selector(progressiveDownloadURLString)]) {
            NSURL *u = UNKNWCoerceURL(UNKNWMsgSend(media, @selector(progressiveDownloadURLString)));
            if (u) return u;
        }
        // 2) videoVersions — array of qualities; pick the widest.
        if ([media respondsToSelector:@selector(videoVersions)]) {
            id arr = UNKNWMsgSend(media, @selector(videoVersions));
            if ([arr isKindOfClass:NSArray.class] && [arr count]) {
                id best = nil; long bestW = -1;
                for (id ver in (NSArray *)arr) {
                    long w = 0;
                    if ([ver respondsToSelector:@selector(width)])
                        w = ((long (*)(id, SEL))objc_msgSend)(ver, @selector(width));
                    if (w >= bestW) { bestW = w; best = ver; }
                }
                if (!best) best = ((NSArray *)arr).firstObject;
                for (NSString *k in @[@"url", @"URL"]) {
                    SEL s = NSSelectorFromString(k);
                    if ([best respondsToSelector:s]) {
                        NSURL *u = UNKNWCoerceURL(UNKNWMsgSend(best, s));
                        if (u) return u;
                    }
                }
            }
        }
        // 3) DASH-only: log the manifest so we can add assembly later; don't crash.
        for (NSString *k in @[@"videoDashManifest", @"dashManifest"]) {
            SEL s = NSSelectorFromString(k);
            if ([media respondsToSelector:s]) {
                id m = UNKNWMsgSend(media, s);
                if ([m isKindOfClass:NSString.class] && [(NSString *)m length]) {
                    UNKNWDiagLog([NSString stringWithFormat:@"[dl] reel is DASH-only (%@, %lu chars)",
                                  k, (unsigned long)[(NSString *)m length]]);
                    break;
                }
            }
        }
    } @catch (__unused id e) {}
    return nil;
}

// Pull the best downloadable image URL out of an IGMedia model.
static NSURL *UNKNWImageURLFromMedia(id media) {
    if (!media) return nil;
    @try {
        for (NSString *k in @[@"displayURL", @"displayUrl", @"imageURL", @"imageUrl", @"url", @"URL"]) {
            SEL s = NSSelectorFromString(k);
            if ([media respondsToSelector:s]) {
                NSURL *u = UNKNWCoerceURL(UNKNWMsgSend(media, s));
                if (u) return u;
            }
        }
        // imageVersions2 / imageCandidates / candidates → widest candidate → url
        for (NSString *k in @[@"imageVersions2", @"imageCandidates", @"candidates"]) {
            SEL s = NSSelectorFromString(k);
            if (![media respondsToSelector:s]) continue;
            id node = UNKNWMsgSend(media, s);
            // imageVersions2 wraps its candidates under -candidates; unwrap if needed.
            if (node && ![node isKindOfClass:NSArray.class] &&
                [node respondsToSelector:@selector(candidates)])
                node = UNKNWMsgSend(node, @selector(candidates));
            if (![node isKindOfClass:NSArray.class] || ![node count]) continue;
            id best = nil; long bestW = -1;
            for (id c in (NSArray *)node) {
                long w = 0;
                if ([c respondsToSelector:@selector(width)])
                    w = ((long (*)(id, SEL))objc_msgSend)(c, @selector(width));
                if (w >= bestW) { bestW = w; best = c; }
            }
            if (!best) best = ((NSArray *)node).firstObject;
            for (NSString *uk in @[@"url", @"URL"]) {
                SEL us = NSSelectorFromString(uk);
                if ([best respondsToSelector:us]) {
                    NSURL *u = UNKNWCoerceURL(UNKNWMsgSend(best, us));
                    if (u) return u;
                }
            }
        }
    } @catch (__unused id e) {}
    return nil;
}

// Resolve the IGMedia of the item under the finger: ask the live responder
// chain (the reels/story viewer exposes the current item), then the last-bound
// reel. No KVC / Swift-view introspection, so there is no SIGSEGV path.
static id UNKNWCurrentMediaForView(UIView *view) {
    id media = nil;
    for (UIResponder *r = view; r && !media; r = r.nextResponder) {
        for (NSString *name in @[@"currentMedia", @"activeMedia", @"focusedMedia",
                                 @"currentPost", @"currentReel", @"currentItem"]) {
            SEL s = NSSelectorFromString(name);
            if (![r respondsToSelector:s]) continue;
            @try {
                id m = UNKNWMediaFromObject(UNKNWMsgSend(r, s));
                if (m) { media = m; break; }
            } @catch (__unused id e) {}
        }
    }
    if (!media) media = gUNKNWCurrentReelMedia;
    if (media) {
        static dispatch_once_t o; dispatch_once(&o, ^{
            UNKNWDiagLog([NSString stringWithFormat:@"[dl] media class: %@",
                          NSStringFromClass(object_getClass(media))]);
        });
    }
    return media;
}

// Video URL for the reel under the finger (model first, AV capture last).
static NSURL *UNKNWReelVideoURL(UIView *cell) {
    NSURL *u = UNKNWVideoURLFromMedia(UNKNWCurrentMediaForView(cell));
    return u ?: gUNKNWLastVideoURL;
}

#pragma mark - gesture install

static void UNKNWAddLongPress(UIView *v, SEL action) {
    if (!v.window || objc_getAssociatedObject(v, kUNKNWDLInstalled)) return;
    objc_setAssociatedObject(v, kUNKNWDLInstalled, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    v.userInteractionEnabled = YES;
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:v action:action];
    lp.minimumPressDuration = 0.6;
    [v addGestureRecognizer:lp];
}

// A floating circular save button, pinned to a bottom corner of the host view.
static void UNKNWAddSaveButton(UIView *v, SEL action, BOOL leadingCorner) {
    if (!v.window || objc_getAssociatedObject(v, kUNKNWBtnInstalled)) return;
    objc_setAssociatedObject(v, kUNKNWBtnInstalled, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    v.userInteractionEnabled = YES;
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightSemibold];
    [b setImage:[UIImage systemImageNamed:@"arrow.down.circle.fill" withConfiguration:cfg] forState:UIControlStateNormal];
    b.tintColor = UIColor.whiteColor;
    b.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
    b.layer.cornerRadius = 21; b.clipsToBounds = YES;
    b.translatesAutoresizingMaskIntoConstraints = NO;
    [b addTarget:v action:action forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:b];
    UILayoutGuide *g = v.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [b.widthAnchor constraintEqualToConstant:42],
        [b.heightAnchor constraintEqualToConstant:42],
        [b.bottomAnchor constraintEqualToAnchor:g.bottomAnchor constant:-90],
        (leadingCorner ? [b.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:16]
                       : [b.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-16]),
    ]];
}

// Install the chosen save controls on a media view (respecting the mode pref).
// leadingCorner places the button away from the surface's own control rail.
// allowLongPress is NO where a long-press would fight the app's own gesture
// (e.g. the story viewer's hold-to-pause).
static void UNKNWInstallSaveControls(UIView *v, SEL gestureAction, SEL buttonAction,
                                     BOOL leadingCorner, BOOL allowLongPress) {
    NSInteger mode = UNKNWDLMode();
    if (mode == 2) return;                                    // off
    if (allowLongPress) UNKNWAddLongPress(v, gestureAction);  // modes 0 and 1
    if (mode == 0) UNKNWAddSaveButton(v, buttonAction, leadingCorner);
}

#pragma mark - hooks

%group UNKNWMediaDownloader

static void UNKNWNoteVideoURL(NSURL *u, NSString *src) {
    if (![u isKindOfClass:NSURL.class] || ![u.scheme hasPrefix:@"http"]) return;
    gUNKNWLastVideoURL = u;
    static dispatch_once_t o; dispatch_once(&o, ^{ UNKNWDiagLog([NSString stringWithFormat:@"[dl] video via %@", src]); });
}

// Capture the URL of any video asset Instagram loads, regardless of which
// player it renders with.
%hook AVURLAsset
- (instancetype)initWithURL:(NSURL *)URL options:(NSDictionary *)options {
    self = %orig;
    @try { UNKNWNoteVideoURL(URL, @"AVURLAsset"); } @catch (__unused id e) {}
    return self;
}
%end

%hook AVPlayerItem
- (instancetype)initWithURL:(NSURL *)URL {
    self = %orig;
    @try { UNKNWNoteVideoURL(URL, @"AVPlayerItem"); } @catch (__unused id e) {}
    return self;
}
%end

%hook AVPlayer
- (void)replaceCurrentItemWithPlayerItem:(AVPlayerItem *)item {
    %orig;
    @try {
        AVAsset *asset = item.asset;
        if ([asset isKindOfClass:AVURLAsset.class]) UNKNWNoteVideoURL(((AVURLAsset *)asset).URL, @"AVPlayer");
    } @catch (__unused id e) {}
}
%end

// IGListKit binds the reel's model here; stash it as the current reel so a
// long-press can resolve the exact media even if the responder lookup misses.
%hook IGSundialViewerCarouselSectionController
- (void)didUpdateToObject:(id)object {
    %orig;
    @try { id m = UNKNWMediaFromObject(object); if (m) gUNKNWCurrentReelMedia = m; } @catch (__unused id e) {}
}
%end
%hook IGSundialViewerPhotoSectionController
- (void)didUpdateToObject:(id)object {
    %orig;
    @try { id m = UNKNWMediaFromObject(object); if (m) gUNKNWCurrentReelMedia = m; } @catch (__unused id e) {}
}
%end

// Reel — save the playing video (model first, AVPlayer capture last).
%hook IGSundialViewerVideoCell
- (void)didMoveToWindow {
    %orig;
    UNKNWInstallSaveControls(self, @selector(unknw_save:), @selector(unknw_saveTap:), YES, YES);
}
%new
- (void)unknw_doSave {
    NSURL *u = UNKNWReelVideoURL(self) ?: UNKNWVideoURLInView(self, 0);
    UNKNWSaveVideoURL(u);
}
%new
- (void)unknw_save:(UILongPressGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan) [self unknw_doSave];
}
%new
- (void)unknw_saveTap:(id)sender { [self unknw_doSave]; }
%end

// Profile picture — save the full-resolution image (long-press only: a floating
// button would not fit the small avatar).
%hook IGProfilePictureImageView
- (void)didMoveToWindow {
    %orig;
    if (UNKNWDLMode() != 2) UNKNWAddLongPress(self, @selector(unknw_save:));
}
%new
- (void)unknw_doSave {
    // Full-resolution profile picture: prefer the user model's HD URL, then the
    // URL the image view loaded, then fall back to the rendered bitmap.
    NSURL *hd = nil;
    @try {
        if ([self respondsToSelector:@selector(user)]) {
            id user = UNKNWMsgSend(self, @selector(user));
            if (user) {
                SEL hi = NSSelectorFromString(@"hdProfilePicUrlInfo");
                if ([user respondsToSelector:hi]) {
                    id info = UNKNWMsgSend(user, hi);
                    for (NSString *uk in @[@"url", @"URL"]) {
                        SEL us = NSSelectorFromString(uk);
                        if (info && [info respondsToSelector:us]) { NSURL *u = UNKNWCoerceURL(UNKNWMsgSend(info, us)); if (u) { hd = u; break; } }
                    }
                }
                if (!hd) for (NSString *k in @[@"profilePicURL", @"profilePicUrl"]) {
                    SEL s = NSSelectorFromString(k);
                    if ([user respondsToSelector:s]) { NSURL *u = UNKNWCoerceURL(UNKNWMsgSend(user, s)); if (u) { hd = u; break; } }
                }
            }
        }
        if (!hd) for (NSString *k in @[@"imageURL", @"imageUrl", @"currentURL", @"url"]) {
            SEL s = NSSelectorFromString(k);
            if ([self respondsToSelector:s]) { NSURL *u = UNKNWCoerceURL(UNKNWMsgSend(self, s)); if (u) { hd = u; break; } }
        }
    } @catch (__unused id e) {}
    if (hd) { UNKNWSaveVideoURL(hd); return; }  // downloadURL handles images too
    UNKNWSaveImage(UNKNWLargestImage(self, 0));
}
%new
- (void)unknw_save:(UILongPressGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan) [self unknw_doSave];
}
%new
- (void)unknw_saveTap:(id)sender { [self unknw_doSave]; }
%end

// Feed post photo — save the displayed image.
%hook IGFeedPhotoView
- (void)didMoveToWindow {
    %orig;
    UNKNWInstallSaveControls(self, @selector(unknw_save:), @selector(unknw_saveTap:), NO, YES);
}
%new
- (void)unknw_doSave { UNKNWSaveImage(UNKNWLargestImage(self, 0)); }
%new
- (void)unknw_save:(UILongPressGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan) [self unknw_doSave];
}
%new
- (void)unknw_saveTap:(id)sender { [self unknw_doSave]; }
%end

// Story — button only (a long-press would fight the story's hold-to-pause).
// Saves the current story's video if it has one, otherwise the shown image.
%hook IGStoryFullscreenCell
- (void)didMoveToWindow {
    %orig;
    UNKNWInstallSaveControls(self, @selector(unknw_save:), @selector(unknw_saveTap:), YES, NO);
}
%new
- (void)unknw_doSave {
    id media = UNKNWCurrentMediaForView(self);
    NSURL *v = UNKNWVideoURLFromMedia(media) ?: gUNKNWLastVideoURL;
    if (v) { UNKNWSaveVideoURL(v); return; }
    NSURL *img = UNKNWImageURLFromMedia(media);
    if (img) { UNKNWSaveVideoURL(img); return; }  // downloadURL handles images too
    UNKNWSaveImage(UNKNWLargestImage(self, 0));
}
%new
- (void)unknw_save:(UILongPressGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan) [self unknw_doSave];
}
%new
- (void)unknw_saveTap:(id)sender { [self unknw_doSave]; }
%end

%end

void UNKNWInitMediaDownloader(void) {
    %init(UNKNWMediaDownloader);
    UNKNWLog(@"media downloader installed (player-capture + image-grab)");
}
