#import "UNKNWVault.h"
#import "../UNKNW.h"
#import <Photos/Photos.h>

@implementation UNKNWVaultItem
@end

@implementation UNKNWVault {
    NSURL *_directory;
    NSURLSession *_session;
}

+ (instancetype)shared {
    static UNKNWVault *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [UNKNWVault new]; });
    return shared;
}

- (instancetype)init {
    if ((self = [super init])) {
        _session = [NSURLSession sessionWithConfiguration:
                    [NSURLSessionConfiguration defaultSessionConfiguration]];
    }
    return self;
}

- (NSURL *)directory {
    if (!_directory) {
        NSURL *appSupport = [NSFileManager.defaultManager URLForDirectory:NSApplicationSupportDirectory
                                                                 inDomain:NSUserDomainMask
                                                        appropriateForURL:nil
                                                                   create:YES
                                                                    error:nil];
        _directory = [appSupport URLByAppendingPathComponent:@"UNKNW/Vault" isDirectory:YES];
        [NSFileManager.defaultManager createDirectoryAtURL:_directory
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:nil];
    }
    return _directory;
}

#pragma mark - Storing

- (NSURL *)saveData:(NSData *)data suggestedName:(NSString *)name error:(NSError **)error {
    NSString *filename = name.length ? name : [self generatedNameForExtension:@"bin"];
    NSURL *target = [self uniqueURLForName:filename];
    if ([data writeToURL:target options:NSDataWritingAtomic error:error]) {
        return target;
    }
    return nil;
}

- (NSString *)generatedNameForExtension:(NSString *)ext {
    return [NSString stringWithFormat:@"UNKNW_%@.%@",
            [[NSUUID UUID].UUIDString substringToIndex:8], ext];
}

- (NSURL *)uniqueURLForName:(NSString *)name {
    NSURL *candidate = [self.directory URLByAppendingPathComponent:name];
    NSString *base = name.stringByDeletingPathExtension;
    NSString *ext = name.pathExtension;
    NSUInteger i = 1;
    while ([NSFileManager.defaultManager fileExistsAtPath:candidate.path]) {
        NSString *n = ext.length ? [NSString stringWithFormat:@"%@_%lu.%@", base, (unsigned long)i, ext]
                                 : [NSString stringWithFormat:@"%@_%lu", base, (unsigned long)i];
        candidate = [self.directory URLByAppendingPathComponent:n];
        i++;
    }
    return candidate;
}

#pragma mark - Downloading

- (void)downloadURL:(NSURL *)url completion:(void (^)(BOOL, NSError *))completion {
    if (!url) {
        [self finish:completion success:NO error:[self errorWithMessage:@"nil URL"]];
        return;
    }
    __weak typeof(self) weakSelf = self;
    NSURLSessionDownloadTask *task =
        [_session downloadTaskWithURL:url
                    completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        typeof(self) self = weakSelf;
        if (!self) return;
        if (error || !location) {
            [self finish:completion success:NO error:error];
            return;
        }
        NSString *ext = url.pathExtension.length ? url.pathExtension : @"mp4";
        NSData *data = [NSData dataWithContentsOfURL:location];
        if (!data) {
            [self finish:completion success:NO error:[self errorWithMessage:@"empty download"]];
            return;
        }
        NSError *saveError = nil;
        NSURL *stored = [self saveData:data
                         suggestedName:[self generatedNameForExtension:ext]
                                 error:&saveError];
        if (!stored) {
            [self finish:completion success:NO error:saveError];
            return;
        }
        if (UNKNWPrefNumber(kUNKNWMediaDestKey, UNKNWVaultDestinationPhotos) == UNKNWVaultDestinationPhotos) {
            [self exportToPhotos:stored albumName:[self preferredAlbumName] completion:completion];
        } else {
            [self finish:completion success:YES error:nil];
        }
    }];
    [task resume];
}

- (NSString *)preferredAlbumName {
    switch ((NSInteger)UNKNWPrefNumber(kUNKNWMediaAlbumKey, 0)) {
        case 0: return @"UNKNW";
        case 1: return @"Instagram";
        default: return nil; // Camera Roll (library root)
    }
}

#pragma mark - Photos export

- (void)exportToPhotos:(NSURL *)fileURL albumName:(NSString *)albumName completion:(void (^)(BOOL, NSError *))completion {
    PHAuthorizationStatus status;
    if (@available(iOS 14.0, *)) {
        status = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly];
    } else {
        status = [PHPhotoLibrary authorizationStatus];
    }
    if (status == PHAuthorizationStatusNotDetermined) {
        __weak typeof(self) weakSelf = self;
        void (^handler)(PHAuthorizationStatus) = ^(PHAuthorizationStatus s) {
            [weakSelf performPhotosExport:fileURL albumName:albumName completion:completion];
        };
        if (@available(iOS 14.0, *)) {
            [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:handler];
        } else {
            [PHPhotoLibrary requestAuthorization:handler];
        }
        return;
    }
    [self performPhotosExport:fileURL albumName:albumName completion:completion];
}

