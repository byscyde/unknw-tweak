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

#define kUNKNWNagClassName @"IGCoreRootTestFlightNagPlugin.TestFlightUpdateNudgeViewController"

%group UNKNWBetaBypass

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (![NSStringFromClass([self class]) isEqualToString:kUNKNWNagClassName]) return;

    UNKNWLog(@"beta bypass: dismissing update nag");
    __weak UIViewController *vc = self;
    // Dismiss on the next runloop so we never mutate the view-controller
    // hierarchy from inside the appearance callback.
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *target = vc;
        if (!target) return;
        if (target.presentingViewController) {
            [target.presentingViewController dismissViewControllerAnimated:NO completion:nil];
        } else if (target.navigationController.viewControllers.count > 1) {
            [target.navigationController popViewControllerAnimated:NO];
        } else {
            [target.view removeFromSuperview];
            [target willMoveToParentViewController:nil];
            [target removeFromParentViewController];
        }
    });
}

%end

%end

void UNKNWInitBetaBypass(void) {
    %init(UNKNWBetaBypass);
}
