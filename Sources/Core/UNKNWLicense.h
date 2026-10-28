// UNKNWLicense — client for the UNKNW license + settings-sync server.
//
// Responsibilities:
//   - validate a license key against your server;
//   - back up the user's own UNKNW.* settings to the server (keyed by the
//     license), and restore them after a reinstall.
//
// Only the user's own tweak settings are synced. Follower/profile analytics
// stay on-device (see UNKNWFollowerStore) and are never uploaded here.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UNKNWLicense : NSObject

+ (instancetype)shared;

/// Base URL of your server, e.g. https://api.scyde.dev. Override at runtime via
/// the UNKNW_SERVER_URL env var or by editing the default in the .m.
@property (nonatomic, copy) NSString *baseURLString;

/// The stored license key (persisted in prefs), or nil.
@property (nonatomic, copy, nullable) NSString *key;

/// POST the key to /v1/validate. Completion runs on the main queue.
- (void)validateKey:(NSString *)key
         completion:(void (^)(BOOL valid, NSString *_Nullable message))completion;

/// PUT the current UNKNW.* settings to /v1/settings for the stored key.
- (void)backupSettings:(nullable void (^)(BOOL success, NSString *_Nullable message))completion;

/// GET settings for the stored key and apply them locally.
- (void)restoreSettings:(nullable void (^)(BOOL success, NSString *_Nullable message))completion;

@end

NS_ASSUME_NONNULL_END
