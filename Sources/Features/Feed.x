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

%group UNKNWHideAds
// TODO: drop/collapse sponsored feed items.
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
