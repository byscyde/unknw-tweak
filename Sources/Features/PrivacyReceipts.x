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

%group UNKNWHideStorySeen

// TODO: %hook the "mark story seen" reporter; skip %orig when
//       UNKNWPrefBool(kUNKNWHideStorySeenKey, NO) is YES.

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
