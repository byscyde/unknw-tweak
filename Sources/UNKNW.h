// UNKNW — an original enhancement tweak for Instagram.
// Developer: SCYDE (https://scyde.dev)
//
// Single place for the shared preference keys, the logging macro, the
// preference accessors and the list of feature initializers. Adding a feature
// touches this file in two spots: a key #define and an `extern` initializer.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#pragma mark - Identity

// Preferences live in the host app's own NSUserDefaults, because on a
// non-jailbroken / Feather install there is no shared prefs file and no
// Settings.app bundle. All keys are namespaced with "UNKNW." so they never
// collide with Instagram's own defaults.

// General
#define kUNKNWEnabledKey            @"UNKNW.enabled"        // master switch
#define kUNKNWLicenseKeyKey         @"UNKNW.licenseKey"     // stored license key

// Feed
#define kUNKNWHideAdsKey            @"UNKNW.hideAds"

// Profile Analyzer
#define kUNKNWProfileAnalyzerKey    @"UNKNW.profileAnalyzer"

// Stories
#define kUNKNWStoriesArchiveKey     @"UNKNW.storiesArchive"
#define kUNKNWStoriesAutoDLKey      @"UNKNW.storiesAutoDownload"

// Media
#define kUNKNWMediaDownloaderKey    @"UNKNW.mediaDownloader"
#define kUNKNWMediaDMKey            @"UNKNW.mediaDMDownload"
#define kUNKNWMediaDestKey          @"UNKNW.mediaDest"      // 0 = Vault, 1 = Photos
#define kUNKNWMediaAlbumKey         @"UNKNW.mediaAlbum"     // 0 = UNKNW, 1 = Instagram, 2 = Camera Roll

// Privacy
#define kUNKNWHideStorySeenKey      @"UNKNW.hideStorySeen"
#define kUNKNWHideDMSeenKey         @"UNKNW.hideDMSeen"
#define kUNKNWManualSeenKey         @"UNKNW.manualSendSeen"

// Messages
#define kUNKNWKeepUnsentKey         @"UNKNW.keepUnsent"
#define kUNKNWHideTypingKey         @"UNKNW.hideTyping"
#define kUNKNWDownloadAudioKey      @"UNKNW.downloadAudioMsg"
#define kUNKNWSendAudioFileKey      @"UNKNW.sendAudioFromFile"
#define kUNKNWConfirmCallsKey       @"UNKNW.confirmCalls"

// Reels
#define kUNKNWReelsAutoAdvanceKey   @"UNKNW.reelsAutoAdvance"
#define kUNKNWReelsLimitOnKey       @"UNKNW.reelsLimitEnabled"
#define kUNKNWReelsLimitCountKey    @"UNKNW.reelsLimitCount"

// Utilities & Customization
#define kUNKNWConfirmLikeKey        @"UNKNW.confirmLike"
#define kUNKNWConfirmFollowKey      @"UNKNW.confirmFollow"
#define kUNKNWCopyTextKey           @"UNKNW.copyText"
#define kUNKNWDetailedDatesKey      @"UNKNW.detailedDates"

// Developer
#define kUNKNWDebugLoggingKey       @"UNKNW.debugLogging"

#pragma mark - Logging

#define UNKNWLog(fmt, ...) NSLog((@"[UNKNW] " fmt), ##__VA_ARGS__)

#pragma mark - Preferences

#ifdef __cplusplus
extern "C" {
#endif

BOOL     UNKNWPrefBool(NSString *key, BOOL defaultValue);
void     UNKNWPrefSetBool(NSString *key, BOOL value);
double   UNKNWPrefNumber(NSString *key, double defaultValue);
void     UNKNWPrefSetNumber(NSString *key, double value);
NSString *UNKNWPrefString(NSString *key, NSString *defaultValue);
void     UNKNWPrefSetString(NSString *key, NSString *value);

#ifdef __cplusplus
}
#endif

#pragma mark - Feature initializers

// Each is defined in its feature file under Sources/Features and runs its own
// %init(group). Registered in Features.m. NULL in the registry = config-only
// value with no hooks.
extern void UNKNWInitHideAds(void);
extern void UNKNWInitProfileAnalyzer(void);
extern void UNKNWInitStoriesArchive(void);
extern void UNKNWInitMediaDownloader(void);
extern void UNKNWInitHideStorySeen(void);
extern void UNKNWInitHideDMSeen(void);
extern void UNKNWInitKeepUnsent(void);
extern void UNKNWInitHideTyping(void);
extern void UNKNWInitDownloadAudioMsg(void);
extern void UNKNWInitSendAudioFromFile(void);
extern void UNKNWInitConfirmCalls(void);
extern void UNKNWInitReelsAutoAdvance(void);
extern void UNKNWInitConfirmLike(void);
extern void UNKNWInitConfirmFollow(void);
extern void UNKNWInitCopyText(void);
extern void UNKNWInitDetailedDates(void);
extern void UNKNWInitDebugLogging(void);
