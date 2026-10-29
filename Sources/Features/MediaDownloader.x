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

#pragma mark - bounded model-graph search for a media URL

typedef struct { NSMutableArray *videos; NSMutableArray *images; /* @[url,width] */ int budget; } UNKNWScanCtx;

static double UNKNWCallDouble(id obj, SEL sel) {
    return ((double (*)(id, SEL))objc_msgSend)(obj, sel);
}
static id UNKNWCallId(id obj, SEL sel) {
    return ((id (*)(id, SEL))objc_msgSend)(obj, sel);
}

static void UNKNWScan(id obj, UNKNWScanCtx *ctx, NSMutableSet *seen, int depth) {
    if (!obj || depth > 6 || ctx->budget <= 0) return;
    if ([obj isKindOfClass:NSString.class] || [obj isKindOfClass:NSNumber.class] ||
        [obj isKindOfClass:NSData.class]   || [obj isKindOfClass:NSDate.class]) return;
    NSValue *k = [NSValue valueWithNonretainedObject:obj];
    if ([seen containsObject:k]) return;
    [seen addObject:k];
    ctx->budget--;

    NSString *cn = NSStringFromClass(object_getClass(obj)) ?: @"";

    // Video variant URLs.
    @try {
        SEL s = NSSelectorFromString(@"allVideoURLs");
        if ([obj respondsToSelector:s]) {
            id set = UNKNWCallId(obj, s);
            for (id u in set) if ([u isKindOfClass:NSURL.class]) [ctx->videos addObject:u];
        }
    } @catch (__unused id e) {}

    // HD profile picture.
    @try {
        SEL s = NSSelectorFromString(@"HDProfilePicURL");
        if ([obj respondsToSelector:s]) {
            NSURL *u = UNKNWCallId(obj, s);
            if ([u isKindOfClass:NSURL.class]) [ctx->images addObject:@[u, @(1.0e9)]];
        }
    } @catch (__unused id e) {}

    // An image-version object exposes url (+ width).
    if ([cn containsString:@"ImageURL"] || [cn containsString:@"ImageSpecifier"]) {
        @try {
            SEL su = NSSelectorFromString(@"url");
            NSURL *u = [obj respondsToSelector:su] ? UNKNWCallId(obj, su) : nil;
            double w = 0; SEL sw = NSSelectorFromString(@"width");
            if ([obj respondsToSelector:sw]) w = UNKNWCallDouble(obj, sw);
            if ([u isKindOfClass:NSURL.class]) [ctx->images addObject:@[u, @(w)]];
        } @catch (__unused id e) {}
    }

    // Collections: descend into elements (skip view objects).
    if ([obj isKindOfClass:NSArray.class] || [obj isKindOfClass:NSSet.class] || [obj isKindOfClass:NSOrderedSet.class]) {
        for (id e in obj) if (![e isKindOfClass:UIResponder.class]) UNKNWScan(e, ctx, seen, depth + 1);
        return;
    }
    if ([obj isKindOfClass:NSDictionary.class]) {
        for (id e in ((NSDictionary *)obj).allValues) if (![e isKindOfClass:UIResponder.class]) UNKNWScan(e, ctx, seen, depth + 1);
        return;
    }

    // Walk object-typed ivars (including superclasses), skipping the view tree.
    Class c = object_getClass(obj); int up = 0;
    while (c && c != NSObject.class && up < 5 && ctx->budget > 0) {
        unsigned n = 0; Ivar *ivars = class_copyIvarList(c, &n);
        for (unsigned i = 0; i < n && ctx->budget > 0; i++) {
            const char *t = ivar_getTypeEncoding(ivars[i]);
            if (!t || t[0] != '@') continue;
            @try {
                id v = object_getIvar(obj, ivars[i]);
                if (v && ![v isKindOfClass:UIResponder.class]) UNKNWScan(v, ctx, seen, depth + 1);
            } @catch (__unused id e) {}
        }
        free(ivars);
        c = class_getSuperclass(c); up++;
    }
}

// Resolve the best downloadable URL reachable from `root` (a cell / media view).
static NSURL *UNKNWResolveMediaURL(id root) {
    UNKNWScanCtx ctx; ctx.videos = [NSMutableArray array]; ctx.images = [NSMutableArray array]; ctx.budget = 1200;
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
