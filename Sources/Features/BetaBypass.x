// Bypass the "It's time to update Instagram Beta" gate.
//
// On this build the gate is presented by the Swift class
// IGCoreRootTestFlightNagPlugin.TestFlightUpdateNudgeViewController. Because the
// name contains a dot (a Swift class), we resolve it at runtime and swizzle its
// viewDidAppear: with MSHookMessageEx rather than a compile-time %hook, then
// dismiss/pop it the moment it appears so it never blocks the app.
//
// If a future Instagram version renames the class, update the string below
// (discover it again with Developer Logging / Diagnostics).

#import "../UNKNW.h"

#define kUNKNWNagClassName @"IGCoreRootTestFlightNagPlugin.TestFlightUpdateNudgeViewController"

// Provided by the bundled CydiaSubstrate shim.
extern void MSHookMessageEx(Class cls, SEL sel, IMP imp, IMP *result);

static void (*orig_nag_viewDidAppear)(UIViewController *, SEL, BOOL);

static void unknw_nag_viewDidAppear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_nag_viewDidAppear) orig_nag_viewDidAppear(self, _cmd, animated);
    UNKNWLog(@"beta bypass: dismissing update nag");
    UINavigationController *nav = self.navigationController;
    if (nav && nav.viewControllers.count > 1) {
        [nav popViewControllerAnimated:NO];
    } else {
        [self dismissViewControllerAnimated:NO completion:nil];
    }
}

void UNKNWInitBetaBypass(void) {
    Class cls = NSClassFromString(kUNKNWNagClassName);
    if (!cls) {
        UNKNWLog(@"beta bypass: nag class not found (name may have changed)");
        return;
    }
    MSHookMessageEx(cls, @selector(viewDidAppear:),
                    (IMP)unknw_nag_viewDidAppear, (IMP *)&orig_nag_viewDidAppear);
    UNKNWLog(@"beta bypass installed");
}
