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
#import <objc/runtime.h>

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
    if (UNKNWPrefBool(kUNKNWHideStorySeenKey, YES)) return;
    %orig;
}

%end

%end

// Don't send DM read receipts: skip -markLastMessageAsSeen (verified in the IG
// 453 class dump on IGDirectThreadViewFeatureManager (ObjC) and on the Swift
// IGDirectMessageListViewController).
@interface IGDirectThreadViewFeatureManager : NSObject @end

%group UNKNWHideDMSeen

%hook IGDirectThreadViewFeatureManager
- (void)markLastMessageAsSeen {
    if (UNKNWPrefBool(kUNKNWHideDMSeenKey, NO)) return;
    %orig;
}
%end

%end

// Runtime-swizzle -markLastMessageAsSeen on the Swift message-list VC (its name
// is mangled, so %hook can't target it) to also suppress the receipt there.
static void UNKNWSwizzleSwiftMarkSeen(void) {
    Class cls = NSClassFromString(@"IGDirectMessageListViewController.IGDirectMessageListViewController")
             ?: NSClassFromString(@"_TtC33IGDirectMessageListViewController33IGDirectMessageListViewController");
    if (!cls) return;
    SEL sel = @selector(markLastMessageAsSeen);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    IMP orig = method_getImplementation(m);
    IMP wrapper = imp_implementationWithBlock(^(id self_){
        if (UNKNWPrefBool(kUNKNWHideDMSeenKey, NO)) return;
        ((void (*)(id, SEL))orig)(self_, sel);
    });
    method_setImplementation(m, wrapper);
}

void UNKNWInitHideStorySeen(void) {
    %init(UNKNWHideStorySeen);
}

void UNKNWInitHideDMSeen(void) {
    %init(UNKNWHideDMSeen);
    UNKNWSwizzleSwiftMarkSeen();
}
