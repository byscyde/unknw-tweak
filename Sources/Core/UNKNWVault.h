// UNKNWVault — local media store and Photos export.
//
// A self-contained, jailbreak-independent store living in the host app's
// sandbox (Application Support/UNKNW/Vault). It can download a remote URL,
// keep it in the vault, and/or export it to the Photos library into a named
// album. This is the plumbing every download-oriented feature calls once a
// media URL has been obtained from Instagram (that part is the per-feature,
// version-specific hook).

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, UNKNWVaultDestination) {
    UNKNWVaultDestinationVault  = 0,
    UNKNWVaultDestinationPhotos = 1,
};

NS_ASSUME_NONNULL_BEGIN

@interface UNKNWVaultItem : NSObject
@property (nonatomic, copy) NSURL *fileURL;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSDate *createdAt;
@property (nonatomic, assign) unsigned long long byteSize;
@end

@interface UNKNWVault : NSObject

+ (instancetype)shared;

/// Absolute path to the vault directory, created on first access.
@property (nonatomic, readonly) NSURL *directory;

/// Store bytes already in memory. Returns the stored file URL, or nil on error.
- (nullable NSURL *)saveData:(NSData *)data
               suggestedName:(nullable NSString *)name
                       error:(NSError **)error;

/// Download a remote media URL, then route it per the user's preferences
/// (vault vs. Photos, and which album). Completion runs on the main queue.
- (void)downloadURL:(NSURL *)url
         completion:(nullable void (^)(BOOL success, NSError *_Nullable error))completion;

/// Export an existing vault file to the Photos library into `albumName`
/// (created if needed). Requests add-only authorization if required.
- (void)exportToPhotos:(NSURL *)fileURL
             albumName:(nullable NSString *)albumName
            completion:(nullable void (^)(BOOL success, NSError *_Nullable error))completion;

/// Everything currently in the vault, newest first.
- (NSArray<UNKNWVaultItem *> *)allItems;

- (BOOL)deleteItem:(UNKNWVaultItem *)item error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
