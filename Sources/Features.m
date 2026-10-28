#import "UNKNW.h"
#import "Features.h"

@implementation UNKNWFeature
@end

@implementation UNKNWFeature (Builders)

+ (instancetype)toggle:(NSString *)key category:(NSString *)category section:(NSString *)section
                 title:(NSString *)title detail:(NSString *)detail
             defaultOn:(BOOL)defaultOn init:(UNKNWFeatureInit)init {
    UNKNWFeature *f = [UNKNWFeature new];
    f.kind = UNKNWFeatureKindToggle;
    f.key = key; f.category = category; f.section = section ?: @"";
    f.title = title; f.detail = detail;
    f.defaultBool = defaultOn; f.initializer = init;
    return f;
}

+ (instancetype)stepper:(NSString *)key category:(NSString *)category section:(NSString *)section
                  title:(NSString *)title detail:(NSString *)detail
                  value:(double)value min:(double)min max:(double)max step:(double)step {
    UNKNWFeature *f = [UNKNWFeature new];
    f.kind = UNKNWFeatureKindStepper;
    f.key = key; f.category = category; f.section = section ?: @"";
    f.title = title; f.detail = detail;
    f.defaultNumber = value; f.minValue = min; f.maxValue = max; f.stepValue = step;
    return f;
}

+ (instancetype)segment:(NSString *)key category:(NSString *)category section:(NSString *)section
                  title:(NSString *)title detail:(NSString *)detail
                options:(NSArray<NSString *> *)options defaultIndex:(NSInteger)defaultIndex {
    UNKNWFeature *f = [UNKNWFeature new];
    f.kind = UNKNWFeatureKindSegment;
    f.key = key; f.category = category; f.section = section ?: @"";
    f.title = title; f.detail = detail;
    f.options = options; f.defaultNumber = defaultIndex;
    return f;
}

@end

