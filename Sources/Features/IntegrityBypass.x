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

// Append a diagnostic line to the UNKNW log shown in the Diagnostics screen.
static void UNKNWDiag(NSString *line) {
    NSURL *as = [NSFileManager.defaultManager URLForDirectory:NSApplicationSupportDirectory
                                                     inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    NSURL *dir = [as URLByAppendingPathComponent:@"UNKNW" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *path = [[dir URLByAppendingPathComponent:@"classes.log"] path];
    NSString *entry = [line stringByAppendingString:@"\n"];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!fh) { [entry writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]; return; }
    @try { [fh seekToEndOfFile]; [fh writeData:[entry dataUsingEncoding:NSUTF8StringEncoding]]; }
    @catch (__unused NSException *e) {} @finally { [fh closeFile]; }
}

%group UNKNWStabilityGuard

// App Group redirect — the real sideload logout cause.
//
// Instagram keeps its logged-in accounts/session in a "shared_bootstrap" inside
// the shared App Group container (group.com.burbn.instagram), so it survives
// relaunch and is shared with the app extensions. A re-signed (sideloaded) app
// cannot claim that App Group, so
// -[NSFileManager containerURLForSecurityApplicationGroupIdentifier:] returns
// nil and Instagram falls back to tmp/ — which is volatile, so the session is
// lost on the next launch (and the nil path trips the string checks that showed
// up as the crash / "Error Domain"). We give it a STABLE per-group directory
// under Application Support when the real container is unavailable, so the
// bootstrap persists across relaunches and login sticks.
%hook NSFileManager

- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier {
    NSURL *real = %orig;
    if (real || !groupIdentifier) return real;
    NSURL *appSupport = [self URLForDirectory:NSApplicationSupportDirectory
                                     inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    if (!appSupport) return nil;
    NSURL *dir = [[appSupport URLByAppendingPathComponent:@"UNKNWAppGroups" isDirectory:YES]
                  URLByAppendingPathComponent:groupIdentifier isDirectory:YES];
    [self createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    static dispatch_once_t once;
    dispatch_once(&once, ^{ UNKNWLog(@"app-group redirect active (session persistence)"); });
    return dir;
}

%end

%hook NSString

- (NSRange)rangeOfString:(NSString *)aString options:(NSStringCompareOptions)mask range:(NSRange)searchRange locale:(NSLocale *)locale {
    if (!aString) {
        // Log the first few contexts so we can see WHAT Instagram is comparing
        // against nil (the value that is populated on an App Store build but nil
        // on a re-signed install) — that is the real root to supply.
        static int n = 0;
        if (n < 12) { n++; NSString *me = (NSString *)self;
            UNKNWDiag([NSString stringWithFormat:@"[nil-guard] receiver=\"%@\"", me.length > 120 ? [me substringToIndex:120] : me]); }
        return NSMakeRange(NSNotFound, 0);
    }
    return %orig;
}

%end

%end

// Capture the exact text of error popups Instagram shows (the "Error Domain"
// alert), which the user cannot read fully on-device.
%group UNKNWErrorDiag

%hook UIAlertController
- (void)setTitle:(NSString *)title {
    if (title.length) UNKNWDiag([NSString stringWithFormat:@"[alert.title] %@", title]);
    %orig;
}
- (void)setMessage:(NSString *)message {
    if (message.length) UNKNWDiag([NSString stringWithFormat:@"[alert.message] %@", message]);
    %orig;
}
%end

%end

void UNKNWInitIntegrityBypass(void) {
    %init(UNKNWStabilityGuard);
    if (UNKNWPrefBool(kUNKNWDebugLoggingKey, NO)) %init(UNKNWErrorDiag);
    UNKNWLog(@"stability guard installed");
}
