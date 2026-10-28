// Media Downloader.
//
// Adds a download action to posts, reels, stories and post audio (and, when
// kUNKNWMediaDMKey is on, DM media). Routing (vault vs. Photos, album) is
// handled entirely by UNKNWVault from the user's preferences — this feature
// only needs to (1) add a trigger to the relevant UI and (2) resolve the media
// URL for the item in view.
//
// IMPLEMENTATION NOTE — fill this in with Developer Logging:
//   - Hook the post/reel/story cell or its media view to add a long-press or a
//     button (UNKNWVaultDestination is read inside UNKNWVault, so you don't
//     branch here).
//   - From the cell's bound model, read the best-quality image/video URL
//     (confirm the property names with Developer Logging), then:
//         [UNKNWVault.shared downloadURL:url completion:^(BOOL ok, NSError *e){ ... }];
//   - For post audio, the original-audio asset URL lives on the reel/clips
//     model; pass it to the same downloadURL: call.

#import "../UNKNW.h"
#import "../Core/UNKNWVault.h"

%group UNKNWMediaDownloader

// TODO: %hook the media cell/view classes to add the download trigger and
//       resolve the media URL from the bound model.

%end

void UNKNWInitMediaDownloader(void) {
    %init(UNKNWMediaDownloader);
}
