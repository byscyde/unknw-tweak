// Preference storage for UNKNW.
//
// On a non-jailbroken (Feather) install the tweak runs inside the host app's
// sandbox, so the simplest reliable store is the host app's own NSUserDefaults.
// Keys are namespaced with "UNKNW." (see UNKNW.h) so they never clash with the
// host app. Values are read live, so a toggle written by the in-app panel is
// visible to any code that reads it on the next access.

#import "UNKNW.h"

static NSUserDefaults *defaults(void) {
    return [NSUserDefaults standardUserDefaults];
}

BOOL UNKNWPrefBool(NSString *key, BOOL defaultValue) {
    id value = [defaults() objectForKey:key];
    return (value == nil) ? defaultValue : [value boolValue];
}

void UNKNWPrefSetBool(NSString *key, BOOL value) {
    [defaults() setBool:value forKey:key];
    [defaults() synchronize];
}

double UNKNWPrefNumber(NSString *key, double defaultValue) {
    id value = [defaults() objectForKey:key];
    return (value == nil) ? defaultValue : [value doubleValue];
}

void UNKNWPrefSetNumber(NSString *key, double value) {
    [defaults() setDouble:value forKey:key];
    [defaults() synchronize];
}

NSString *UNKNWPrefString(NSString *key, NSString *defaultValue) {
    id value = [defaults() objectForKey:key];
    return [value isKindOfClass:[NSString class]] ? value : defaultValue;
}

void UNKNWPrefSetString(NSString *key, NSString *value) {
    if (value) {
        [defaults() setObject:value forKey:key];
    } else {
        [defaults() removeObjectForKey:key];
    }
    [defaults() synchronize];
}