- (void)performPhotosExport:(NSURL *)fileURL albumName:(NSString *)albumName completion:(void (^)(BOOL, NSError *))completion {
    BOOL isVideo = [@[@"mp4", @"mov", @"m4v"] containsObject:fileURL.pathExtension.lowercaseString];
    // Create the asset on its own (it lands in Recents — the "gallery"). Adding
    // it to a named album in the SAME change block can fail the whole save, so
    // the album is handled separately and best-effort.
    __block NSString *localId = nil;
    __weak typeof(self) weakSelf = self;
    [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
        PHAssetChangeRequest *req = isVideo
            ? [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:fileURL]
            : [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:fileURL];
        localId = req.placeholderForCreatedAsset.localIdentifier;
    } completionHandler:^(BOOL success, NSError *error) {
        if (success && albumName.length && localId) {
            [weakSelf addAsset:localId toAlbum:albumName completion:^{ [weakSelf finish:completion success:YES error:nil]; }];
        } else {
            [weakSelf finish:completion success:success error:error];
        }
    }];
}

- (void)addAsset:(NSString *)localId toAlbum:(NSString *)albumName completion:(void (^)(void))done {
    void (^addToCollection)(PHAssetCollection *) = ^(PHAssetCollection *album) {
        if (!album) { if (done) done(); return; }
        [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
            PHAsset *asset = [PHAsset fetchAssetsWithLocalIdentifiers:@[localId] options:nil].firstObject;
            PHAssetCollectionChangeRequest *req = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:album];
            if (asset && req) [req addAssets:@[asset]];
        } completionHandler:^(BOOL s, NSError *e) { if (done) done(); }];
    };
    PHAssetCollection *existing = [self albumNamed:albumName];
    if (existing) { addToCollection(existing); return; }
    __block NSString *albumLocalId = nil;
    [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
        PHAssetCollectionChangeRequest *req = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:albumName];
        albumLocalId = req.placeholderForCreatedAssetCollection.localIdentifier;
    } completionHandler:^(BOOL s, NSError *e) {
        PHAssetCollection *created = albumLocalId
            ? [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[albumLocalId] options:nil].firstObject : nil;
        addToCollection(created);
    }];
}

- (PHAssetCollection *)albumNamed:(NSString *)name {
    PHFetchOptions *options = [PHFetchOptions new];
    options.predicate = [NSPredicate predicateWithFormat:@"localizedTitle = %@", name];
    PHFetchResult *result = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                                                     subtype:PHAssetCollectionSubtypeAny
                                                                     options:options];
    return result.firstObject;
}

#pragma mark - Listing

- (NSArray<UNKNWVaultItem *> *)allItems {
    NSArray<NSURLResourceKey> *keys = @[NSURLCreationDateKey, NSURLFileSizeKey];
    NSArray<NSURL *> *contents = [NSFileManager.defaultManager contentsOfDirectoryAtURL:self.directory
                                                            includingPropertiesForKeys:keys
                                                                               options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                 error:nil];
    NSMutableArray<UNKNWVaultItem *> *items = [NSMutableArray array];
    for (NSURL *url in contents) {
        UNKNWVaultItem *item = [UNKNWVaultItem new];
        item.fileURL = url;
        item.name = url.lastPathComponent;
        NSDate *created = nil; NSNumber *size = nil;
        [url getResourceValue:&created forKey:NSURLCreationDateKey error:nil];
        [url getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
        item.createdAt = created ?: [NSDate date];
        item.byteSize = size.unsignedLongLongValue;
        [items addObject:item];
    }
    [items sortUsingComparator:^NSComparisonResult(UNKNWVaultItem *a, UNKNWVaultItem *b) {
        return [b.createdAt compare:a.createdAt];
    }];
    return items;
}

- (BOOL)deleteItem:(UNKNWVaultItem *)item error:(NSError **)error {
    return [NSFileManager.defaultManager removeItemAtURL:item.fileURL error:error];
}

#pragma mark - Helpers

- (NSError *)errorWithMessage:(NSString *)message {
    return [NSError errorWithDomain:@"dev.scyde.unknw.vault" code:1
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

- (void)finish:(void (^)(BOOL, NSError *))completion success:(BOOL)success error:(NSError *)error {
    if (!completion) return;
    dispatch_async(dispatch_get_main_queue(), ^{ completion(success, error); });
}

@end
