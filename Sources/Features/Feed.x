// Feed.
//
// Feed-scoped options: hide ads, disable video autoplay, hide comments preview.
//
// IMPLEMENTATION NOTES — fill these in with Developer Logging:
//   HideAds: hook the feed item/cell model, detect the sponsored flag, and drop
//     or collapse the item when kUNKNWHideAdsKey is ON.
//   DisableAutoplay: hook the feed video cell's play/willDisplay path and skip
//     autoplay when kUNKNWFeedDisableAutoplayKey is ON (tap still plays).
//   HideCommentsPreview: hook the feed cell that shows the comment preview rows
//     and hide them when kUNKNWHideCommentsPreviewKey is ON.

#import "../UNKNW.h"
#import <objc/runtime.h>
#import <objc/message.h>

// Interop: the feed/reels list data sources vend their visible objects through
// -objectsForListAdapter:. We return %orig with the sponsored items removed.
@interface IGMainFeedListAdapterDataSource : NSObject @end
@interface IGSundialFeedDataSource : NSObject @end
@interface IGVideoFeedViewController : UIViewController @end
@interface IGChainingFeedViewController : UIViewController @end

// The story viewer inserts ad "reels" into its list (incl. realtime insertion).
@interface IGStoryViewerViewController : UIViewController @end

// Reels (Sundial) ads are rendered by dedicated IGListKit section controllers.
@interface IGSundialAdsBaseSectionController : NSObject @end
@interface IGSundialAd4AdSectionController : NSObject @end
@interface IGSundialAd4AdCreatorsSectionController : NSObject @end
@interface IGSundialAdsCarouselSectionController : NSObject @end
@interface IGSundialAdsShowreelNativeSectionController : NSObject @end

static BOOL UNKNWBoolSel(id obj, NSString *name) {
    SEL s = NSSelectorFromString(name);
    if (![obj respondsToSelector:s]) return NO;
    @try { return ((BOOL (*)(id, SEL))objc_msgSend)(obj, s); } @catch (__unused id e) { return NO; }
}

static id UNKNWIdSel(id obj, NSString *name) {
    SEL s = NSSelectorFromString(name);
    if (![obj respondsToSelector:s]) return nil;
    @try { return ((id (*)(id, SEL))objc_msgSend)(obj, s); } @catch (__unused id e) { return nil; }
}

// An injected sponsored unit. We key off IG's own ad flags on the item or the
// IGMedia it wraps — isAd / isSponsored, or a non-nil adID. (isPaidPartnership
// is a creator disclosure on an organic post, so it is deliberately NOT an ad.)
static BOOL UNKNWIsAdObject(id obj) {
    if (!obj) return NO;
    NSString *cn = NSStringFromClass(object_getClass(obj)) ?: @"";
    if ([cn isEqualToString:@"IGAdItem"]) return YES;
    if ([cn containsString:@"SundialAds"] || [cn containsString:@"AdsVideoCell"] ||
        [cn containsString:@"MultiAdsCell"] || [cn containsString:@"AdItem"]) return YES;
    if (UNKNWBoolSel(obj, @"isAd") || UNKNWBoolSel(obj, @"isSponsored")) return YES;
    id adid = UNKNWIdSel(obj, @"adID") ?: UNKNWIdSel(obj, @"adId");
    if ([adid isKindOfClass:NSString.class] && [(NSString *)adid length]) return YES;
    // Feed rows usually wrap an IGMedia; check the flags on it too.
    for (NSString *k in @[@"media", @"feedItem", @"item"]) {
        id m = UNKNWIdSel(obj, k);
        if (m && m != obj) {
            if (UNKNWBoolSel(m, @"isAd") || UNKNWBoolSel(m, @"isSponsored")) return YES;
            id a = UNKNWIdSel(m, @"adID") ?: UNKNWIdSel(m, @"adId");
            if ([a isKindOfClass:NSString.class] && [(NSString *)a length]) return YES;
        }
    }
    return NO;
}