NSArray<UNKNWFeature *> *UNKNWAllFeatures(void) {
    static NSArray<UNKNWFeature *> *features = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *cFixes = @"App Fixes";
        NSString *cFeed = @"Feed", *cReels = @"Reels", *cStories = @"Stories";
        NSString *cMsg = @"Messages", *cProfile = @"Profile";
        NSString *cDownload = @"Download Manager", *cGeneral = @"General";

        features = @[
            // ===== App Fixes (enablers for sideloaded installs) =====
            [UNKNWFeature toggle:kUNKNWIntegrityKey category:cFixes section:@""
                           title:@"Stability guard"
                          detail:@"Stop the sideloaded app crashing at launch (nil-string guard, loaded at launch)"
                       defaultOn:YES init:UNKNWInitIntegrityBypass],
            [UNKNWFeature toggle:kUNKNWKeychainFixKey category:cFixes section:@""
                           title:@"Fix login persistence"
                          detail:@"Keep your session across relaunches on a re-signed install"
                       defaultOn:YES init:UNKNWInstallKeychainFix],
            [UNKNWFeature toggle:kUNKNWBetaBypassKey category:cFixes section:@""
                           title:@"Bypass beta update gate"
                          detail:@"Skip the \"update Instagram Beta\" screen"
                       defaultOn:YES init:UNKNWInitBetaBypass],

            // ===== Feed =====
            [UNKNWFeature toggle:kUNKNWHideAdsKey category:cFeed section:@"Posts"
                           title:@"Hide ads" detail:@"Remove sponsored posts from the feed"
                       defaultOn:NO init:UNKNWInitHideAds],
            [UNKNWFeature toggle:kUNKNWFeedDisableAutoplayKey category:cFeed section:@"Posts"
                           title:@"Disable video autoplay" detail:@"Feed videos play only when tapped"
                       defaultOn:NO init:UNKNWInitFeedDisableAutoplay],
            [UNKNWFeature toggle:kUNKNWConfirmLikeKey category:cFeed section:@"Posts"
                           title:@"Confirm likes" detail:@"Ask before liking to avoid accidental taps"
                       defaultOn:NO init:UNKNWInitConfirmLike],
            [UNKNWFeature toggle:kUNKNWDetailedDatesKey category:cFeed section:@"Posts"
                           title:@"Detailed dates" detail:@"Show full timestamps on posts and stories"
                       defaultOn:NO init:UNKNWInitDetailedDates],
            [UNKNWFeature toggle:kUNKNWCopyTextKey category:cFeed section:@"Comments"
                           title:@"Copy text" detail:@"Long-press a comment or caption to copy it"
                       defaultOn:NO init:UNKNWInitCopyText],
            [UNKNWFeature toggle:kUNKNWHideCommentsPreviewKey category:cFeed section:@"Comments"
                           title:@"Hide comments preview" detail:@"Remove the comment preview under posts"
                       defaultOn:NO init:UNKNWInitHideCommentsPreview],

            // ===== Reels =====
            [UNKNWFeature toggle:kUNKNWReelsAutoAdvanceKey category:cReels section:@"Playback"
                           title:@"Auto-advance" detail:@"Play the next reel automatically"
                       defaultOn:NO init:UNKNWInitReelsAutoAdvance],
            [UNKNWFeature toggle:kUNKNWReelsLimitOnKey category:cReels section:@"Playback"
                           title:@"Limit reels" detail:@"Stop after a set number of reels per session"
                       defaultOn:NO init:NULL],
            [UNKNWFeature stepper:kUNKNWReelsLimitCountKey category:cReels section:@"Playback"
                            title:@"Reel limit" detail:@"Reels per session when limiting is on"
                            value:30 min:5 max:200 step:5],

            // ===== Stories =====
            [UNKNWFeature toggle:kUNKNWStoriesArchiveKey category:cStories section:@"Archive"
                           title:@"Stories Archive" detail:@"Archive your stories with viewers and likers"
                       defaultOn:NO init:UNKNWInitStoriesArchive],
            [UNKNWFeature toggle:kUNKNWStoriesAutoDLKey category:cStories section:@"Archive"
                           title:@"Auto-download" detail:@"Save each story to the vault as you post it"
                       defaultOn:NO init:NULL],
            [UNKNWFeature toggle:kUNKNWHideStorySeenKey category:cStories section:@"Privacy"
                           title:@"Hide story seen" detail:@"View stories without sending a seen receipt"
                       defaultOn:NO init:UNKNWInitHideStorySeen],

            // ===== Messages =====
            [UNKNWFeature toggle:kUNKNWHideTypingKey category:cMsg section:@"Privacy"
                           title:@"Hide typing indicator" detail:@"Don't broadcast that you're typing"
                       defaultOn:NO init:UNKNWInitHideTyping],
            [UNKNWFeature toggle:kUNKNWHideDMSeenKey category:cMsg section:@"Privacy"
                           title:@"Hide read receipts" detail:@"Read messages without marking them seen"
                       defaultOn:NO init:UNKNWInitHideDMSeen],
            [UNKNWFeature toggle:kUNKNWManualSeenKey category:cMsg section:@"Privacy"
                           title:@"Send seen manually" detail:@"Add a one-tap button to send the receipt"
                       defaultOn:NO init:NULL],
            [UNKNWFeature toggle:kUNKNWKeepUnsentKey category:cMsg section:@"Content"
                           title:@"Keep unsent messages" detail:@"Retain messages unsent after you received them"
                       defaultOn:NO init:UNKNWInitKeepUnsent],
            [UNKNWFeature toggle:kUNKNWDownloadAudioKey category:cMsg section:@"Content"
                           title:@"Download audio messages" detail:@"Save voice messages to the vault"
                       defaultOn:NO init:UNKNWInitDownloadAudioMsg],
            [UNKNWFeature toggle:kUNKNWSendAudioFileKey category:cMsg section:@"Content"
                           title:@"Send audio from file" detail:@"Send a voice message from a file or a video's track"
                       defaultOn:NO init:UNKNWInitSendAudioFromFile],
            [UNKNWFeature toggle:kUNKNWConfirmCallsKey category:cMsg section:@"Calls"
                           title:@"Confirm call actions" detail:@"Ask before starting or joining a call"
                       defaultOn:NO init:UNKNWInitConfirmCalls],

            // ===== Profile =====
            [UNKNWFeature toggle:kUNKNWProfileAnalyzerKey category:cProfile section:@""
                           title:@"Profile Analyzer" detail:@"Unfollowers, non-followers-back, profile changes"
                       defaultOn:NO init:UNKNWInitProfileAnalyzer],
            [UNKNWFeature toggle:kUNKNWConfirmFollowKey category:cProfile section:@""
                           title:@"Confirm follows" detail:@"Ask before following/unfollowing"
                       defaultOn:NO init:UNKNWInitConfirmFollow],

            // ===== Download Manager =====
            [UNKNWFeature toggle:kUNKNWMediaDownloaderKey category:cDownload section:@""
                           title:@"Media Downloader" detail:@"Download posts, reels, stories and post audio"
                       defaultOn:NO init:UNKNWInitMediaDownloader],
            [UNKNWFeature toggle:kUNKNWMediaDMKey category:cDownload section:@""
                           title:@"Allow DM media" detail:@"Include media received in direct messages"
                       defaultOn:NO init:NULL],
            [UNKNWFeature segment:kUNKNWMediaDestKey category:cDownload section:@"Destination"
                            title:@"Save to" detail:@"Where downloaded media is stored"
                          options:@[@"Vault", @"Photos"] defaultIndex:0],
            [UNKNWFeature segment:kUNKNWMediaAlbumKey category:cDownload section:@"Destination"
                            title:@"Photos album" detail:@"Album used when saving to Photos"
                          options:@[@"UNKNW", @"Instagram", @"Camera Roll"] defaultIndex:0],

            // ===== General =====
            [UNKNWFeature toggle:kUNKNWDebugLoggingKey category:cGeneral section:@""
                           title:@"Developer Logging" detail:@"Print view-controller class names to the console"
                       defaultOn:NO init:UNKNWInitDebugLogging],
        ];
    });
    return features;
}

