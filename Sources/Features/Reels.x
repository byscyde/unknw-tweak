// Reels.
//
// Auto-advance to the next reel when the current one ends, and optionally cap
// how many reels you can scroll in one session (a self-control feature).
// Auto-advance and the limit are independent: the limit is read live from
// kUNKNWReelsLimitOnKey / kUNKNWReelsLimitCountKey.
//
// IMPLEMENTATION NOTE — fill this in with Developer Logging:
//   Auto-advance: hook the reel player's "did reach end" / playback-finished
//     callback and programmatically scroll the reels collection view to the
//     next item.
//   Limit: keep a session counter here; increment it when a new reel becomes
//     visible (hook the cell's willDisplay / page-change). When the counter
//     reaches (NSInteger)UNKNWPrefNumber(kUNKNWReelsLimitCountKey, 30) and
//     kUNKNWReelsLimitOnKey is ON, block further scrolling and show a notice.

#import "../UNKNW.h"

static NSInteger gReelsSeenThisSession __unused = 0; // used by the limit logic once wired

%group UNKNWReelsAutoAdvance

// TODO: %hook the reel playback-finished callback; advance to the next item.
// TODO: %hook the reel "became visible" callback for the session limit.

%end

void UNKNWInitReelsAutoAdvance(void) {
    gReelsSeenThisSession = 0;
    %init(UNKNWReelsAutoAdvance);
}
