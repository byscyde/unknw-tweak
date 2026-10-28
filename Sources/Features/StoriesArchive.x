// Stories Archive.
//
// Archives YOUR OWN stories to the vault, together with their viewer and liker
// lists, so you can review top viewers/likers over time. Operates on your own
// account's story data that Instagram already shows you.
//
// IMPLEMENTATION NOTE — fill this in with Developer Logging:
//   - Hook the model that represents one of your posted story items to get its
//     media URL, then: [UNKNWVault.shared downloadURL:mediaURL completion:nil];
//     (respects the user's Vault/Photos destination preference).
//   - Hook the viewers-list response for a story to capture the viewer and
//     liker arrays; persist them next to the media (e.g. a JSON sidecar in the
//     vault) and compute per-viewer/per-liker counts for analytics.
//   - Honour kUNKNWStoriesAutoDLKey: only auto-save when that toggle is on.

#import "../UNKNW.h"
#import "../Core/UNKNWVault.h"

%group UNKNWStoriesArchive

// TODO: %hook your-own-story media model and the story viewers response.

%end

void UNKNWInitStoriesArchive(void) {
    %init(UNKNWStoriesArchive);
}
