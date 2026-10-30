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

// Safe dynamic call. Only invokes a selector that takes NO arguments and
// returns an OBJECT pointer, verified against the method signature first. This
// prevents the uncatchable SIGSEGV from calling a selector whose real return
// type is not `id` (IG's reels/story responders are Swift and expose many
// same-named getters with scalar/struct returns). @try cannot catch that, so
// the pre-check is the actual guard.
static id UNKNWMsgSend(id obj, SEL sel) {
    if (!obj || !sel || ![obj respondsToSelector:sel]) return nil;
    NSMethodSignature *sig = nil;
    @try { sig = [obj methodSignatureForSelector:sel]; } @catch (__unused id e) { return nil; }
    if (!sig || sig.numberOfArguments != 2) return nil;        // self + _cmd only
    const char *rt = sig.methodReturnType;
    if (!rt || rt[0] != '@') return nil;                       // must return an object
    @try { return ((id (*)(id, SEL))objc_msgSend)(obj, sel); } @catch (__unused id e) { return nil; }
}

// Safe scalar call for integer-returning getters (e.g. -width). Returns 0 if the
// selector is absent or does not return an integer type.
static long UNKNWIntCall(id obj, SEL sel) {
    if (![obj respondsToSelector:sel]) return 0;
    NSMethodSignature *sig = nil;
    @try { sig = [obj methodSignatureForSelector:sel]; } @catch (__unused id e) { return 0; }
    if (!sig || sig.numberOfArguments != 2) return 0;
    char r = sig.methodReturnType[0];
    if (r=='q'||r=='l'||r=='i'||r=='s'||r=='c'||r=='Q'||r=='L'||r=='I'||r=='S'||r=='C')
        return ((long (*)(id, SEL))objc_msgSend)(obj, sel);
    return 0;
}

// Is this object an IGMedia-like model (responds to media content accessors)?
static BOOL UNKNWIsMediaModel(id o) {
    return o && ([o respondsToSelector:@selector(videoVersions)] ||
                 [o respondsToSelector:@selector(progressiveDownloadUrl)] ||
                 [o respondsToSelector:NSSelectorFromString(@"imageVersions2")] ||
                 [o respondsToSelector:NSSelectorFromString(@"displayURL")]);
}

// Resolve the IGMedia model from whatever object a bind/responder exposes.
// Recurses up to 2 levels so chains like
// IGStoryViewerViewModel → currentReel (IGReel) → reelMedia (IGMedia) resolve.
static id UNKNWMediaFromObjectDepth(id obj, int depth) {
    if (!obj || depth > 2) return nil;
    if (UNKNWIsMediaModel(obj)) return obj;
    for (NSString *name in @[@"media", @"currentMedia", @"reelMedia", @"currentItem",
                             @"currentReel", @"reel", @"feedItem", @"item", @"object",
                             @"post", @"activeMedia", @"focusedMedia"]) {
        id m = UNKNWMsgSend(obj, NSSelectorFromString(name));
        if (!m || m == obj) continue;
        if (UNKNWIsMediaModel(m)) return m;
        id deeper = UNKNWMediaFromObjectDepth(m, depth + 1);
        if (deeper) return deeper;
    }
    return nil;
}
static id UNKNWMediaFromObject(id obj) { return UNKNWMediaFromObjectDepth(obj, 0); }

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
                    long w = UNKNWIntCall(ver, @selector(width));
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
    } @catch (__unused id e) {}
    return nil;  // likely DASH-only — the caller falls back to UNKNWDashManifest
}

