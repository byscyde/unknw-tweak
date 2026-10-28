// UNKNW entry point.
//
// Two responsibilities:
//   1. Always install the gesture that opens the in-app settings panel, so the
//      tweak is controllable even when the master switch is off.
//   2. On load, install the hooks for each feature whose toggle is on.
//
// Feature hooks are grouped (%group) and initialized here via their C
// initializers. logos installs a group's hooks when %init(group) runs, so
// enabling/disabling a feature takes effect on the next app launch.

#import "UNKNW.h"
#import "Features.h"
#import "UNKNWSettingsController.h"

// Declares the %new method below so the compiler sees the selector.
@interface UIWindow (UNKNW)
- (void)unknw_installSettingsGesture;
@end

#pragma mark - Settings gesture (always active)

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    [self unknw_installSettingsGesture];
}

%new
- (void)unknw_installSettingsGesture {
    for (UIGestureRecognizer *existing in self.gestureRecognizers) {
        if ([existing.name isEqualToString:@"UNKNWSettingsGesture"]) {
            return; // already installed on this window
        }
    }
    UILongPressGestureRecognizer *recognizer =
        [[UILongPressGestureRecognizer alloc] initWithTarget:[UNKNWGestureHandler shared]
                                                      action:@selector(handleGesture:)];
    recognizer.numberOfTouchesRequired = 2;   // two-finger ...
    recognizer.minimumPressDuration = 0.8;    // ... long-press opens UNKNW
    recognizer.name = @"UNKNWSettingsGesture";
    [self addGestureRecognizer:recognizer];
}

%end

#pragma mark - Loader

%ctor {
    @autoreleasepool {
        // Install the ungrouped UIWindow hook unconditionally so the settings
        // panel is always reachable.
        %init;

        if (!UNKNWPrefBool(kUNKNWEnabledKey, YES)) {
            UNKNWLog(@"master switch off — settings reachable, no features loaded");
            return;
        }

        NSUInteger loaded = 0;
        for (UNKNWFeature *feature in UNKNWAllFeatures()) {
            if (feature.initializer && UNKNWPrefBool(feature.key, feature.defaultBool)) {
                feature.initializer();
                loaded++;
            }
        }

        UNKNWLog(@"loaded into %@ — %lu/%lu feature(s) active",
                 NSBundle.mainBundle.bundleIdentifier,
                 (unsigned long)loaded,
                 (unsigned long)UNKNWAllFeatures().count);
    }
}
