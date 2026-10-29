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

static BOOL UNKNWIsAdObject(id obj) {
    if (!obj) return NO;
    NSString *cn = NSStringFromClass(object_getClass(obj)) ?: @"";
    if ([cn isEqualToString:@"IGAdItem"]) return YES;
    if ([cn containsString:@"SundialAds"] || [cn containsString:@"AdsVideoCell"] ||
        [cn containsString:@"MultiAdsCell"] || [cn containsString:@"AdItem"]) return YES;
    @try {
        SEL sp = NSSelectorFromString(@"isSponsored");
        if ([obj respondsToSelector:sp] && ((BOOL (*)(id, SEL))objc_msgSend)(obj, sp)) return YES;
        SEL sa = NSSelectorFromString(@"isSponsoredApp");
        if ([obj respondsToSelector:sa] && ((BOOL (*)(id, SEL))objc_msgSend)(obj, sa)) return YES;
    } @catch (__unused id e) {}
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
    if (!UNKNWPrefBool(kUNKNWHideAdsKey, NO)) return items;
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:items.count];
    for (id it in items) if (!UNKNWIsAdObject(it)) [out addObject:it];
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
