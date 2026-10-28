// UNKNWFollowerStore — on-device snapshots and diffing for Profile Analyzer.
//
// The feature hook feeds in the current follower / following lists (as plain
// dictionaries, so this code is independent of Instagram's model classes); the
// store persists a snapshot and reports what changed versus the previous one:
// unfollowers, non-followers-back, new followers, and per-account profile
// changes (picture, username, full name, privacy, verification).
//
// Everything stays on the device. Nothing here is uploaded.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Dictionary keys describing one account in a list passed to the store.
extern NSString *const UNKNWAccountPK;        // stable id (string)
extern NSString *const UNKNWAccountUsername;
extern NSString *const UNKNWAccountFullName;
extern NSString *const UNKNWAccountPicURL;
extern NSString *const UNKNWAccountIsPrivate;  // NSNumber(BOOL)
extern NSString *const UNKNWAccountIsVerified; // NSNumber(BOOL)

@interface UNKNWProfileChange : NSObject
@property (nonatomic, copy) NSString *pk;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *field;     // e.g. "username", "isPrivate"
@property (nonatomic, copy, nullable) id oldValue;
@property (nonatomic, copy, nullable) id newValue;
@end

@interface UNKNWFollowerDiff : NSObject
@property (nonatomic, copy) NSArray<NSDictionary *> *unfollowers;       // left since last snapshot
@property (nonatomic, copy) NSArray<NSDictionary *> *newFollowers;
@property (nonatomic, copy) NSArray<NSDictionary *> *notFollowingBack;  // you follow, they don't
@property (nonatomic, copy) NSArray<UNKNWProfileChange *> *profileChanges;
@property (nonatomic, assign) BOOL isFirstSnapshot;
@end

@interface UNKNWFollowerStore : NSObject

+ (instancetype)shared;

/// Persist a new snapshot and return the diff against the previous one.
- (UNKNWFollowerDiff *)recordFollowers:(NSArray<NSDictionary *> *)followers
                             following:(NSArray<NSDictionary *> *)following;

/// The most recently stored followers list (empty before the first snapshot).
- (NSArray<NSDictionary *> *)latestFollowers;

@end

NS_ASSUME_NONNULL_END
