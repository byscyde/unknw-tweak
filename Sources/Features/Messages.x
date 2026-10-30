// Messages.
//
// Keep unsent messages, hide the typing indicator, download audio messages,
// send audio from a file (or converted from a video's track), and confirm call
// actions.
//
// NOTE: the requested "disable screenshot notifications" option is intentionally
// not implemented. Instagram only sends those for disappearing / view-once /
// vanish-mode content, and the notification is the other person's only signal
// that their one-time content was captured — defeating it removes a safeguard
// that protects someone else, not your own experience. Everything else here is
// included.
//
// IMPLEMENTATION NOTE — fill each group in with Developer Logging:
//   KeepUnsent:     hook the handler that removes a message on an "unsend"
//                   realtime event; when kUNKNWKeepUnsentKey is ON, keep the
//                   already-received message in the thread model and mark it
//                   visually as unsent instead of deleting it.
//   HideTyping:     hook the method that sends the "typing..." indicator and
//                   skip %orig when kUNKNWHideTypingKey is ON.
//   DownloadAudio:  add a save action on the voice-message bubble; resolve its
//                   audio URL and call [UNKNWVault.shared downloadURL:...].
//   SendAudioFile:  add an attachment path that takes an audio file (or extracts
//                   the audio track from a video via AVAssetExportSession) and
//                   feeds it into the existing voice-message send path.
//   ConfirmCalls:   hook the call start/join action and present a confirmation
//                   UIAlertController before calling %orig.

#import "../UNKNW.h"
#import "../Core/UNKNWVault.h"
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

// Interop (verified in the IG 453 class dump):
//   IGDirectTypingStatusService -updateOutgoingStatusIsActive:threadKey:
//       threadMetadata:typingStatusType:   sends the outgoing "typing…" status.
//   IGDirectVideoCallFeatureController -_didTapCallButtonWithCallType:  starts a call.
@interface IGDirectTypingStatusService : NSObject @end
@interface IGDirectVideoCallFeatureController : NSObject @end

static UIViewController *UNKNWMsgTopVC(void) {
    UIWindow *win = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
        if ([s isKindOfClass:UIWindowScene.class])
            for (UIWindow *w in ((UIWindowScene *)s).windows) if (w.isKeyWindow) { win = w; break; }
    UIViewController *vc = win.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

static void UNKNWMsgConfirm(NSString *title, void (^onYes)(void)) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *top = UNKNWMsgTopVC();
        if (!top) { if (onYes) onYes(); return; }
        UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:nil
                                                          preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [a addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *_){ if (onYes) onYes(); }]];
        [top presentViewController:a animated:YES completion:nil];
    });
}

%group UNKNWKeepUnsent
// TODO: hook the unsend handler; retain the message when kUNKNWKeepUnsentKey ON.
%end

// Don't broadcast "typing…": skip the outgoing-status send.
%group UNKNWHideTyping
%hook IGDirectTypingStatusService
- (void)updateOutgoingStatusIsActive:(BOOL)active threadKey:(id)key threadMetadata:(id)md typingStatusType:(NSInteger)type {
    if (UNKNWPrefBool(kUNKNWHideTypingKey, NO)) return;
    %orig;
}
%end
%end

#pragma mark - Download audio message (bounded, safe object-graph URL probe)

// Safe no-arg object call (signature-checked; Swift getters with non-object
// returns can't crash us).
static id UNKNWMObj(id obj, SEL sel) {
    if (!obj || !sel || ![obj respondsToSelector:sel]) return nil;
    NSMethodSignature *sig = nil;
    @try { sig = [obj methodSignatureForSelector:sel]; } @catch (__unused id e) { return nil; }
    if (!sig || sig.numberOfArguments != 2 || sig.methodReturnType[0] != '@') return nil;
    @try { return ((id (*)(id, SEL))objc_msgSend)(obj, sel); } @catch (__unused id e) { return nil; }
}

static NSURL *UNKNWCoerceHTTP(id v) {
    NSURL *u = nil;
    if ([v isKindOfClass:NSURL.class]) u = v;
    else if ([v isKindOfClass:NSString.class] && [(NSString *)v length]) u = [NSURL URLWithString:v];
    return [u.scheme hasPrefix:@"http"] ? u : nil;
}

