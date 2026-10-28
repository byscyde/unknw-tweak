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

%group UNKNWKeepUnsent
// TODO: hook the unsend handler; retain the message when kUNKNWKeepUnsentKey ON.
%end

%group UNKNWHideTyping
// TODO: hook the typing-indicator sender; skip %orig when kUNKNWHideTypingKey ON.
%end

%group UNKNWDownloadAudioMsg
// TODO: add save action on voice bubble → UNKNWVault downloadURL:.
%end

%group UNKNWSendAudioFromFile
// TODO: feed an audio file / extracted track into the voice-message send path.
%end

%group UNKNWConfirmCalls
// TODO: confirm before %orig of the call start/join action.
%end

void UNKNWInitKeepUnsent(void)       { %init(UNKNWKeepUnsent); }
void UNKNWInitHideTyping(void)       { %init(UNKNWHideTyping); }
void UNKNWInitDownloadAudioMsg(void) { %init(UNKNWDownloadAudioMsg); }
void UNKNWInitSendAudioFromFile(void){ %init(UNKNWSendAudioFromFile); }
void UNKNWInitConfirmCalls(void)     { %init(UNKNWConfirmCalls); }
