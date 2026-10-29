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
@interface IGProfilePictureImageView : UIImageView
@end
@interface IGFeedPhotoView : UIView
@end

static const void *kUNKNWDLInstalled = &kUNKNWDLInstalled;
static NSURL *gUNKNWLastVideoURL = nil;  // most recently played video

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

// Try known Instagram video-URL accessors on an object via safe KVC/selectors.
static NSURL *UNKNWURLFromObj(id obj) {
    if (!obj) return nil;
    for (NSString *k in @[@"videoURL", @"url", @"mediaURL", @"playableURL",
                          @"progressiveDownloadURL", @"progressiveDownloadUrl",
                          @"currentVideoURL", @"assetURL", @"contentURL"]) {
        @try {
            id v = [obj valueForKey:k];
            if ([v isKindOfClass:NSURL.class]) return v;
            if ([v isKindOfClass:NSString.class] && [(NSString *)v hasPrefix:@"http"]) return [NSURL URLWithString:v];
        } @catch (__unused id e) {}
    }
    @try { id a = [obj valueForKey:@"asset"]; if ([a isKindOfClass:AVURLAsset.class]) return ((AVURLAsset *)a).URL; } @catch (__unused id e) {}
    @try {
        SEL s = NSSelectorFromString(@"allVideoURLs");
        if ([obj respondsToSelector:s]) {
            id set = ((id (*)(id, SEL))objc_msgSend)(obj, s);
            for (id uu in set) if ([uu isKindOfClass:NSURL.class]) return uu;
        }
    } @catch (__unused id e) {}
    return nil;
}

static UIView *UNKNWFindViewContaining(UIView *root, NSString *needle, int depth) {
    if (!root || depth > 8) return nil;
    if ([NSStringFromClass(object_getClass(root)) containsString:needle]) return root;
    for (UIView *sv in root.subviews) { UIView *r = UNKNWFindViewContaining(sv, needle, depth + 1); if (r) return r; }
    return nil;
}

// Reels use a custom Metal video view (IGSundialModernVideoPlaybackView); the
// URL lives on it or its model, not an AVPlayerLayer.
static NSURL *UNKNWReelVideoURL(UIView *cell) {
    UIView *pv = UNKNWFindViewContaining(cell, @"VideoPlayback", 0) ?: UNKNWFindViewContaining(cell, @"ModernVideo", 0);
    NSURL *u = UNKNWURLFromObj(pv);
    if (u) return u;
    for (NSString *k in @[@"media", @"model", @"viewModel", @"videoModel", @"playbackModel", @"video", @"item", @"mediaInfo", @"dataModel"]) {
        @try { NSURL *r = UNKNWURLFromObj([pv valueForKey:k]); if (r) return r; } @catch (__unused id e) {}
    }
    for (NSString *k in @[@"mediaInfo", @"mediaPassthrough", @"media", @"viewModel", @"itemConfiguration"]) {
        @try {
            id m = [cell valueForKey:k];
            NSURL *r = UNKNWURLFromObj(m); if (r) return r;
            @try { NSURL *r2 = UNKNWURLFromObj([m valueForKey:@"video"]); if (r2) return r2; } @catch (__unused id e) {}
        } @catch (__unused id e) {}
    }
    if (pv) { // diagnostic: real property names of the playback view
        @try {
            NSMutableString *s = [NSMutableString stringWithFormat:@"[dl] playback %@ ivars:", NSStringFromClass(object_getClass(pv))];
            unsigned n = 0; Ivar *iv = class_copyIvarList(object_getClass(pv), &n);
            for (unsigned i = 0; i < n && i < 50; i++) [s appendFormat:@" %s", ivar_getName(iv[i])];
            free(iv); UNKNWDiagLog(s);
        } @catch (__unused id e) {}
    }
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

// Find the largest rendered UIImage inside a view subtree.
static UIImage *UNKNWLargestImage(UIView *v, int depth) {
    if (!v || depth > 6) return nil;
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
    [UNKNWVault.shared exportToPhotos:f albumName:@"UNKNW" completion:nil];
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

%hook IGSundialViewerVideoCell
- (void)didMoveToWindow { %orig; UNKNWAddLongPress(self, @selector(unknw_save:)); }
%new
- (void)unknw_save:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    NSURL *u = UNKNWReelVideoURL(self) ?: UNKNWVideoURLInView(self, 0) ?: gUNKNWLastVideoURL;
    UNKNWSaveVideoURL(u);
}
%end

%hook IGProfilePictureImageView
- (void)didMoveToWindow { %orig; UNKNWAddLongPress(self, @selector(unknw_save:)); }
%new
- (void)unknw_save:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    // Prefer a full-resolution URL over the small rendered thumbnail.
    NSURL *hd = nil;
    for (NSString *key in @[@"overrideProfilePicURL", @"_overrideProfilePicURL", @"animatedImageURL", @"_animatedImageURL"]) {
        @try { id v = [self valueForKey:key]; if ([v isKindOfClass:NSURL.class]) { hd = v; break; } } @catch (__unused id e) {}
    }
    if (hd) { UNKNWSaveVideoURL(hd); return; }  // downloadURL handles images too
    UNKNWSaveImage(UNKNWLargestImage(self, 0));
}
%end

// Feed post photo — long-press to save the displayed image.
%hook IGFeedPhotoView
- (void)didMoveToWindow { %orig; UNKNWAddLongPress(self, @selector(unknw_save:)); }
%new
- (void)unknw_save:(UILongPressGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan) UNKNWSaveImage(UNKNWLargestImage(self, 0));
}
%end

%end

void UNKNWInitMediaDownloader(void) {
    %init(UNKNWMediaDownloader);
    UNKNWLog(@"media downloader installed (player-capture + image-grab)");
}
