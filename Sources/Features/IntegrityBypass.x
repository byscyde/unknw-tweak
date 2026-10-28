// Stability guard — the enabler that keeps a sideloaded (re-signed) Instagram
// from crashing on launch.
//
// The crash is an uncaught NSInvalidArgumentException:
//   -[__StringStorage rangeOfString:options:range:locale:]: nil argument
// thrown from FBSharedFramework config code on a background thread early in
// launch (a value that is populated on an App Store build comes back nil on a
// re-signed install). hasPrefix:/hasSuffix:/rangeOfString: all funnel into
// rangeOfString:options:range:locale:, so guarding that one method against a nil
// search string turns the fatal throw into a harmless "not found" and the app
// keeps running. We only intervene when the argument is nil; every normal call
// is untouched.
//
// (An earlier App Attest / DCAppAttestService bypass was tried here but was NOT
// the crash cause and surfaced a visible "error domain" message at login, so it
// was removed. Proper device-identity handling will come with that subsystem.)

#import "../UNKNW.h"

%group UNKNWStabilityGuard

%hook NSString

- (NSRange)rangeOfString:(NSString *)aString options:(NSStringCompareOptions)mask range:(NSRange)searchRange locale:(NSLocale *)locale {
    if (!aString) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{ UNKNWLog(@"stability guard: swallowed rangeOfString:nil (crash averted)"); });
        return NSMakeRange(NSNotFound, 0);
    }
    return %orig;
}

%end

%end

void UNKNWInitIntegrityBypass(void) {
    %init(UNKNWStabilityGuard);
    UNKNWLog(@"stability guard installed");
}
