// Feed.
//
// Feed-scoped options. Currently: Hide ads / sponsored posts.
//
// IMPLEMENTATION NOTE — fill this in with Developer Logging:
//   Hook the feed item/cell model and detect the sponsored/ad flag (observe the
//   property with Developer Logging while a sponsored post is on screen), then
//   either remove the item from the data source or collapse its cell to zero
//   height when kUNKNWHideAdsKey is ON.

#import "../UNKNW.h"

%group UNKNWHideAds

// TODO: %hook the feed item model / cell; drop or collapse sponsored items.

%end

void UNKNWInitHideAds(void) {
    %init(UNKNWHideAds);
}
