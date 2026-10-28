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

/// A stable per-install identifier (generated once, persisted in prefs).
@property (nonatomic, readonly) NSString *deviceId;

/// Cached activation state (persisted). The loader gates all features on this;
/// it is set by activation / status and cleared on failure or deactivation.
@property (nonatomic, readonly) BOOL isActivated;

/// Fire-and-forget status refresh for app launch (updates isActivated for the
/// next launch so revocation/expiry propagate).
- (void)refreshOnLaunch;

/// POST the key + this device to /v1/activate (binds the device, enforcing the
/// license's device limit). On success the key is stored. Main-queue completion.
- (void)activateKey:(NSString *)key
         completion:(void (^)(BOOL activated, NSString *_Nullable message))completion;

/// GET /v1/status for the stored key + device (valid + activated state).
- (void)refreshStatus:(void (^)(BOOL valid, BOOL activated, NSString *_Nullable message))completion;

/// Release this device from the stored key.
- (void)deactivate:(nullable void (^)(BOOL ok, NSString *_Nullable message))completion;

/// PUT the current UNKNW.* settings to /v1/settings for the stored key.
- (void)backupSettings:(nullable void (^)(BOOL success, NSString *_Nullable message))completion;

/// GET settings for the stored key and apply them locally.
- (void)restoreSettings:(nullable void (^)(BOOL success, NSString *_Nullable message))completion;

@end

NS_ASSUME_NONNULL_END
