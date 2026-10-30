# UNKNW — Instagram & Regram internals (reverse-engineering reference)

This is our permanent map of the Instagram 453 internals and Regram's technique,
recovered by class-dumping the binaries. Use it instead of guessing. Everything
here is interoperability facts (class / method / property names and offsets) used
to write UNKNW's own original implementations.

## Tooling — regenerate any time

`scripts/objctool.py` resolves a thin arm64 Mach-O's ObjC metadata through its
DYLD chained fixups (rebase target = low 36 bits), giving a full class dump with
IMP addresses, plus selref/classref maps and an annotated disassembler.

```
# full class dump (name + methods + IMP):
python3 -I scripts/objctool.py <binary> classes [NameFilter]

# selector-reference table:
python3 -I scripts/objctool.py <binary> selrefs

# annotated disassembly of the function at an IMP (needs an llvm-objdump dump):
llvm-objdump -d --macho --symbolize-operands --no-show-raw-insn <binary> > dis.txt
python3 -I scripts/objctool.py <binary> dis 0x<imp> dis.txt
```

Binaries live outside the repo (they are Instagram's / Regram's property):
- Instagram 453: `Payload/Instagram.app/Instagram` from the base IPA.
- Regram: `Payload/Instagram.app/Regram.dylib` from a Regram IPA.

Full dumps kept in the repo:
- `docs/dumps/regram-classdump.txt` — Regram: 1262 classes, ~20.9k methods, IMPs.
- `docs/dumps/regram-selrefs.txt` — Regram selector references.
- `docs/dumps/ig-relevant-classdump.txt` — the IG 453 classes that matter for our
  features (story / profile / reels / sundial / media / ads / user).

---

## Media model — IGMedia (the backbone of every download)

Reels, stories and feed posts are all backed by an **IGMedia** (plain ObjC model;
safe to message when `-respondsToSelector:` is YES — never use KVC on the Swift
*view* objects, that SIGSEGVs).

Video (reels & stories stream as **MPEG-DASH**, not progressive):
- `-videoDashManifest` → the MPD XML string (the usual source — parse + remux).
- `-dashManifest` → alt manifest.
- `-progressiveDownloadUrl` / `-progressiveDownloadURLString` → direct MP4 (rare).
- `-videoVersions` → array of quality variants; each has `-url`/`-URL`, `-width`,
  `-height`, `-bandwidth`, `-type`.

Image:
- `-displayURL` / `-displayUrl`, `-imageURL`/`-imageUrl`, `-url`/`-URL`.
- `-imageVersions2` → wraps `-candidates` (array); each candidate has `-url`,
  `-width`, `-height`. (`-imageCandidates` / `-candidates` on some models.)

Ad flags: `-isAd`, `-isSponsored`, `-adID`/`-adId`. (`-isPaidPartnership` is a
creator disclosure on an organic post — NOT an injected ad.)

---

## DASH download (how Regram does it — and now UNKNW)

Regram's binary proves the technique (class `RGDownloadFileResolver`,
`RGDashParser`, `RGDashRepresentation -mergeWithAudioPresentation`, and ivars
`AVAssetWriter _writer`, `AVAssetWriterInput _videoInput`; selectors
`assetReaderTrackOutputWithTrack:outputSettings:`, `copyNextSampleBuffer`,
`convertRawDashFile:`):

1. Read `-videoDashManifest` (MPD XML) off the IGMedia.
2. Parse the MPD: pick the highest-`bandwidth` `<BaseURL>` from the **video** and
   from the **audio** `<AdaptationSet>` (decode `&amp;` in the URLs).
3. Download both files.
4. **Remux at the sample level** — `AVAssetReader` + `AVAssetReaderTrackOutput`
   (outputSettings:nil) → `copyNextSampleBuffer` → `AVAssetWriterInput`
   (outputSettings:nil, sourceFormatHint = track.formatDescriptions[0]) →
   `AVAssetWriter` (AVFileTypeMPEG4). **No re-encode** (IG tracks are
   fragmented/HEVC → `AVAssetExportSession` HighestQuality fails "Cannot Decode",
   and passthrough-export output is rejected by Photos as
   `PHPhotosErrorInvalidResource` 3302). The reader→writer remux yields a clean
   standard MP4 the Photos library accepts.
5. Save: create the asset on its own (lands in Recents), add to the album in a
   separate best-effort change (album-in-same-block can fail the whole save).

UNKNW implementation: `Sources/Features/MediaDownloader.x` (`UNKNWBestRepURL`,
`UNKNWFetchToTemp`, `UNKNWMux`/`UNKNWPump`, `UNKNWDownloadDASH`) and
`Sources/Core/UNKNWVault.m` (`performPhotosExport` / `addAsset:toAlbum:`).

---

## Feature 1 — Reels video download

- Reel cell: **`IGSundialViewerVideoCell`** (our long-press / button host).
- Section controller: **`IGSundialVideoSC.IGSundialViewerVideoSectionController`**
  (Swift) binds the reel; `-didUpdateToObject:` receives the **IGMedia**.
  (There is *no* class literally named `IGSundialViewerVideoSectionController`.)
  Other reel SCs: `IGSundialViewerCarouselSectionController`,
  `IGSundialViewerPhotoSectionController`, `IGSundialViewerLoadingSectionController`.
