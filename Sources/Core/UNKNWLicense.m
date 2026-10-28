#import "UNKNWLicense.h"
#import "../UNKNW.h"
#import <UIKit/UIKit.h>

// Change this to your server, or set the UNKNW_SERVER_URL env var.
static NSString *const kDefaultBaseURL = @"https://api.scyde.dev";

@implementation UNKNWLicense {
    NSURLSession *_session;
}

+ (instancetype)shared {
    static UNKNWLicense *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [UNKNWLicense new]; });
    return shared;
}

- (instancetype)init {
    if ((self = [super init])) {
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        NSString *env = NSProcessInfo.processInfo.environment[@"UNKNW_SERVER_URL"];
        _baseURLString = env.length ? env : kDefaultBaseURL;
    }
    return self;
}

- (NSString *)key { return UNKNWPrefString(kUNKNWLicenseKeyKey, nil); }
- (void)setKey:(NSString *)key { UNKNWPrefSetString(kUNKNWLicenseKeyKey, key); }

- (BOOL)isActivated { return UNKNWPrefBool(kUNKNWActivatedKey, NO); }
- (void)setActivatedFlag:(BOOL)value { UNKNWPrefSetBool(kUNKNWActivatedKey, value); }
- (void)refreshOnLaunch { [self refreshStatus:^(BOOL valid, BOOL activated, NSString *message) {}]; }

// Stable per-install id: generated once and persisted. Survives reinstalls only
// via the settings backup; a fresh install gets a new id (and a new activation).
- (NSString *)deviceId {
    NSString *stored = UNKNWPrefString(kUNKNWDeviceIdKey, nil);
    if (stored.length) return stored;
    NSString *generated = [NSUUID UUID].UUIDString;
    UNKNWPrefSetString(kUNKNWDeviceIdKey, generated);
    return generated;
}

- (NSString *)deviceName { return UIDevice.currentDevice.name ?: @"iPhone"; }

#pragma mark - Settings payload

- (NSDictionary *)collectSettings {
    NSDictionary *all = [NSUserDefaults.standardUserDefaults dictionaryRepresentation];
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    for (NSString *k in all) {
        if ([k hasPrefix:@"UNKNW."] &&
            ![k isEqualToString:kUNKNWLicenseKeyKey] && ![k isEqualToString:kUNKNWDeviceIdKey]) {
            settings[k] = all[k];
        }
    }
    return settings;
}

- (void)applySettings:(NSDictionary *)settings {
    if (![settings isKindOfClass:[NSDictionary class]]) return;
    for (NSString *k in settings) {
        if ([k hasPrefix:@"UNKNW."] &&
            ![k isEqualToString:kUNKNWLicenseKeyKey] && ![k isEqualToString:kUNKNWDeviceIdKey]) {
            [NSUserDefaults.standardUserDefaults setObject:settings[k] forKey:k];
        }
    }
    [NSUserDefaults.standardUserDefaults synchronize];
}

#pragma mark - Requests

- (NSMutableURLRequest *)requestForPath:(NSString *)path method:(NSString *)method {
    NSURL *url = [NSURL URLWithString:[self.baseURLString stringByAppendingString:path]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = method;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    return request;
}

- (void)send:(NSURLRequest *)request completion:(void (^)(BOOL ok, NSDictionary *json, NSString *message))completion {
    NSURLSessionDataTask *task = [_session dataTaskWithRequest:request
                                             completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if (![json isKindOfClass:[NSDictionary class]]) json = nil;
        BOOL ok = !error && http.statusCode >= 200 && http.statusCode < 300;
        NSString *message = error.localizedDescription ?: json[@"message"];
        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(ok, json, message); });
    }];
    [task resume];
}

- (void)activateKey:(NSString *)key completion:(void (^)(BOOL, NSString *))completion {
    NSMutableURLRequest *request = [self requestForPath:@"/v1/activate" method:@"POST"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:@{
        @"key": key ?: @"", @"deviceId": self.deviceId, @"deviceName": [self deviceName],
    } options:0 error:nil];
    [self send:request completion:^(BOOL ok, NSDictionary *json, NSString *message) {
        BOOL activated = ok && [json[@"activated"] boolValue];
        if (activated) self.key = key;
        [self setActivatedFlag:activated];
        if (completion) completion(activated, message);
    }];
}

- (void)refreshStatus:(void (^)(BOOL, BOOL, NSString *))completion {
    if (!self.key.length) { if (completion) completion(NO, NO, @"No license key"); return; }
    NSMutableURLRequest *request = [self requestForPath:@"/v1/status" method:@"GET"];
    [request setValue:self.key forHTTPHeaderField:@"X-License-Key"];
    [request setValue:self.deviceId forHTTPHeaderField:@"X-Device-Id"];
    [self send:request completion:^(BOOL ok, NSDictionary *json, NSString *message) {
        BOOL valid = [json[@"valid"] boolValue];
        BOOL activated = [json[@"activated"] boolValue];
        // Only downgrade the cached flag on a definitive server answer, not on a
        // network error, so offline launches don't lock a paid user out.
        if (ok) [self setActivatedFlag:(valid && activated)];
        if (completion) completion(valid, activated, message);
    }];
}

- (void)deactivate:(void (^)(BOOL, NSString *))completion {
    if (!self.key.length) { if (completion) completion(NO, @"No license key"); return; }
    NSMutableURLRequest *request = [self requestForPath:@"/v1/deactivate" method:@"POST"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:@{@"key": self.key, @"deviceId": self.deviceId} options:0 error:nil];
    [self send:request completion:^(BOOL ok, NSDictionary *json, NSString *message) {
        BOOL done = ok && [json[@"ok"] boolValue];
        if (done) [self setActivatedFlag:NO];
        if (completion) completion(done, message);
    }];
}

- (void)backupSettings:(void (^)(BOOL, NSString *))completion {
    if (!self.key.length) { if (completion) completion(NO, @"No license key"); return; }
    NSMutableURLRequest *request = [self requestForPath:@"/v1/settings" method:@"PUT"];
    [request setValue:self.key forHTTPHeaderField:@"X-License-Key"];
    [request setValue:self.deviceId forHTTPHeaderField:@"X-Device-Id"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:@{@"settings": [self collectSettings]} options:0 error:nil];
    [self send:request completion:^(BOOL ok, NSDictionary *json, NSString *message) {
        if (completion) completion(ok, message ?: (ok ? @"Backed up" : @"Backup failed"));
    }];
}

- (void)restoreSettings:(void (^)(BOOL, NSString *))completion {
    if (!self.key.length) { if (completion) completion(NO, @"No license key"); return; }
    NSMutableURLRequest *request = [self requestForPath:@"/v1/settings" method:@"GET"];
    [request setValue:self.key forHTTPHeaderField:@"X-License-Key"];
    [request setValue:self.deviceId forHTTPHeaderField:@"X-Device-Id"];
    [self send:request completion:^(BOOL ok, NSDictionary *json, NSString *message) {
        if (ok) [self applySettings:json[@"settings"]];
        if (completion) completion(ok, message ?: (ok ? @"Restored" : @"Restore failed"));
    }];
}

@end
