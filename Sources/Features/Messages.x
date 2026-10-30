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

%group UNKNWDownloadAudioMsg
// TODO: add save action on voice bubble → UNKNWVault downloadURL:.
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
void UNKNWInitDownloadAudioMsg(void) { %init(UNKNWDownloadAudioMsg); }
void UNKNWInitSendAudioFromFile(void){ %init(UNKNWSendAudioFromFile); }
void UNKNWInitConfirmCalls(void)     { %init(UNKNWConfirmCalls); }