- Capture: a broad `-didUpdateToObject:` swizzle over every
  Sundial/Reel/Clips/Story section controller stashes the bound IGMedia
  (`gUNKNWCurrentReelMedia`). Resolve → `UNKNWVideoURLFromMedia` → DASH.

## Feature 2 — Story download

- Content cell: **`IGStoryFullscreenCell`** (our host). It exposes the current
  item: **`-currentStoryItemContext`** → **`IGStoryItemContext`** →
  **`-storyItem`** → the story item → its IGMedia.
- Viewer VC: **`IGStoryViewerViewController`** (ObjC-registered name) has
  `-currentStoryItem`, `-focusedStoryItem`, `-currentViewModel`, `-currentPageIndex`.
- Reel/item model: **`IGStoryViewerViewModel`** — `-items`, `-currentUser`,
  `-owner`, `-type`, `-adsDetails` (see ads), `-storyDetails`. Section controller:
  `IGStoryFullscreenSectionControllerSwift`.
- The story view model does **not** expose the current item directly (only
  `-items`); the current item lives on the cell's `-currentStoryItemContext`.

## Feature 3 — Profile picture download (HD)

- Regram: `-HDProfilePictureURLForUser:` / `-HDProfilePictureURLForUser:fallbackToThumbnail:`,
  `-downloadProfilePictureToVaultForUser:`, `-fetchHDProfilePictureWithCompletion:`.
  It reads the **IGUser**'s `-hdProfilePicUrlInfo` (an image-info object with
  `-url`) or `-hdProfilePicURL`, falling back to `-profilePicURL`.
- Getting the user: **`IGProfileViewController -user`** (ObjC). The fullscreen
  viewer **`IGProfilePictureFullscreen.IGProfilePictureFullscreenViewController`**
  (Swift, created `initWithProfileUser:...`) is presented modally and is NOT in
  the avatar's responder chain — so capture the viewed user from
  `IGProfileViewController` (UNKNW stashes `gUNKNWProfileUser`).
- The view: **`IGProfilePictureImageView`** (has `-setImageURL:`, `-imageURL`,
  `-user` sometimes). IG only serves profile pics up to the HD size
  (`hdProfilePicUrlInfo`, ~1080) — there is no public "original upload" URL.

## Ads removal

- **Feed**: items vended via `-objectsForListAdapter:` on (ObjC + Swift) list data
  sources. We swizzle that selector across every implementing class and drop
  `UNKNWIsAdObject` items. Ad item class: `IGAdItem`.
- **Reels (Sundial)**: the feed data source is Swift (`IGSundialFeedDataSource.…`);
  the swizzle reaches it. Ad section controllers (backstop, collapse to 0 items):
  `IGSundialAdsBaseSectionController`, `IGSundialAd4AdSectionController`,
  `IGSundialAd4AdCreatorsSectionController`, `IGSundialAdsCarouselSectionController`,
  `IGSundialAdsShowreelNativeSectionController`.
- **Stories**: a sponsored story is a separate reel whose **`IGStoryViewerViewModel`**
  has a non-nil **`-adsDetails`**. These view models are vended through
  `-objectsForListAdapter:`, so `UNKNWIsAdObject` treating `adsDetails != nil` as
  an ad lets the same filter drop them. IG's own ad-hiding hooks also exist:
  `IGStoryViewerViewController -hideStoryItemAtMACIndex:`,
  `-multiAdsGridSectionViewDidHideAllAds:`, `-_skipDPAGridStoryWithAllAdsHidden`.
- Ad detection (`UNKNWIsAdObject`, `Sources/Features/Feed.x`): class name is
  `IGAdItem` / contains `SundialAds`/`AdItem`; or `-isAd`/`-isSponsored` YES; or
  non-nil `-adID`; or non-nil `-adsDetails`; also checked on a wrapped `-media`.

## Safe dynamic calls (the crash rule)

IG's reels/story responders are Swift and expose many same-named getters with
scalar/struct returns. Calling such a selector as if it returned `id` is an ABI
mismatch → **uncatchable SIGSEGV** (`@try` does not catch it). Always verify the
method signature first: no args, and the right return type (`@` for objects).
See `UNKNWMsgSend`/`UNKNWIntCall` (MediaDownloader.x) and the signature-checked
`UNKNWBoolSel`/`UNKNWIdSel` (Feed.x). Never use KVC (`valueForKey:`) on IG models.

---

## Regram download/model classes worth knowing (see full dump for methods)

- `RGDownloadFileResolver` — `resolveFromPhoto:completion:`,
  `resolveFromVideo:completion:`, quality pickers, web-candidate prefetch.
- `RGDownloadAssembler`, `RGDownloadFileResolver`, `RGDownloadDuplicateChecker`,
  `RGDownloadBanner`, `RGDownloadFloatingButton` (the save button UI).
- `RGDashParser`, `RGDashRepresentation`, `RGDashDownloadOptionCell`,
  `RGMediaURL`, `RGAudioDownloadHelpers`.
- `RGCurrentUserStory` — `mediaURL`, `mediaThumbnailURL`, `mediaType`, `mediaID`.
- `RGAdsSection` — the ads settings section (Regram's ad removal itself is logos
  `%hook`s on IG classes, which do not appear as classes in the dump).
