// Profile Analyzer.
//
// Compares your follower/following lists over time: unfollowers, accounts not
// following you back, and profile changes (picture, username, full name,
// privacy, verification). All analysis is on-device (UNKNWFollowerStore).
//
// IMPLEMENTATION NOTE — fill this in with Developer Logging:
//   Instagram loads followers via a paginated API. Two options:
//     (a) Hook the response model that carries a page of users (observe it with
//         Developer Logging while opening your own followers list) and collect
//         users across pages, OR
//     (b) add a manual "Analyze now" action that calls the same internal
//         pagination and gathers users yourself.
//   For each user build a dictionary with the UNKNWAccount* keys and pass the
//   full followers + following arrays to:
//       UNKNWFollowerDiff *diff =
//           [UNKNWFollowerStore.shared recordFollowers:followers following:following];
//   then present diff.unfollowers / diff.notFollowingBack / diff.profileChanges.

#import "../UNKNW.h"
#import "../Core/UNKNWFollowerStore.h"

%group UNKNWProfileAnalyzer

// TODO: %hook the followers/following response model class.
// Example shape (names are placeholders — confirm with Developer Logging):
//
// %hook IGUserListResponse
// - (id)initWithUsers:(NSArray *)users {
//     id r = %orig;
//     // accumulate `users` into a buffer keyed by list type, then when the
//     // last page arrives call -[UNKNWFollowerStore recordFollowers:following:]
//     return r;
// }
// %end

%end

void UNKNWInitProfileAnalyzer(void) {
    %init(UNKNWProfileAnalyzer);
}
