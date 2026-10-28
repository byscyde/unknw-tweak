#import "UNKNW.h"
#import "Features.h"

@implementation UNKNWFeature
@end

@implementation UNKNWFeature (Builders)

+ (instancetype)toggle:(NSString *)key category:(NSString *)category title:(NSString *)title
                detail:(NSString *)detail defaultOn:(BOOL)defaultOn init:(UNKNWFeatureInit)init {
    UNKNWFeature *f = [UNKNWFeature new];
    f.kind = UNKNWFeatureKindToggle;
    f.key = key; f.category = category; f.title = title; f.detail = detail;
    f.defaultBool = defaultOn; f.initializer = init;
    return f;
}

+ (instancetype)stepper:(NSString *)key category:(NSString *)category title:(NSString *)title
                 detail:(NSString *)detail value:(double)value min:(double)min max:(double)max step:(double)step {
    UNKNWFeature *f = [UNKNWFeature new];
    f.kind = UNKNWFeatureKindStepper;
    f.key = key; f.category = category; f.title = title; f.detail = detail;
    f.defaultNumber = value; f.minValue = min; f.maxValue = max; f.stepValue = step;
    return f;
}

+ (instancetype)segment:(NSString *)key category:(NSString *)category title:(NSString *)title
                 detail:(NSString *)detail options:(NSArray<NSString *> *)options defaultIndex:(NSInteger)defaultIndex {
    UNKNWFeature *f = [UNKNWFeature new];
    f.kind = UNKNWFeatureKindSegment;
    f.key = key; f.category = category; f.title = title; f.detail = detail;
    f.options = options; f.defaultNumber = defaultIndex;
    return f;
}

@end

