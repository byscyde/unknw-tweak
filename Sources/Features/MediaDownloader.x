// Media Downloader — original UNKNW implementation.
//
// The hooks add a long-press "save" gesture to Instagram media views. Rather
// than depend on exact, version-specific property names, the URL is found by a
// bounded search of the view's own backing model graph: we walk Instagram's
// model objects (skipping the UIKit view tree) collecting video URLs
// (-allVideoURLs), profile-picture URLs (-HDProfilePicURL) and image-version
// URLs (IGImageURL), then pick the best. The resolved URL is handed to
// UNKNWVault for download + routing to the vault or Photos.

#import "../UNKNW.h"
#import "../Core/UNKNWVault.h"
#import <objc/runtime.h>
#import <objc/message.h>

@interface IGSundialViewerVideoCell : UIView
@end
@interface IGProfilePictureImageView : UIImageView
@end

static const void *kUNKNWDLInstalled = &kUNKNWDLInstalled;

#pragma mark - log + toast

static void UNKNWMDLog(NSString *line) {
    if (!UNKNWPrefBool(kUNKNWDebugLoggingKey, NO)) return;
    NSURL *as = [NSFileManager.defaultManager URLForDirectory:NSApplicationSupportDirectory
                                                     inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    NSURL *dir = [as URLByAppendingPathComponent:@"UNKNW" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *path = [[dir URLByAppendingPathComponent:@"classes.log"] path];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    NSData *d = [[line stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
    if (!fh) { [[line stringByAppendingString:@"\n"] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]; return; }
    @try { [fh seekToEndOfFile]; [fh writeData:d]; } @catch (__unused id e) {} @finally { [fh closeFile]; }
}

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

#pragma mark - safe model-graph search for a media URL

typedef struct { NSMutableArray *videos; NSMutableArray *images; /* @[url,width] */ int budget; } UNKNWScanCtx;

// Keys that may hold a media/model/user object or a collection of them. We only
// ever read these through -valueForKey: (which calls the real getter, so Swift
// lazy-stored properties initialise safely) — never raw object_getIvar, which
// would hand back uninitialised lazy-storage pointers and crash.
static NSArray<NSString *> *UNKNWTraverseKeys(void) {
    static NSArray *keys; static dispatch_once_t once;
    dispatch_once(&once, ^{ keys = @[
        @"mediaInfo", @"mediaPassthrough", @"media", @"video", @"photo", @"image",
        @"items", @"item", @"currentItem", @"currentStoryItem", @"storyItem",
        @"model", @"viewModel", @"post", @"feedItem", @"contentMedia", @"displayMedia",
        @"igMedia", @"reelItem", @"clipsItem", @"user", @"carouselMedia", @"firstItem" ]; });
    return keys;
}

static NSURL *UNKNWCallURL(id obj, NSString *sel) {
    @try {
        SEL s = NSSelectorFromString(sel);
        if (![obj respondsToSelector:s]) return nil;
        id r = ((id (*)(id, SEL))objc_msgSend)(obj, s);
        return [r isKindOfClass:NSURL.class] ? r : nil;
    } @catch (__unused id e) { return nil; }
}

static void UNKNWScan(id obj, UNKNWScanCtx *ctx, NSMutableSet *seen, int depth) {
    if (!obj || depth > 5 || ctx->budget <= 0) return;
    if ([obj isKindOfClass:NSString.class] || [obj isKindOfClass:NSNumber.class] ||
        [obj isKindOfClass:NSData.class]   || [obj isKindOfClass:NSDate.class]   ||
        [obj isKindOfClass:NSURL.class]) return;
    NSValue *k = [NSValue valueWithNonretainedObject:obj];
    if ([seen containsObject:k]) return;
    [seen addObject:k];
    ctx->budget--;

    // Video variant URLs.
    @try {
        SEL s = NSSelectorFromString(@"allVideoURLs");
        if ([obj respondsToSelector:s]) {
            id set = ((id (*)(id, SEL))objc_msgSend)(obj, s);
            if ([set respondsToSelector:@selector(objectEnumerator)])
                for (id u in set) if ([u isKindOfClass:NSURL.class]) [ctx->videos addObject:u];
        }
    } @catch (__unused id e) {}

    // HD profile picture / cover image.
    NSURL *hd = UNKNWCallURL(obj, @"HDProfilePicURL"); if (hd) [ctx->images addObject:@[hd, @(1.0e9)]];
    NSURL *cover = UNKNWCallURL(obj, @"coverImageURL"); if (cover) [ctx->images addObject:@[cover, @(5.0e8)]];

    // Image-version arrays -> IGImageURL (url + width).
    for (NSString *key in @[@"_originalImageVersions", @"originalImageVersions", @"imageVersions", @"candidates"]) {
        @try {
            id arr = [obj valueForKey:key];
            if ([arr respondsToSelector:@selector(objectEnumerator)]) {
                for (id iv in arr) {
                    NSURL *u = nil; double w = 0;
                    @try { id uu = [iv valueForKey:@"url"]; if ([uu isKindOfClass:NSURL.class]) u = uu;
                           id ww = [iv valueForKey:@"width"]; if ([ww respondsToSelector:@selector(doubleValue)]) w = [ww doubleValue]; }
                    @catch (__unused id e) {}
                    if (u) [ctx->images addObject:@[u, @(w)]];
                }
            }
        } @catch (__unused id e) {}
    }

    // Collections.
    if ([obj isKindOfClass:NSArray.class] || [obj isKindOfClass:NSSet.class] || [obj isKindOfClass:NSOrderedSet.class]) {
        for (id e in obj) if (![e isKindOfClass:UIResponder.class]) UNKNWScan(e, ctx, seen, depth + 1);
        return;
    }

    // Follow only the curated keys, via safe KVC getters.
    for (NSString *key in UNKNWTraverseKeys()) {
        if (ctx->budget <= 0) break;
        @try {
            id v = [obj valueForKey:key];
            if (v && ![v isKindOfClass:UIResponder.class]) UNKNWScan(v, ctx, seen, depth + 1);
        } @catch (__unused id e) {}
    }
}

// Resolve the best downloadable URL reachable from `root` (a cell / media view).
static NSURL *UNKNWResolveMediaURL(id root) {
    UNKNWScanCtx ctx; ctx.videos = [NSMutableArray array]; ctx.images = [NSMutableArray array]; ctx.budget = 400;
    UNKNWScan(root, &ctx, [NSMutableSet set], 0);

    // Prefer a video; use the longest URL string as a cheap "best variant".
    NSURL *bestVideo = nil; NSUInteger len = 0;
    for (NSURL *u in ctx.videos) if (u.absoluteString.length >= len) { len = u.absoluteString.length; bestVideo = u; }
    if (bestVideo) return bestVideo;

    // Else the highest-resolution image.
    NSURL *bestImg = nil; double bw = -1;
    for (NSArray *pair in ctx.images) { double w = [pair[1] doubleValue]; if (w >= bw) { bw = w; bestImg = pair[0]; } }
    if (bestImg) return bestImg;

    // Nothing — log the root's ivar names so we can see this version's shape.
    @try {
        NSMutableString *s = [NSMutableString stringWithFormat:@"[media] no url. root=%@ ivars:",
                              NSStringFromClass(object_getClass(root))];
        Class c = object_getClass(root); unsigned n = 0; Ivar *iv = class_copyIvarList(c, &n);
        for (unsigned i = 0; i < n && i < 40; i++) [s appendFormat:@" %s", ivar_getName(iv[i])];
        free(iv);
        UNKNWMDLog(s);
    } @catch (__unused id e) {}
    return nil;
}

static void UNKNWSave(id root) {
    NSURL *url = UNKNWResolveMediaURL(root);
    if (!url) { UNKNWToast(@"No media found"); return; }
    UNKNWToast(@"Downloading…");
    [UNKNWVault.shared downloadURL:url completion:^(BOOL ok, NSError *e){
        UNKNWToast(ok ? @"Saved ✓" : @"Download failed");
    }];
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

%hook IGSundialViewerVideoCell
- (void)didMoveToWindow { %orig; UNKNWAddLongPress(self, @selector(unknw_save:)); }
%new
- (void)unknw_save:(UILongPressGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan) UNKNWSave(self);
}
%end

%hook IGProfilePictureImageView
- (void)didMoveToWindow { %orig; UNKNWAddLongPress(self, @selector(unknw_save:)); }
%new
- (void)unknw_save:(UILongPressGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan) UNKNWSave(self);
}
%end

%end

void UNKNWInitMediaDownloader(void) {
    %init(UNKNWMediaDownloader);
    UNKNWLog(@"media downloader installed (deep resolver)");
}