// The DASH manifest (MPD XML) string for a media, if it streams via DASH.
static NSString *UNKNWDashManifest(id media) {
    for (NSString *k in @[@"videoDashManifest", @"dashManifest"]) {
        id m = UNKNWMsgSend(media, NSSelectorFromString(k));
        if ([m isKindOfClass:NSString.class] && [(NSString *)m length]) return m;
    }
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
                long w = UNKNWIntCall(c, @selector(width));
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

#pragma mark - DASH (reels & stories stream as MPEG-DASH, not progressive)

static NSString *UNKNWXMLDecode(NSString *s) {
    return [[[s stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]
                stringByReplacingOccurrencesOfString:@"&#38;" withString:@"&"]
                stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];
}

static NSString *UNKNWRegex1(NSString *pattern, NSString *text, NSRegularExpressionOptions opts) {
    NSError *e = nil;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pattern options:opts error:&e];
    if (!re) return nil;
    NSTextCheckingResult *m = [re firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (!m || m.numberOfRanges < 2) return nil;
    return [text substringWithRange:[m rangeAtIndex:1]];
}

// Highest-bandwidth <BaseURL> from the video or audio AdaptationSet of an MPD.
static NSString *UNKNWBestRepURL(NSString *mpd, BOOL wantVideo) {
    NSError *e = nil;
    NSString *asPat = [NSString stringWithFormat:@"<AdaptationSet[^>]*(?:mimeType|contentType)=\"%@[^\"]*\"[^>]*>(.*?)</AdaptationSet>",
                       wantVideo ? @"video" : @"audio"];
    NSRegularExpression *asRe = [NSRegularExpression regularExpressionWithPattern:asPat
                                 options:NSRegularExpressionDotMatchesLineSeparators error:&e];
    if (!asRe) return nil;
    NSRegularExpression *repRe = [NSRegularExpression regularExpressionWithPattern:@"<Representation([^>]*)>(.*?)</Representation>"
                                  options:NSRegularExpressionDotMatchesLineSeparators error:&e];
    NSString *bestURL = nil; long long bestBW = -1;
    for (NSTextCheckingResult *as in [asRe matchesInString:mpd options:0 range:NSMakeRange(0, mpd.length)]) {
        NSString *body = [mpd substringWithRange:[as rangeAtIndex:1]];
        for (NSTextCheckingResult *rep in [repRe matchesInString:body options:0 range:NSMakeRange(0, body.length)]) {
            NSString *attrs = [body substringWithRange:[rep rangeAtIndex:1]];
            NSString *rbody = [body substringWithRange:[rep rangeAtIndex:2]];
            NSString *base = UNKNWRegex1(@"<BaseURL>([^<]+)</BaseURL>", rbody, 0);
            if (!base.length) continue;
            NSString *bwStr = UNKNWRegex1(@"bandwidth=\"(\\d+)\"", attrs, 0);
            long long bw = bwStr ? bwStr.longLongValue : 0;
            if (bw >= bestBW) { bestBW = bw; bestURL = base; }
        }
    }
    return bestURL.length ? UNKNWXMLDecode(bestURL) : nil;
}

static void UNKNWSaveLocalVideo(NSURL *fileURL) {
    if (!fileURL) { UNKNWToast(@"Download failed"); return; }
    unsigned long long sz = [[NSFileManager.defaultManager attributesOfItemAtPath:fileURL.path error:nil] fileSize];
    if ((NSInteger)UNKNWPrefNumber(kUNKNWMediaDestKey, 1) == 1) {
        [UNKNWVault.shared exportToPhotos:fileURL albumName:@"UNKNW" completion:^(BOOL ok, NSError *e){
            UNKNWDiagLog([NSString stringWithFormat:@"[dl] photos export ok=%d %lluKB err=%@", ok, sz/1024, e.localizedDescription ?: @"-"]);
            UNKNWToast(ok ? @"Saved to Photos ✓" : @"Save failed");
        }];
    } else {
        NSData *d = [NSData dataWithContentsOfURL:fileURL];
        NSURL *v = d ? [UNKNWVault.shared saveData:d suggestedName:@"reel.mp4" error:nil] : nil;
        UNKNWToast(v ? @"Saved to Vault ✓" : @"Save failed");
    }
}

// Download one URL to a temp file.
static void UNKNWFetchToTemp(NSString *urlStr, NSString *ext, NSString *tag, void (^done)(NSURL *file)) {
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) { UNKNWDiagLog([NSString stringWithFormat:@"[dl] %@: bad url", tag]); done(nil); return; }
    NSURLSessionDownloadTask *t = [NSURLSession.sharedSession downloadTaskWithURL:url
        completionHandler:^(NSURL *loc, NSURLResponse *resp, NSError *err){
            long http = [resp isKindOfClass:NSHTTPURLResponse.class] ? (long)((NSHTTPURLResponse *)resp).statusCode : 0;
            if (!loc || err) {
                UNKNWDiagLog([NSString stringWithFormat:@"[dl] %@: fail http=%ld err=%@", tag, http, err.localizedDescription ?: @"?"]);
                done(nil); return;
            }
            NSURL *dst = [[NSURL fileURLWithPath:NSTemporaryDirectory()]
                          URLByAppendingPathComponent:[NSString stringWithFormat:@"unknw-%@.%@", NSUUID.UUID.UUIDString, ext]];
            [NSFileManager.defaultManager removeItemAtURL:dst error:nil];
            NSError *mv = nil;
            [NSFileManager.defaultManager moveItemAtURL:loc toURL:dst error:&mv];
            unsigned long long sz = [[NSFileManager.defaultManager attributesOfItemAtPath:dst.path error:nil] fileSize];
            UNKNWDiagLog([NSString stringWithFormat:@"[dl] %@: http=%ld %lluKB%@", tag, http, sz/1024, mv ? @" MOVE-FAIL" : @""]);
            done(mv ? nil : dst);
        }];
    [t resume];
}