static NSArray *UNKNWFilterAds(NSArray *items) {
    if (![items isKindOfClass:NSArray.class]) return items;
    // Diagnostic: show what the feed actually vends (once per item-class set).
    static NSMutableSet *seen; static dispatch_once_t o; dispatch_once(&o, ^{ seen = [NSMutableSet set]; });
    NSCountedSet *cs = [NSCountedSet set];
    for (id it in items) [cs addObject:NSStringFromClass(object_getClass(it)) ?: @"?"];
    for (NSString *c in cs) {
        if ([seen containsObject:c]) continue;
        [seen addObject:c];
        UNKNWDiagLog([NSString stringWithFormat:@"[ads] feed item class: %@", c]);
    }
    if (!UNKNWPrefBool(kUNKNWHideAdsKey, YES)) return items;
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:items.count];
    for (id it in items) if (!UNKNWIsAdObject(it)) [out addObject:it];
    return out;
}

// Drop ad reels from a story-viewer reel list (keeps organic + non-ad netego).
static NSArray *UNKNWFilterAdReels(NSArray *reels) {
    if (![reels isKindOfClass:NSArray.class] || !UNKNWPrefBool(kUNKNWHideAdsKey, YES)) return reels;
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:reels.count];
    for (id r in reels) {
        BOOL ad = NO;
        @try {
            if ([r respondsToSelector:@selector(isAd)]) ad = ((BOOL (*)(id, SEL))objc_msgSend)(r, @selector(isAd));
        } @catch (__unused id e) {}
        if (!ad) [out addObject:r];
    }
    return out;
}

%group UNKNWHideAds

%hook IGMainFeedListAdapterDataSource
- (NSArray *)objectsForListAdapter:(id)adapter { return UNKNWFilterAds(%orig); }
%end

%hook IGSundialFeedDataSource
- (NSArray *)objectsForListAdapter:(id)adapter { return UNKNWFilterAds(%orig); }
%end

%hook IGVideoFeedViewController
- (NSArray *)objectsForListAdapter:(id)adapter { return UNKNWFilterAds(%orig); }
%end

%hook IGChainingFeedViewController
- (NSArray *)objectsForListAdapter:(id)adapter { return UNKNWFilterAds(%orig); }
%end

// Reels pager: the sundial feed data source is Swift, so the array filter above
// does not reach it. Instead collapse each reels-ad section controller to zero
// items — the full-screen pager then skips straight to the next real clip.
%hook IGSundialAdsBaseSectionController
- (NSInteger)numberOfItems { return UNKNWPrefBool(kUNKNWHideAdsKey, YES) ? 0 : %orig; }
%end
%hook IGSundialAd4AdSectionController
- (NSInteger)numberOfItems { return UNKNWPrefBool(kUNKNWHideAdsKey, YES) ? 0 : %orig; }
%end
%hook IGSundialAd4AdCreatorsSectionController
- (NSInteger)numberOfItems { return UNKNWPrefBool(kUNKNWHideAdsKey, YES) ? 0 : %orig; }
%end
%hook IGSundialAdsCarouselSectionController
- (NSInteger)numberOfItems { return UNKNWPrefBool(kUNKNWHideAdsKey, YES) ? 0 : %orig; }
%end
%hook IGSundialAdsShowreelNativeSectionController
- (NSInteger)numberOfItems { return UNKNWPrefBool(kUNKNWHideAdsKey, YES) ? 0 : %orig; }
%end

// Stories: filter ad reels out of the viewer's list (covers realtime insertion).
%hook IGStoryViewerViewController
- (void)updateReels:(NSArray *)reels { %orig(UNKNWFilterAdReels(reels)); }
%end

%end

%group UNKNWFeedDisableAutoplay
// TODO: prevent feed videos from autoplaying.
%end

%group UNKNWHideCommentsPreview
// TODO: hide the comment-preview rows under feed posts.
%end

void UNKNWInitHideAds(void)             { %init(UNKNWHideAds); }
void UNKNWInitFeedDisableAutoplay(void) { %init(UNKNWFeedDisableAutoplay); }
void UNKNWInitHideCommentsPreview(void) { %init(UNKNWHideCommentsPreview); }
