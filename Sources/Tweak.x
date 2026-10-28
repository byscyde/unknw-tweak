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
#import "Core/UNKNWLicense.h"

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
    UNKNWGestureHandler *handler = [UNKNWGestureHandler shared];

    // Two-finger long-press anywhere opens the panel (always available).
    UILongPressGestureRecognizer *twoFinger =
        [[UILongPressGestureRecognizer alloc] initWithTarget:handler action:@selector(handleGesture:)];
    twoFinger.numberOfTouchesRequired = 2;
    twoFinger.minimumPressDuration = 0.8;
    twoFinger.name = @"UNKNWSettingsGesture";
    twoFinger.delegate = handler;
    [self addGestureRecognizer:twoFinger];

    // Single-finger long-press on the Home-tab corner also opens the panel. The
    // delegate restricts it to that corner and lets the app's gestures proceed.
    UILongPressGestureRecognizer *homeHold =
        [[UILongPressGestureRecognizer alloc] initWithTarget:handler action:@selector(handleGesture:)];
    homeHold.numberOfTouchesRequired = 1;
    homeHold.minimumPressDuration = 0.6;
    homeHold.name = @"UNKNWHomeGesture";
    homeHold.cancelsTouchesInView = NO;
    homeHold.delegate = handler;
    [self addGestureRecognizer:homeHold];
}

%end

#pragma mark - Loader

%ctor {
    @autoreleasepool {
        // Install the ungrouped UIWindow hook unconditionally so the settings
        // panel is always reachable.
        %init;

        // Refresh license status in the background for the next launch so
        // revocation/expiry propagate (never blocks startup).
        [[UNKNWLicense shared] refreshOnLaunch];

        // Developer Logging is ungated — it's a diagnostic, and it must work
        // before activation (e.g. to capture the beta screen's class name).
        if (UNKNWPrefBool(kUNKNWDebugLoggingKey, NO)) UNKNWInitDebugLogging();

        if (!UNKNWPrefBool(kUNKNWEnabledKey, YES)) {
            UNKNWLog(@"master switch off — settings reachable, no features loaded");
            return;
        }

        // "App Fixes" are enablers that just make the sideloaded app usable
        // (keychain/login, beta gate) — they load regardless of activation.
        // Every other (premium) feature stays locked until a license is active.
        BOOL activated = UNKNWLicense.shared.isActivated;
        NSUInteger loaded = 0;
        for (UNKNWFeature *feature in UNKNWAllFeatures()) {
            if ([feature.key isEqualToString:kUNKNWDebugLoggingKey]) continue; // already loaded
            BOOL isEnabler = [feature.category isEqualToString:@"App Fixes"];
            if (!isEnabler && !activated) continue; // premium gated behind license
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
