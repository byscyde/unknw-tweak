// Developer Logging — the starter feature.
//
// When enabled, logs the class name of every view controller as it appears.
// Run `idevicesyslog` (or Console.app) filtered on "[UNKNW]" while you navigate
// Instagram, and you will see the real class names you need in order to hook a
// specific screen when building your own features.
//
// This is the reference implementation of the per-feature pattern:
//   - all hooks live inside a single %group;
//   - a plain C initializer runs %init(group) for that group;
//   - the initializer is declared in UNKNW.h and registered in Features.m.

#import "../UNKNW.h"

%group UNKNWDebugLogging

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    UNKNWLog(@"viewDidAppear → %@", NSStringFromClass([self class]));
}

%end

%end

void UNKNWInitDebugLogging(void) {
    %init(UNKNWDebugLogging);
}
