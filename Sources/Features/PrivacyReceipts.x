// Privacy — seen receipts.
//
// These features suppress YOUR OWN outbound "seen" signal for stories and DMs,
// and (with kUNKNWManualSeenKey) let you send it yourself with one tap. They
// only affect signals you emit about your own viewing — nothing about other
// people's content is captured or revealed.
//
// IMPLEMENTATION NOTE — fill this in with Developer Logging:
//   Instagram reports "seen" by issuing a network request when you open a story
//   or a DM thread. Find the method that fires that request (watch the call
//   stack / networking layer with Developer Logging) and, in the hook:
//     - if the corresponding hide-toggle is ON, skip %orig (don't report), and
//     - remember the item so the manual-send button can call the original
//       reporting method on demand when kUNKNWManualSeenKey is ON.

#import "../UNKNW.h"

// Interop: the story viewer forwards "this item was seen" to its delegate, which
// is what triggers the outbound seen receipt.
@interface IGStoryViewerViewController_U : UIViewController
- (void)fullscreenSectionController:(id)arg1 didMarkItemAsSeen:(id)arg2;
@end

%group UNKNWHideStorySeen

%hook IGStoryViewerViewController

- (void)fullscreenSectionController:(id)arg1 didMarkItemAsSeen:(id)arg2 {
    // When hiding is on, simply don't propagate the "seen" event, so no receipt
    // is reported for the story you just viewed.
    if (UNKNWPrefBool(kUNKNWHideStorySeenKey, NO)) return;
    %orig;
}

%end

%end

%group UNKNWHideDMSeen

// TODO: %hook the "mark thread/message seen" reporter; skip %orig when
//       UNKNWPrefBool(kUNKNWHideDMSeenKey, NO) is YES.

%end

void UNKNWInitHideStorySeen(void) {
    %init(UNKNWHideStorySeen);
}

void UNKNWInitHideDMSeen(void) {
    %init(UNKNWHideDMSeen);
}