NSArray<UNKNWFeature *> *UNKNWAllFeatures(void) {
    static NSArray<UNKNWFeature *> *features = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *catFeed     = @"Feed";
        NSString *catProfile  = @"Profile";
        NSString *catDownload = @"Download Manager";
        NSString *catStories  = @"Stories";
        NSString *catReels    = @"Reels";
        NSString *catMessages = @"Messages";
        NSString *catGeneral  = @"General";

        features = @[
            // --- Feed --------------------------------------------------------
            [UNKNWFeature toggle:kUNKNWHideAdsKey category:catFeed
                           title:@"Hide ads"
                          detail:@"Remove sponsored posts from the feed"
                       defaultOn:NO init:UNKNWInitHideAds],
            [UNKNWFeature toggle:kUNKNWConfirmLikeKey category:catFeed
                           title:@"Confirm likes"
                          detail:@"Ask before liking to avoid accidental taps"
                       defaultOn:NO init:UNKNWInitConfirmLike],
            [UNKNWFeature toggle:kUNKNWCopyTextKey category:catFeed
                           title:@"Copy text"
                          detail:@"Long-press to copy captions and comments"
                       defaultOn:NO init:UNKNWInitCopyText],
            [UNKNWFeature toggle:kUNKNWDetailedDatesKey category:catFeed
                           title:@"Detailed dates"
                          detail:@"Show full timestamps on posts and stories"
                       defaultOn:NO init:UNKNWInitDetailedDates],

            // --- Profile -----------------------------------------------------
            [UNKNWFeature toggle:kUNKNWProfileAnalyzerKey category:catProfile
                           title:@"Profile Analyzer"
                          detail:@"Track unfollowers, non-followers-back, and profile changes"
                       defaultOn:NO init:UNKNWInitProfileAnalyzer],
            [UNKNWFeature toggle:kUNKNWConfirmFollowKey category:catProfile
                           title:@"Confirm follows"
                          detail:@"Ask before following/unfollowing"
                       defaultOn:NO init:UNKNWInitConfirmFollow],

            // --- Download Manager --------------------------------------------
            [UNKNWFeature toggle:kUNKNWMediaDownloaderKey category:catDownload
                           title:@"Media Downloader"
                          detail:@"Download posts, reels, stories and post audio"
                       defaultOn:NO init:UNKNWInitMediaDownloader],
            [UNKNWFeature toggle:kUNKNWMediaDMKey category:catDownload
                           title:@"Allow DM media"
                          detail:@"Include media received in direct messages"
                       defaultOn:NO init:NULL],
            [UNKNWFeature segment:kUNKNWMediaDestKey category:catDownload
                            title:@"Save to"
                           detail:@"Where downloaded media is stored"
                          options:@[@"Vault", @"Photos"] defaultIndex:0],
            [UNKNWFeature segment:kUNKNWMediaAlbumKey category:catDownload
                            title:@"Photos album"
                           detail:@"Album used when saving to Photos"
                          options:@[@"UNKNW", @"Instagram", @"Camera Roll"] defaultIndex:0],

            // --- Stories -----------------------------------------------------
            [UNKNWFeature toggle:kUNKNWStoriesArchiveKey category:catStories
                           title:@"Stories Archive"
                          detail:@"Archive your stories with viewer/liker lists and analytics"
                       defaultOn:NO init:UNKNWInitStoriesArchive],
            [UNKNWFeature toggle:kUNKNWStoriesAutoDLKey category:catStories
                           title:@"Auto-download Stories"
                          detail:@"Save each story to the vault as you post it"
                       defaultOn:NO init:NULL],
            [UNKNWFeature toggle:kUNKNWHideStorySeenKey category:catStories
                           title:@"Hide story seen"
                          detail:@"View stories without sending a seen receipt"
                       defaultOn:NO init:UNKNWInitHideStorySeen],

            // --- Reels -------------------------------------------------------
            [UNKNWFeature toggle:kUNKNWReelsAutoAdvanceKey category:catReels
                           title:@"Auto-advance"
                          detail:@"Play the next reel automatically"
                       defaultOn:NO init:UNKNWInitReelsAutoAdvance],
            [UNKNWFeature toggle:kUNKNWReelsLimitOnKey category:catReels
                           title:@"Limit reels"
                          detail:@"Stop after a set number of reels in one session"
                       defaultOn:NO init:NULL],
            [UNKNWFeature stepper:kUNKNWReelsLimitCountKey category:catReels
                            title:@"Reel limit"
                           detail:@"Reels per session when limiting is on"
                            value:30 min:5 max:200 step:5],

            // --- Messages ----------------------------------------------------
            [UNKNWFeature toggle:kUNKNWKeepUnsentKey category:catMessages
                           title:@"Keep unsent messages"
                          detail:@"Retain messages that were unsent after you received them"
                       defaultOn:NO init:UNKNWInitKeepUnsent],
            [UNKNWFeature toggle:kUNKNWHideTypingKey category:catMessages
                           title:@"Hide typing indicator"
                          detail:@"Don't broadcast that you're typing"
                       defaultOn:NO init:UNKNWInitHideTyping],
            [UNKNWFeature toggle:kUNKNWHideDMSeenKey category:catMessages
                           title:@"Hide DM read receipts"
                          detail:@"Read messages without marking them seen"
                       defaultOn:NO init:UNKNWInitHideDMSeen],
            [UNKNWFeature toggle:kUNKNWManualSeenKey category:catMessages
                           title:@"Send seen manually"
                          detail:@"Add a one-tap button to send the seen receipt yourself"
                       defaultOn:NO init:NULL],
            [UNKNWFeature toggle:kUNKNWDownloadAudioKey category:catMessages
                           title:@"Download audio messages"
                          detail:@"Save voice messages to the vault"
                       defaultOn:NO init:UNKNWInitDownloadAudioMsg],
            [UNKNWFeature toggle:kUNKNWSendAudioFileKey category:catMessages
                           title:@"Send audio from file"
                          detail:@"Send a voice message from an audio file or a video's track"
                       defaultOn:NO init:UNKNWInitSendAudioFromFile],
            [UNKNWFeature toggle:kUNKNWConfirmCallsKey category:catMessages
                           title:@"Confirm call actions"
                          detail:@"Ask before starting or joining a call"
                       defaultOn:NO init:UNKNWInitConfirmCalls],

            // --- General -----------------------------------------------------
            [UNKNWFeature toggle:kUNKNWDebugLoggingKey category:catGeneral
                           title:@"Developer Logging"
                          detail:@"Print view-controller class names to the console"
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

NSArray<UNKNWFeature *> *UNKNWFeaturesInCategory(NSString *category) {
    NSMutableArray *result = [NSMutableArray array];
    for (UNKNWFeature *f in UNKNWAllFeatures()) {
        if ([f.category isEqualToString:category]) [result addObject:f];
    }
    return result;
}
