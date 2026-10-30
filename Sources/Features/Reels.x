// Reels.
//
// Reels session limit (a self-control feature): count how many reels you scroll
// through and, after a set number, show a notice and leave the reels viewer.
// Read live from kUNKNWReelsLimitOnKey / kUNKNWReelsLimitCountKey.
//
// Auto-advance (play the next reel automatically when one ends) is not wired:
// IG 453 reels render through a custom Metal player with no catchable
// "did reach end" callback — see docs/INTERNALS.md roadmap.

#import "../UNKNW.h"

@interface IGSundialViewerVideoCell : UIView
@end

static NSInteger gReelsSeenThisSession = 0;
static BOOL gReelsLimitFired = NO;

static UIViewController *UNKNWReelsTopVC(void) {
    UIWindow *win = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
        if ([s isKindOfClass:UIWindowScene.class])
            for (UIWindow *w in ((UIWindowScene *)s).windows) if (w.isKeyWindow) { win = w; break; }
    UIViewController *vc = win.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

%group UNKNWReelsLimit

// Count a reel each time a reel video cell becomes visible; cap the session.
%hook IGSundialViewerVideoCell
- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;                              // only on appearance
    if (!UNKNWPrefBool(kUNKNWReelsLimitOnKey, NO)) return;
    if (gReelsLimitFired) return;
    gReelsSeenThisSession++;
    NSInteger limit = (NSInteger)UNKNWPrefNumber(kUNKNWReelsLimitCountKey, 30);
    if (gReelsSeenThisSession < limit) return;
    gReelsLimitFired = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *top = UNKNWReelsTopVC();
        if (!top) return;
        UIAlertController *a =
            [UIAlertController alertControllerWithTitle:@"Reel limit reached"
                                                message:[NSString stringWithFormat:@"You've watched %ld reels this session.", (long)limit]
                                         preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_){
            // Leave the reels viewer: pop if pushed, else dismiss.
            UINavigationController *nav = top.navigationController;
            if (nav.viewControllers.count > 1) [nav popViewControllerAnimated:YES];
            else [top dismissViewControllerAnimated:YES completion:nil];
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Keep watching" style:UIAlertActionStyleCancel handler:^(UIAlertAction *_){
            gReelsSeenThisSession = 0; gReelsLimitFired = NO;  // reset the counter
        }]];
        [top presentViewController:a animated:YES completion:nil];
    });
}
%end

%end

void UNKNWInitReelsLimit(void) {
    gReelsSeenThisSession = 0;
    gReelsLimitFired = NO;
    %init(UNKNWReelsLimit);
}

// Auto-advance is not wired (no catchable reel-end callback on the Metal player).
void UNKNWInitReelsAutoAdvance(void) { }