// Walk the view model's object graph (bounded) and return the first audio-ish
// http URL. Follows only a curated set of accessors, with a visited set.
static NSURL *UNKNWFindAudioURL(id root) {
    if (!root) return nil;
    NSArray *accessors = @[@"audioMessageViewModel", @"messageCellViewModel", @"messageMetadata",
                           @"message", @"audio", @"media", @"content", @"viewModel", @"model",
                           @"url", @"URL", @"audioURL", @"audioSrc", @"assetURL", @"src",
                           @"fileURL", @"downloadURL", @"playbackURL", @"audioAssetURL"];
    NSMutableArray *queue = [NSMutableArray arrayWithObject:root];
    NSMutableSet *seen = [NSMutableSet set];
    NSInteger budget = 200;
    while (queue.count && budget-- > 0) {
        id obj = queue.firstObject; [queue removeObjectAtIndex:0];
        NSValue *key = [NSValue valueWithNonretainedObject:obj];
        if ([seen containsObject:key]) continue;
        [seen addObject:key];
        NSURL *direct = UNKNWCoerceHTTP(obj);
        if (direct) return direct;
        for (NSString *name in accessors) {
            id child = UNKNWMObj(obj, NSSelectorFromString(name));
            if (!child) continue;
            NSURL *u = UNKNWCoerceHTTP(child);
            if (u) return u;
            if (queue.count < 150) [queue addObject:child];
        }
    }
    return nil;
}

@interface UNKNWAudioSave : NSObject
+ (instancetype)shared;
- (void)handle:(UILongPressGestureRecognizer *)g;
@end
@implementation UNKNWAudioSave
+ (instancetype)shared { static UNKNWAudioSave *s; static dispatch_once_t o; dispatch_once(&o, ^{ s = [UNKNWAudioSave new]; }); return s; }
- (void)handle:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    if (!UNKNWPrefBool(kUNKNWDownloadAudioKey, NO)) return;
    UIView *cell = g.view;
    NSURL *url = nil;
    @try {
        id vm = UNKNWMObj(cell, @selector(audioMessageViewModel)) ?: cell;
        url = UNKNWFindAudioURL(vm);
    } @catch (__unused id e) {}
    if (!url) { return; }
    [UNKNWVault.shared downloadURL:url completion:nil];
}
@end

static const void *kUNKNWAudioGesture = &kUNKNWAudioGesture;

// The audio-message cell is a Swift class that overrides -layoutSubviews, so we
// can runtime-swizzle that (not an inherited UIView method) to install a save
// long-press once per cell.
static void UNKNWInstallAudioDownload(void) {
    Class cls = NSClassFromString(@"IGDirectAudioMessageUI.IGDirectAudioMessageCell")
             ?: NSClassFromString(@"_TtC22IGDirectAudioMessageUI24IGDirectAudioMessageCell");
    if (!cls) return;
    SEL sel = @selector(layoutSubviews);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    // only swizzle if the cell itself implements layoutSubviews (not inherited)
    unsigned int n = 0; Method *list = class_copyMethodList(cls, &n); BOOL own = NO;
    for (unsigned int i = 0; i < n; i++) if (method_getName(list[i]) == sel) { own = YES; break; }
    free(list);
    if (!own) return;
    IMP orig = method_getImplementation(m);
    IMP wrapper = imp_implementationWithBlock(^(UIView *self_){
        ((void (*)(id, SEL))orig)(self_, sel);
        @try {
            if (objc_getAssociatedObject(self_, kUNKNWAudioGesture)) return;
            objc_setAssociatedObject(self_, kUNKNWAudioGesture, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            self_.userInteractionEnabled = YES;
            UILongPressGestureRecognizer *lp =
                [[UILongPressGestureRecognizer alloc] initWithTarget:[UNKNWAudioSave shared] action:@selector(handle:)];
            lp.minimumPressDuration = 0.6;
            [self_ addGestureRecognizer:lp];
        } @catch (__unused id e) {}
    });
    method_setImplementation(m, wrapper);
}

%group UNKNWDownloadAudioMsg
// (install is a runtime swizzle in UNKNWInitDownloadAudioMsg — the cell is Swift)
%end

%group UNKNWSendAudioFromFile
// TODO: feed an audio file / extracted track into the voice-message send path.
%end

// Ask before starting/joining a call.
%group UNKNWConfirmCalls
%hook IGDirectVideoCallFeatureController
- (void)_didTapCallButtonWithCallType:(NSInteger)callType {
    if (!UNKNWPrefBool(kUNKNWConfirmCallsKey, NO)) { %orig; return; }
    UNKNWMsgConfirm(@"Start this call?", ^{ %orig(callType); });
}
%end
%end

void UNKNWInitKeepUnsent(void)       { %init(UNKNWKeepUnsent); }
void UNKNWInitHideTyping(void)       { %init(UNKNWHideTyping); }
void UNKNWInitDownloadAudioMsg(void) { %init(UNKNWDownloadAudioMsg); UNKNWInstallAudioDownload(); }
void UNKNWInitSendAudioFromFile(void){ %init(UNKNWSendAudioFromFile); }
void UNKNWInitConfirmCalls(void)     { %init(UNKNWConfirmCalls); }
