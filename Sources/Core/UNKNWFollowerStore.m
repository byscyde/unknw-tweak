#import "UNKNWFollowerStore.h"

NSString *const UNKNWAccountPK         = @"pk";
NSString *const UNKNWAccountUsername   = @"username";
NSString *const UNKNWAccountFullName   = @"fullName";
NSString *const UNKNWAccountPicURL     = @"picURL";
NSString *const UNKNWAccountIsPrivate  = @"isPrivate";
NSString *const UNKNWAccountIsVerified = @"isVerified";

@implementation UNKNWProfileChange
@end

@implementation UNKNWFollowerDiff
@end

@implementation UNKNWFollowerStore {
    NSURL *_file;
}

+ (instancetype)shared {
    static UNKNWFollowerStore *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [UNKNWFollowerStore new]; });
    return shared;
}

- (NSURL *)file {
    if (!_file) {
        NSURL *appSupport = [NSFileManager.defaultManager URLForDirectory:NSApplicationSupportDirectory
                                                                 inDomain:NSUserDomainMask
                                                        appropriateForURL:nil create:YES error:nil];
        NSURL *dir = [appSupport URLByAppendingPathComponent:@"UNKNW/Analytics" isDirectory:YES];
        [NSFileManager.defaultManager createDirectoryAtURL:dir
                               withIntermediateDirectories:YES attributes:nil error:nil];
        _file = [dir URLByAppendingPathComponent:@"followers.json"];
    }
    return _file;
}

- (NSDictionary *)loadSnapshot {
    NSData *data = [NSData dataWithContentsOfURL:self.file];
    if (!data) return nil;
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
}

- (void)writeFollowers:(NSArray *)followers following:(NSArray *)following {
    NSDictionary *snapshot = @{
        @"capturedAt": @([NSDate date].timeIntervalSince1970),
        @"followers": followers ?: @[],
        @"following": following ?: @[],
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:snapshot options:0 error:nil];
    [data writeToURL:self.file options:NSDataWritingAtomic error:nil];
}

- (NSArray<NSDictionary *> *)latestFollowers {
    return [self loadSnapshot][@"followers"] ?: @[];
}

// Index a list by its stable primary key.
- (NSDictionary<NSString *, NSDictionary *> *)indexByPK:(NSArray<NSDictionary *> *)list {
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    for (NSDictionary *account in list) {
        NSString *pk = account[UNKNWAccountPK];
        if (pk) map[pk] = account;
    }
    return map;
}

- (UNKNWFollowerDiff *)recordFollowers:(NSArray<NSDictionary *> *)followers
                             following:(NSArray<NSDictionary *> *)following {
    NSDictionary *previous = [self loadSnapshot];
    UNKNWFollowerDiff *diff = [UNKNWFollowerDiff new];

    NSDictionary *curFollowers = [self indexByPK:followers];
    NSDictionary *curFollowing = [self indexByPK:following];

    // Not following back: in `following` but not in `followers`.
    NSMutableArray *notBack = [NSMutableArray array];
    for (NSString *pk in curFollowing) {
        if (!curFollowers[pk]) [notBack addObject:curFollowing[pk]];
    }
    diff.notFollowingBack = notBack;

    if (!previous) {
        diff.isFirstSnapshot = YES;
        diff.unfollowers = @[];
        diff.addedFollowers = @[];
        diff.profileChanges = @[];
        [self writeFollowers:followers following:following];
        return diff;
    }

    NSDictionary *prevFollowers = [self indexByPK:previous[@"followers"]];

    NSMutableArray *unfollowers = [NSMutableArray array];
    for (NSString *pk in prevFollowers) {
        if (!curFollowers[pk]) [unfollowers addObject:prevFollowers[pk]];
    }
    diff.unfollowers = unfollowers;

    NSMutableArray *newFollowers = [NSMutableArray array];
    for (NSString *pk in curFollowers) {
        if (!prevFollowers[pk]) [newFollowers addObject:curFollowers[pk]];
    }
    diff.addedFollowers = newFollowers;

    // Profile changes among accounts present in both follower snapshots.
    NSArray<NSString *> *trackedFields = @[UNKNWAccountUsername, UNKNWAccountFullName,
                                           UNKNWAccountPicURL, UNKNWAccountIsPrivate,
                                           UNKNWAccountIsVerified];
    NSMutableArray *changes = [NSMutableArray array];
    for (NSString *pk in curFollowers) {
        NSDictionary *before = prevFollowers[pk];
        NSDictionary *after = curFollowers[pk];
        if (!before) continue;
        for (NSString *field in trackedFields) {
            id oldValue = before[field];
            id newValue = after[field];
            if (oldValue == newValue) continue;
            if ([oldValue isEqual:newValue]) continue;
            UNKNWProfileChange *change = [UNKNWProfileChange new];
            change.pk = pk;
            change.username = after[UNKNWAccountUsername];
            change.field = field;
            change.oldValue = oldValue;
            change.updatedValue = newValue;
            [changes addObject:change];
        }
    }
    diff.profileChanges = changes;

    [self writeFollowers:followers following:following];
    return diff;
}

@end
