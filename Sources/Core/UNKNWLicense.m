#import "UNKNWLicense.h"
#import "../UNKNW.h"

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
        _session = [NSURLSession sessionWithConfiguration:
                    [NSURLSessionConfiguration defaultSessionConfiguration]];
        NSString *env = NSProcessInfo.processInfo.environment[@"UNKNW_SERVER_URL"];
        _baseURLString = env.length ? env : kDefaultBaseURL;
    }
    return self;
}

- (NSString *)key {
    return UNKNWPrefString(kUNKNWLicenseKeyKey, nil);
}

- (void)setKey:(NSString *)key {
    UNKNWPrefSetString(kUNKNWLicenseKeyKey, key);
}

#pragma mark - Settings payload

// Collect every UNKNW.* preference into a JSON-safe dictionary.
- (NSDictionary *)collectSettings {
    NSDictionary *all = [NSUserDefaults.standardUserDefaults dictionaryRepresentation];
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    for (NSString *k in all) {
        if ([k hasPrefix:@"UNKNW."] && ![k isEqualToString:kUNKNWLicenseKeyKey]) {
            settings[k] = all[k];
        }
    }
    return settings;
}

- (void)applySettings:(NSDictionary *)settings {
    if (![settings isKindOfClass:[NSDictionary class]]) return;
    for (NSString *k in settings) {
        if ([k hasPrefix:@"UNKNW."] && ![k isEqualToString:kUNKNWLicenseKeyKey]) {
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

- (void)send:(NSURLRequest *)request completion:(void (^)(BOOL, NSDictionary *, NSString *))completion {
    NSURLSessionDataTask *task = [_session dataTaskWithRequest:request
                                             completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        BOOL ok = !error && http.statusCode >= 200 && http.statusCode < 300;
        NSString *message = error.localizedDescription ?: json[@"message"];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(ok, json, message);
        });
    }];
    [task resume];
}

- (void)validateKey:(NSString *)key completion:(void (^)(BOOL, NSString *))completion {
    NSMutableURLRequest *request = [self requestForPath:@"/v1/validate" method:@"POST"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:@{@"key": key ?: @""} options:0 error:nil];
    [self send:request completion:^(BOOL ok, NSDictionary *json, NSString *message) {
        BOOL valid = ok && [json[@"valid"] boolValue];
        if (valid) self.key = key;
        if (completion) completion(valid, message);
    }];
}

- (void)backupSettings:(void (^)(BOOL, NSString *))completion {
    if (!self.key.length) { if (completion) completion(NO, @"No license key"); return; }
    NSMutableURLRequest *request = [self requestForPath:@"/v1/settings" method:@"PUT"];
    [request setValue:self.key forHTTPHeaderField:@"X-License-Key"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:@{@"settings": [self collectSettings]}
                                                      options:0 error:nil];
    [self send:request completion:^(BOOL ok, NSDictionary *json, NSString *message) {
        if (completion) completion(ok, message ?: (ok ? @"Backed up" : @"Backup failed"));
    }];
}

- (void)restoreSettings:(void (^)(BOOL, NSString *))completion {
    if (!self.key.length) { if (completion) completion(NO, @"No license key"); return; }
    NSMutableURLRequest *request = [self requestForPath:@"/v1/settings" method:@"GET"];
    [request setValue:self.key forHTTPHeaderField:@"X-License-Key"];
    [self send:request completion:^(BOOL ok, NSDictionary *json, NSString *message) {
        if (ok) [self applySettings:json[@"settings"]];
        if (completion) completion(ok, message ?: (ok ? @"Restored" : @"Restore failed"));
    }];
}

@end
