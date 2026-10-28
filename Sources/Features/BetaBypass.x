// Bypass the "It's time to update Instagram Beta" gate.
//
// The gate is the Swift class
// IGCoreRootTestFlightNagPlugin.TestFlightUpdateNudgeViewController. That class
// is registered lazily, so resolving it at %ctor can miss it. Instead we hook
// the base UIViewController's viewDidAppear: (always available) and, whenever
// the controller that appeared is the nag, dismiss/pop/remove it immediately so
// it never blocks the app. A plain string compare per appearance is cheap.
//
// If a future Instagram version renames the class, update the string (rediscover
// with Developer Logging / the Diagnostics screen).

#import "../UNKNW.h"

// The gate is the Swift class
// IGCoreRootTestFlightNagPlugin.TestFlightUpdateNudgeViewController. We match by
// a substring ("TestFlightUpdateNudge") so a namespace/suffix rename still hits.
static BOOL UNKNWIsNag(UIViewController *vc) {
    if (!vc) return NO;
    NSString *name = NSStringFromClass([vc class]);
    if ([name containsString:@"TestFlightUpdateNudge"] ||
        [name containsString:@"TestFlightNag"]) return YES;
    // A container (nav/bottom-sheet) that wraps the nag counts too.
    for (UIViewController *child in vc.childViewControllers) {
        NSString *cn = NSStringFromClass([child class]);
        if ([cn containsString:@"TestFlightUpdateNudge"] || [cn containsString:@"TestFlightNag"]) return YES;
    }
    return NO;
}

static void UNKNWKillNag(UIViewController *target) {
    if (!target) return;
    UNKNWLog(@"beta bypass: killing update nag (%@)", NSStringFromClass([target class]));
    if (target.presentingViewController) {
        [target.presentingViewController dismissViewControllerAnimated:NO completion:nil];
    } else if (target.navigationController.viewControllers.count > 1) {
        [target.navigationController popViewControllerAnimated:NO];
    } else {
        UIWindow *w = target.view.window;
        [target.view removeFromSuperview];
        [target willMoveToParentViewController:nil];
        [target removeFromParentViewController];
        // If it sits on its own overlay window (it is that window's root), hide
        // the window so it cannot keep covering the app.
        if (w && w.rootViewController == target) { w.hidden = YES; }
    }
}

%group UNKNWBetaBypass

%hook UIViewController

// Primary: never present the nag in the first place.
- (void)presentViewController:(UIViewController *)vc animated:(BOOL)flag completion:(void (^)(void))completion {
    if (UNKNWIsNag(vc)) {
        UNKNWLog(@"beta bypass: blocked presentation of update nag");
        if (completion) completion();
        return;
    }
    %orig;
}

// Earliest backstop: hide it before it is drawn, then remove on the next loop.
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (!UNKNWIsNag(self)) return;
    self.view.hidden = YES;
    __weak UIViewController *vc = self;
    dispatch_async(dispatch_get_main_queue(), ^{ UNKNWKillNag(vc); });
}

// Final backstop: if it appeared anyway (added as a child/overlay), remove it.
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!UNKNWIsNag(self)) return;
    __weak UIViewController *vc = self;
    dispatch_async(dispatch_get_main_queue(), ^{ UNKNWKillNag(vc); });
}

%end

%end

void UNKNWInitBetaBypass(void) {
    %init(UNKNWBetaBypass);
}
