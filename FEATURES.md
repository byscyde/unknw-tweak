# UNKNW — feature status

Every feature below is **registered and appears in the in-app panel**. The
"Infrastructure" column is code that is written and works today; the "Hook"
column is the Instagram-specific part you complete by discovering the right
class/method with **Developer Logging** (see each feature file's notes).

| Category | Feature | Key | Infrastructure | Hook |
|----------|---------|-----|----------------|------|
| Profile Analyzer | Unfollowers / not-following-back / profile changes | `UNKNW.profileAnalyzer` | ✅ `UNKNWFollowerStore` (snapshot + diff, on-device) | capture followers/following pages |
| Stories | Stories Archive (+ viewers/likers analytics) | `UNKNW.storiesArchive` | ✅ `UNKNWVault` | capture own-story media + viewer list |
| Stories | Auto-download stories | `UNKNW.storiesAutoDownload` | ✅ (config) | — |
| Media | Media Downloader (posts/reels/stories/audio) | `UNKNW.mediaDownloader` | ✅ `UNKNWVault` download + Photos export | add trigger, resolve media URL |
| Media | Allow DM media | `UNKNW.mediaDMDownload` | ✅ (config) | — |
| Media | Save to (Vault/Photos) | `UNKNW.mediaDest` | ✅ | — |
| Media | Photos album | `UNKNW.mediaAlbum` | ✅ | — |
| Privacy | Hide story seen | `UNKNW.hideStorySeen` | ✅ (prefs) | suppress story-seen report |
| Privacy | Hide DM read receipts | `UNKNW.hideDMSeen` | ✅ (prefs) | suppress thread-seen report |
| Privacy | Send seen manually | `UNKNW.manualSendSeen` | ✅ (config) | add one-tap send-seen button |
| Messages | Keep unsent messages | `UNKNW.keepUnsent` | ✅ (prefs) | retain on unsend event |
| Messages | Hide typing indicator | `UNKNW.hideTyping` | ✅ (prefs) | suppress typing sender |
| Messages | Download audio messages | `UNKNW.downloadAudioMsg` | ✅ `UNKNWVault` | add save action, resolve URL |
| Messages | Send audio from file | `UNKNW.sendAudioFromFile` | ✅ AVFoundation path | wire into send flow |
| Messages | Confirm call actions | `UNKNW.confirmCalls` | ✅ (prefs) | confirm before call action |
| Reels | Auto-advance | `UNKNW.reelsAutoAdvance` | ✅ (prefs) | advance on playback end |
| Reels | Limit reels / count | `UNKNW.reelsLimitEnabled` / `…Count` | ✅ (config + counter) | count visible reels |
| Utilities | Confirm likes | `UNKNW.confirmLike` | ✅ (prefs) | confirm before like |
| Utilities | Confirm follows | `UNKNW.confirmFollow` | ✅ (prefs) | confirm before follow |
| Utilities | Copy text | `UNKNW.copyText` | ✅ (prefs) | add long-press copy |
| Utilities | Detailed dates | `UNKNW.detailedDates` | ✅ `UNKNWFormat` | substitute timestamp text |
| Developer | Developer Logging | `UNKNW.debugLogging` | ✅ working | — |
| General | License + settings sync | `UNKNW.licenseKey` | ✅ `UNKNWLicense` + `server/` | — |

## How to complete a hook

1. Enable **Developer Logging**, relaunch Instagram, open the relevant screen,
   and read the console (filter `[UNKNW]`) to learn the real class names.
2. Open the feature file in `Sources/Features/` and replace its `// TODO` block
   with `%hook`s against those classes.
3. Call the infrastructure that is already written (e.g.
   `[UNKNWVault.shared downloadURL:url completion:...]`,
   `[UNKNWFollowerStore.shared recordFollowers:following:]`).
4. Rebuild. The toggle already controls whether the hook group loads.

## Not implemented, by design

**Disable screenshot notifications** (requested under Messages) is intentionally
omitted. Instagram sends those notifications only for disappearing / view-once /
vanish-mode content, specifically so the sender knows their one-time content was
captured. A toggle whose only purpose is to defeat that removes a privacy
safeguard protecting the other person, rather than changing your own experience,
so it is left out. Every other Messages option is included.
