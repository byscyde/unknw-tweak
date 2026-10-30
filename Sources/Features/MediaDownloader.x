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
@interface IGProfileViewController : UIViewController
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
static const void *kUNKNWProfileURL   = &kUNKNWProfileURL;  // last URL a profile-pic view loaded
static id gUNKNWProfileUser = nil;  // the IGUser of the profile currently being viewed
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
    for (NSString *name in @[@"media", @"currentMedia", @"reelMedia", @"currentStoryItem",
                             @"storyItem", @"currentItem", @"currentReel", @"reel",
                             @"feedItem", @"item", @"object", @"post", @"activeMedia", @"focusedMedia"]) {
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
        for (NSString *name in @[@"currentMedia", @"currentStoryItem", @"storyItem",
                                 @"activeMedia", @"focusedMedia", @"currentPost",
                                 @"currentReel", @"currentItem"]) {
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
    } else {
        static dispatch_once_t o2; dispatch_once(&o2, ^{
            NSMutableArray *chain = [NSMutableArray array];
            for (UIResponder *r = view; r && chain.count < 14; r = r.nextResponder)
                [chain addObject:NSStringFromClass(object_getClass(r))];
            UNKNWDiagLog([NSString stringWithFormat:@"[dl] no media; chain: %@", [chain componentsJoinedByString:@" > "]]);
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

// Pump one reader-output's encoded samples into one writer-input (passthrough —
// no decode, so IG's fragmented/HEVC tracks remux fine), then leave the group.
static void UNKNWPump(AVAssetReaderTrackOutput *readerOut, AVAssetWriterInput *writerIn,
                      dispatch_queue_t q, dispatch_group_t group) {
    dispatch_group_enter(group);
    [writerIn requestMediaDataWhenReadyOnQueue:q usingBlock:^{
        while (writerIn.isReadyForMoreMediaData) {
            CMSampleBufferRef buf = [readerOut copyNextSampleBuffer];
            if (buf) {
                BOOL ok = [writerIn appendSampleBuffer:buf];
                CFRelease(buf);
                if (!ok) { [writerIn markAsFinished]; dispatch_group_leave(group); return; }
            } else {
                [writerIn markAsFinished];
                dispatch_group_leave(group);
                return;
            }
        }
    }];
}

// Remux a DASH video file (+ optional audio file) into a standard MP4 the Photos
// library accepts — the same AVAssetReader → copyNextSampleBuffer →
// AVAssetWriterInput technique Regram uses. No re-encode (avoids "Cannot Decode")
// and a clean MP4 container (avoids PHPhotosError 3302).
static void UNKNWMux(NSURL *videoFile, NSURL *audioFile, void (^done)(NSURL *out)) {
    @try {
        AVURLAsset *va = [AVURLAsset assetWithURL:videoFile];
        AVAssetTrack *vt = [va tracksWithMediaType:AVMediaTypeVideo].firstObject;
        if (!vt) { UNKNWDiagLog(@"[dl] remux: no video track"); done(nil); return; }
        AVURLAsset *aa = audioFile ? [AVURLAsset assetWithURL:audioFile] : nil;
        AVAssetTrack *at = [aa tracksWithMediaType:AVMediaTypeAudio].firstObject;

        NSError *err = nil;
        AVAssetReader *vReader = [[AVAssetReader alloc] initWithAsset:va error:&err];
        AVAssetReaderTrackOutput *vOut = [[AVAssetReaderTrackOutput alloc] initWithTrack:vt outputSettings:nil];
        vOut.alwaysCopiesSampleData = NO;
        [vReader addOutput:vOut];

        AVAssetReader *aReader = nil; AVAssetReaderTrackOutput *aOut = nil;
        if (at) {
            aReader = [[AVAssetReader alloc] initWithAsset:aa error:&err];
            aOut = [[AVAssetReaderTrackOutput alloc] initWithTrack:at outputSettings:nil];
            aOut.alwaysCopiesSampleData = NO;
            [aReader addOutput:aOut];
        }

        NSURL *out = [[NSURL fileURLWithPath:NSTemporaryDirectory()]
                      URLByAppendingPathComponent:[NSString stringWithFormat:@"unknw-%@.mp4", NSUUID.UUID.UUIDString]];
        AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:out fileType:AVFileTypeMPEG4 error:&err];
        AVAssetWriterInput *vIn = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:nil
                                   sourceFormatHint:(__bridge CMFormatDescriptionRef)vt.formatDescriptions.firstObject];
        vIn.expectsMediaDataInRealTime = NO;
        vIn.transform = vt.preferredTransform;
        [writer addInput:vIn];
        AVAssetWriterInput *aIn = nil;
        if (at) {
            aIn = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:nil
                   sourceFormatHint:(__bridge CMFormatDescriptionRef)at.formatDescriptions.firstObject];
            aIn.expectsMediaDataInRealTime = NO;
            [writer addInput:aIn];
        }

        if (![vReader startReading] || (aReader && ![aReader startReading]) ||
            ![writer startWriting]) {
            UNKNWDiagLog([NSString stringWithFormat:@"[dl] remux start fail: %@", writer.error.localizedDescription ?: vReader.error.localizedDescription ?: @"?"]);
            done(nil); return;
        }
        [writer startSessionAtSourceTime:kCMTimeZero];

        dispatch_group_t group = dispatch_group_create();
        UNKNWPump(vOut, vIn, dispatch_queue_create("unknw.remux.v", DISPATCH_QUEUE_SERIAL), group);
        if (aIn) UNKNWPump(aOut, aIn, dispatch_queue_create("unknw.remux.a", DISPATCH_QUEUE_SERIAL), group);
        dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [writer finishWritingWithCompletionHandler:^{
                UNKNWDiagLog([NSString stringWithFormat:@"[dl] remux status=%ld err=%@",
                              (long)writer.status, writer.error.localizedDescription ?: @"-"]);
                done(writer.status == AVAssetWriterStatusCompleted ? out : nil);
            }];
        });
    } @catch (__unused id e) { UNKNWDiagLog(@"[dl] remux exception"); done(nil); }
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
        if (!aurl) { UNKNWMux(vfile, nil, ^(NSURL *vout){ UNKNWSaveLocalVideo(vout); }); return; }
        UNKNWFetchToTemp(aurl, @"m4a", @"audio", ^(NSURL *afile){
            UNKNWMux(vfile, afile, ^(NSURL *out){
                if (out) { UNKNWSaveLocalVideo(out); return; }
                // audio remux failed — remux video-only so a clean MP4 still saves
                UNKNWMux(vfile, nil, ^(NSURL *vout){ UNKNWSaveLocalVideo(vout); });
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
// Capture the viewed profile's IGUser so the fullscreen profile-pic viewer
// (a separate Swift VC, not in the avatar's responder chain) can still get the
// HD URL. IGProfileViewController exposes -user.
%hook IGProfileViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    @try { id u = UNKNWMsgSend(self, @selector(user)); if (u) gUNKNWProfileUser = u; } @catch (__unused id e) {}
}
%end

%hook IGProfilePictureImageView
- (void)didMoveToWindow {
    %orig;
    if (UNKNWDLMode() != 2) UNKNWAddLongPress(self, @selector(unknw_save:));
}
// Capture the URL this view loads — in the fullscreen profile-pic viewer that is
// the HD image, the best IG serves.
- (void)setImageURL:(id)url {
    %orig;
    @try { if (url) objc_setAssociatedObject(self, kUNKNWProfileURL, url, OBJC_ASSOCIATION_RETAIN_NONATOMIC); } @catch (__unused id e) {}
}
%new
- (void)unknw_doSave {
    // Full-resolution profile picture. Walk the responder chain (reaches the
    // fullscreen profile viewer) and take the HD URL directly, or via the IGUser.
    NSURL *hd = nil;
    SEL hiSel = NSSelectorFromString(@"hdProfilePicUrlInfo");
    for (UIResponder *r = self; r && !hd; r = r.nextResponder) {
        // profile-specific URL accessors on the responder itself
        for (NSString *k in @[@"hdProfilePicURL", @"profilePicURL", @"profilePicUrl"]) {
            NSURL *u = UNKNWCoerceURL(UNKNWMsgSend(r, NSSelectorFromString(k)));
            if (u) { hd = u; break; }
        }
        if (hd) break;
        id info = UNKNWMsgSend(r, hiSel);
        hd = UNKNWCoerceURL(UNKNWMsgSend(info, @selector(url))) ?: UNKNWCoerceURL(UNKNWMsgSend(info, @selector(URL)));
        if (hd) break;
        // via the user model
        for (NSString *uk in @[@"user", @"displayedUser", @"profileUser", @"currentUser"]) {
            id u = UNKNWMsgSend(r, NSSelectorFromString(uk));
            if (!u) continue;
            hd = UNKNWCoerceURL(UNKNWMsgSend(u, NSSelectorFromString(@"hdProfilePicURL")));
            if (!hd) { id i2 = UNKNWMsgSend(u, hiSel); hd = UNKNWCoerceURL(UNKNWMsgSend(i2, @selector(url))) ?: UNKNWCoerceURL(UNKNWMsgSend(i2, @selector(URL))); }
            if (!hd) hd = UNKNWCoerceURL(UNKNWMsgSend(u, NSSelectorFromString(@"profilePicURL")));
            if (hd) break;
        }
    }
    if (!hd && gUNKNWProfileUser) {  // fullscreen viewer: use the viewed profile's user
        id u = gUNKNWProfileUser;
        hd = UNKNWCoerceURL(UNKNWMsgSend(u, NSSelectorFromString(@"hdProfilePicURL")));
        if (!hd) { id i2 = UNKNWMsgSend(u, hiSel); hd = UNKNWCoerceURL(UNKNWMsgSend(i2, @selector(url))) ?: UNKNWCoerceURL(UNKNWMsgSend(i2, @selector(URL))); }
        if (!hd) hd = UNKNWCoerceURL(UNKNWMsgSend(u, NSSelectorFromString(@"profilePicURL")));
    }
    if (!hd) hd = UNKNWCoerceURL(objc_getAssociatedObject(self, kUNKNWProfileURL));  // URL this view loaded
    UNKNWDiagLog([NSString stringWithFormat:@"[dl] profile hd=%@", hd ? hd.absoluteString : @"NONE"]);
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
    // The cell exposes the current story item via its context (verified from the
    // IG binary): IGStoryFullscreenCell.currentStoryItemContext.storyItem.
    id media = nil;
    @try {
        id ctx = UNKNWMsgSend(self, @selector(currentStoryItemContext));
        id item = UNKNWMsgSend(ctx, @selector(storyItem));
        if (item) media = UNKNWMediaFromObject(item) ?: item;
    } @catch (__unused id e) {}
    if (!media) media = UNKNWCurrentMediaForView(self);
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
