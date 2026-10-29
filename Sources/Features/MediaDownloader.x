// Media Downloader — original UNKNW implementation.
//
// Adds a long-press "save" gesture to media in Instagram. The media URL is read
// from Instagram's own model objects (their public-in-process Objective-C
// interface: IGMedia / IGVideo / IGPhoto / IGImageURL / IGUser) and handed to
// UNKNWVault, which downloads it and routes it to the vault or the Photos
// library per the user's preferences.
//
// First pass covers reels (IGSundialViewerVideoCell) and profile pictures
// (IGProfilePictureImageView); feed posts and stories are added once this path
// is confirmed on-device.

#import "../UNKNW.h"
#import "../Core/UNKNWVault.h"
#import <objc/runtime.h>

// ---- Instagram class/model interop (shape of the objects we hook/read) ----
@interface IGSundialViewerVideoCell : UIView
@property (readonly, nonatomic) id video; // IGMedia
@end
@interface IGProfilePictureImageView : UIImageView
@property (nonatomic, readonly) id user;  // IGUser
@end
@interface IGUser_U : NSObject
- (NSURL *)HDProfilePicURL;
@end

static const void *kUNKNWDLInstalled = &kUNKNWDLInstalled;

#pragma mark - Toast

static void UNKNWToast(NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if ([s isKindOfClass:UIWindowScene.class]) {
                for (UIWindow *w in ((UIWindowScene *)s).windows) { if (w.isKeyWindow) { win = w; break; } }
            }
            if (win) break;
        }
        if (!win) return;
        UILabel *l = [UILabel new];
        l.text = [@"  UNKNW: " stringByAppendingString:[msg stringByAppendingString:@"  "]];
        l.textColor = UIColor.whiteColor;
        l.backgroundColor = [UIColor colorWithWhite:0 alpha:0.82];
        l.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        l.textAlignment = NSTextAlignmentCenter;
        l.layer.cornerRadius = 16; l.clipsToBounds = YES;
        l.alpha = 0;
        [l sizeToFit];
        CGRect f = l.frame; f.size.height = 32; f.size.width += 16;
        l.frame = f;
        l.center = CGPointMake(win.bounds.size.width/2, win.safeAreaInsets.top + 60);
        [win addSubview:l];
        [UIView animateWithDuration:0.25 animations:^{ l.alpha = 1; } completion:^(BOOL _){
            [UIView animateWithDuration:0.3 delay:1.6 options:0 animations:^{ l.alpha = 0; }
                             completion:^(BOOL __){ [l removeFromSuperview]; }];
        }];
    });
}

#pragma mark - URL resolution from IG models

static NSURL *UNKNWURLFromPhoto(id photo) {
    if (!photo) return nil;
    NSArray *versions = nil;
    @try { versions = [photo valueForKey:@"_originalImageVersions"]; } @catch (__unused id e) {}
    NSURL *best = nil; CGFloat bestW = -1;
    for (id ver in versions) {
        NSURL *u = nil; CGFloat w = 0;
        @try { u = [ver valueForKey:@"url"]; w = [[ver valueForKey:@"width"] doubleValue]; } @catch (__unused id e) {}
        if (u && w >= bestW) { bestW = w; best = u; }
    }
    return best;
}

static NSURL *UNKNWURLFromVideo(id video) {
    if (!video) return nil;
    NSSet *urls = nil;
    @try { urls = [video valueForKey:@"allVideoURLs"]; } @catch (__unused id e) {}
    // Prefer the longest URL string as a cheap "highest variant" heuristic.
    NSURL *best = nil; NSUInteger len = 0;
    for (NSURL *u in urls) { if (u.absoluteString.length >= len) { len = u.absoluteString.length; best = u; } }
    return best;
}

// Resolve the best downloadable URL from an IGMedia / IGPostItem.
static NSURL *UNKNWURLFromMedia(id media) {
    if (!media) return nil;
    id target = media;
    @try {
        NSArray *items = [media valueForKey:@"items"];     // carousel
        if ([items isKindOfClass:NSArray.class] && items.count) target = items.firstObject;
    } @catch (__unused id e) {}
    id video = nil, photo = nil;
    @try { video = [target valueForKey:@"video"]; } @catch (__unused id e) {}
    @try { photo = [target valueForKey:@"photo"]; } @catch (__unused id e) {}
    NSURL *u = UNKNWURLFromVideo(video);
    if (u) return u;
    return UNKNWURLFromPhoto(photo);
}

static void UNKNWSave(NSURL *url) {
    if (!url) { UNKNWToast(@"No media found"); return; }
    UNKNWToast(@"Downloading…");
    [UNKNWVault.shared downloadURL:url completion:^(BOOL ok, NSError *e){
        UNKNWToast(ok ? @"Saved ✓" : @"Download failed");
    }];
}

#pragma mark - Hooks

%group UNKNWMediaDownloader

// Reels / clips viewer cell.
%hook IGSundialViewerVideoCell

- (void)didMoveToWindow {
    %orig;
    if (!self.window || objc_getAssociatedObject(self, kUNKNWDLInstalled)) return;
    objc_setAssociatedObject(self, kUNKNWDLInstalled, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UILongPressGestureRecognizer *lp =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(unknw_saveReel:)];
    lp.minimumPressDuration = 0.65;
    [self addGestureRecognizer:lp];
}

%new
- (void)unknw_saveReel:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    id media = nil;
    @try { media = [self valueForKey:@"video"]; } @catch (__unused id e) {}
    UNKNWSave(UNKNWURLFromMedia(media));
}

%end

// Profile picture — long-press to save the HD version.
%hook IGProfilePictureImageView

- (void)didMoveToWindow {
    %orig;
    if (!self.window || objc_getAssociatedObject(self, kUNKNWDLInstalled)) return;
    objc_setAssociatedObject(self, kUNKNWDLInstalled, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.userInteractionEnabled = YES;
    UILongPressGestureRecognizer *lp =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(unknw_saveDP:)];
    lp.minimumPressDuration = 0.65;
    [self addGestureRecognizer:lp];
}

%new
- (void)unknw_saveDP:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    id user = nil;
    @try { user = [self valueForKey:@"user"]; } @catch (__unused id e) {}
    NSURL *u = nil;
    @try { if ([user respondsToSelector:@selector(HDProfilePicURL)]) u = [user HDProfilePicURL]; } @catch (__unused id e) {}
    UNKNWSave(u);
}

%end

%end

void UNKNWInitMediaDownloader(void) {
    %init(UNKNWMediaDownloader);
    UNKNWLog(@"media downloader installed (reels + profile pic)");
}