NSArray<NSString *> *UNKNWCategories(void) {
    static NSArray<NSString *> *categories = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableArray *ordered = [NSMutableArray array];
        for (UNKNWFeature *f in UNKNWAllFeatures()) {
            if (![ordered containsObject:f.category]) [ordered addObject:f.category];
        }
        categories = [ordered copy];
    });
    return categories;
}

NSString *UNKNWCategoryIcon(NSString *category) {
    static NSDictionary *icons = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        icons = @{
            @"App Fixes": @"wrench.and.screwdriver",
            @"Feed": @"square.stack",
            @"Reels": @"play.rectangle",
            @"Stories": @"circle.dashed",
            @"Messages": @"paperplane",
            @"Profile": @"person",
            @"Download Manager": @"arrow.down.circle",
            @"General": @"gearshape",
        };
    });
    return icons[category] ?: @"square.grid.2x2";
}

NSArray<NSString *> *UNKNWSectionsInCategory(NSString *category) {
    NSMutableArray *ordered = [NSMutableArray array];
    for (UNKNWFeature *f in UNKNWAllFeatures()) {
        if ([f.category isEqualToString:category] && ![ordered containsObject:f.section]) {
            [ordered addObject:f.section];
        }
    }
    return ordered;
}

NSArray<UNKNWFeature *> *UNKNWFeaturesInCategorySection(NSString *category, NSString *section) {
    NSMutableArray *result = [NSMutableArray array];
    for (UNKNWFeature *f in UNKNWAllFeatures()) {
        if ([f.category isEqualToString:category] && [f.section isEqualToString:section]) {
            [result addObject:f];
        }
    }
    return result;
}