// Mux a video-only file and an audio-only file into one MP4.
static void UNKNWMux(NSURL *videoFile, NSURL *audioFile, void (^done)(NSURL *out)) {
    AVMutableComposition *comp = [AVMutableComposition composition];
    @try {
        AVURLAsset *va = [AVURLAsset assetWithURL:videoFile];
        AVAssetTrack *vt = [va tracksWithMediaType:AVMediaTypeVideo].firstObject;
        if (!vt) { done(nil); return; }
        AVMutableCompositionTrack *cvt = [comp addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        [cvt insertTimeRange:CMTimeRangeMake(kCMTimeZero, va.duration) ofTrack:vt atTime:kCMTimeZero error:nil];
        cvt.preferredTransform = vt.preferredTransform;
        if (audioFile) {
            AVURLAsset *aa = [AVURLAsset assetWithURL:audioFile];
            AVAssetTrack *at = [aa tracksWithMediaType:AVMediaTypeAudio].firstObject;
            if (at) {
                AVMutableCompositionTrack *cat = [comp addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
                [cat insertTimeRange:CMTimeRangeMake(kCMTimeZero, va.duration) ofTrack:at atTime:kCMTimeZero error:nil];
            }
        }
    } @catch (__unused id e) { done(nil); return; }
    NSURL *out = [[NSURL fileURLWithPath:NSTemporaryDirectory()]
                  URLByAppendingPathComponent:[NSString stringWithFormat:@"unknw-%@.mp4", NSUUID.UUID.UUIDString]];
    AVAssetExportSession *ex = [[AVAssetExportSession alloc] initWithAsset:comp presetName:AVAssetExportPresetPassthrough];
    ex.outputURL = out; ex.outputFileType = AVFileTypeMPEG4; ex.shouldOptimizeForNetworkUse = YES;
    [ex exportAsynchronouslyWithCompletionHandler:^{
        UNKNWDiagLog([NSString stringWithFormat:@"[dl] mux status=%ld err=%@",
                      (long)ex.status, ex.error.localizedDescription ?: @"-"]);
        done(ex.status == AVAssetExportSessionStatusCompleted ? out : nil);
    }];
}

// Parse the MPD, download the best video (+audio), mux, and save.
static void UNKNWDownloadDASH(NSString *mpd) {
    NSString *vurl = UNKNWBestRepURL(mpd, YES);
    NSString *aurl = UNKNWBestRepURL(mpd, NO);
    UNKNWDiagLog([NSString stringWithFormat:@"[dl] dash v=%@ a=%@", vurl ? @"yes" : @"no", aurl ? @"yes" : @"no"]);
    if (!vurl) { UNKNWToast(@"No video playing"); return; }
    UNKNWToast(@"Downloading…");
    UNKNWFetchToTemp(vurl, @"mp4", @"video", ^(NSURL *vfile){
        if (!vfile) { UNKNWToast(@"Download failed"); return; }
        if (!aurl) { UNKNWSaveLocalVideo(vfile); return; }
        UNKNWFetchToTemp(aurl, @"m4a", @"audio", ^(NSURL *afile){
            UNKNWMux(vfile, afile, ^(NSURL *out){
                UNKNWSaveLocalVideo(out ?: vfile);  // fall back to video-only on mux failure
            });
        });
    });
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

// (The reel/story model is captured for gUNKNWCurrentReelMedia by the broad
// didUpdateToObject: bind swizzle in UNKNWInstallBindDiagnostics below, which
// covers every Sundial/Reel/Clips/Story section controller.)

// Reel — save the playing video (model first, AVPlayer capture last).
%hook IGSundialViewerVideoCell
- (void)didMoveToWindow {
    %orig;
    UNKNWInstallSaveControls(self, @selector(unknw_save:), @selector(unknw_saveTap:), YES, YES);
}
%new
- (void)unknw_doSave {
    id media = UNKNWCurrentMediaForView(self);
    NSURL *u = UNKNWVideoURLFromMedia(media);
    if (u) { UNKNWSaveVideoURL(u); return; }                 // progressive / versioned
    NSString *mpd = UNKNWDashManifest(media);
    if (mpd.length) { UNKNWDownloadDASH(mpd); return; }       // DASH (reels default)
    UNKNWSaveVideoURL(UNKNWVideoURLInView(self, 0) ?: gUNKNWLastVideoURL);
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
    // Full-resolution profile picture: find the IGUser (on the view or up the
    // responder chain) and take its HD profile-pic URL — the largest IG serves.
    NSURL *hd = nil;
    SEL hiSel = NSSelectorFromString(@"hdProfilePicUrlInfo");
    SEL hdSel = NSSelectorFromString(@"hdProfilePicURL");
    id user = nil;
    for (UIResponder *r = self; r && !user; r = r.nextResponder) {
        for (NSString *uk in @[@"user", @"displayedUser", @"profileUser", @"currentUser", @"account"]) {
            id u = UNKNWMsgSend(r, NSSelectorFromString(uk));
            if (u && ([u respondsToSelector:hiSel] || [u respondsToSelector:hdSel])) { user = u; break; }
        }
    }
    if (user) {
        hd = UNKNWCoerceURL(UNKNWMsgSend(user, hdSel));
        if (!hd) {
            id info = UNKNWMsgSend(user, hiSel);
            hd = UNKNWCoerceURL(UNKNWMsgSend(info, @selector(url)))
              ?: UNKNWCoerceURL(UNKNWMsgSend(info, @selector(URL)));
        }
        if (!hd) hd = UNKNWCoerceURL(UNKNWMsgSend(user, NSSelectorFromString(@"profilePicURL")));
        UNKNWDiagLog([NSString stringWithFormat:@"[dl] profile user=%@ hd=%@",
                      NSStringFromClass(object_getClass(user)), hd ? @"yes" : @"no"]);
    } else {
        UNKNWDiagLog(@"[dl] profile: no user in responder chain");
    }
    if (!hd) for (NSString *k in @[@"imageURL", @"imageUrl", @"currentURL", @"url"]) {
        NSURL *u = UNKNWCoerceURL(UNKNWMsgSend(self, NSSelectorFromString(k)));
        if (u) { hd = u; break; }
    }
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
    NSURL *v = UNKNWVideoURLFromMedia(media);
    if (v) { UNKNWSaveVideoURL(v); return; }
    NSString *mpd = UNKNWDashManifest(media);
    if (mpd.length) { UNKNWDownloadDASH(mpd); return; }       // story video (DASH)
    NSURL *img = UNKNWImageURLFromMedia(media);
    if (img) { UNKNWSaveVideoURL(img); return; }              // story photo (downloadURL handles images)
    if (gUNKNWLastVideoURL) { UNKNWSaveVideoURL(gUNKNWLastVideoURL); return; }
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

// Diagnostic (only with Developer Logging on): log which section controllers
// bind which model classes for reels/story, so we can target the exact classes
// that back the visible reel/story. Also captures the bound model as the current
// reel media (safe — only logs class names, never introspects the object).
static void UNKNWInstallBindDiagnostics(void) {
    SEL sel = @selector(didUpdateToObject:);
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    if (!classes) return;
    static NSMutableSet *seen; static dispatch_once_t so; dispatch_once(&so, ^{ seen = [NSMutableSet set]; });
    for (unsigned int i = 0; i < classCount; i++) {
        Class cls = classes[i];
        const char *cnamec = class_getName(cls);
        if (!cnamec) continue;
        NSString *cname = @(cnamec);
        if (!([cname containsString:@"Sundial"] || [cname containsString:@"Reel"] ||
              [cname containsString:@"Clips"]   || [cname containsString:@"Story"]))
            continue;
        unsigned int mc = 0; Method *methods = class_copyMethodList(cls, &mc);
        if (!methods) continue;
        Method target = NULL;
        for (unsigned int j = 0; j < mc; j++) if (method_getName(methods[j]) == sel) { target = methods[j]; break; }
        free(methods);
        if (!target) continue;
        IMP orig = method_getImplementation(target);
        IMP wrapper = imp_implementationWithBlock(^(id self_, id object) {
            ((void (*)(id, SEL, id))orig)(self_, sel, object);
            @try {
                id m = UNKNWMediaFromObject(object);
                if (m) gUNKNWCurrentReelMedia = m;
                NSString *key = [NSString stringWithFormat:@"%@|%@",
                                 NSStringFromClass(object_getClass(self_)),
                                 object ? NSStringFromClass(object_getClass(object)) : @"nil"];
                @synchronized (seen) {
                    if (![seen containsObject:key]) {
                        [seen addObject:key];
                        UNKNWDiagLog([NSString stringWithFormat:@"[bind] %@ <- %@%@", key,
                                      m ? @"media:" : @"", m ? NSStringFromClass(object_getClass(m)) : @""]);
                    }
                }
            } @catch (__unused id e) {}
        });
        method_setImplementation(target, wrapper);
    }
    free(classes);
    UNKNWDiagLog(@"[bind] diagnostics installed");
}

void UNKNWInitMediaDownloader(void) {
    %init(UNKNWMediaDownloader);
    UNKNWInstallBindDiagnostics();
    UNKNWLog(@"media downloader installed (player-capture + image-grab)");
}
