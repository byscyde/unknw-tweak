# UNKNW — full Regram feature port (plan of record)

Reimplement **every** Regram 6.5 feature in original UNKNW code — all of it except Regram's own license gating. Order: **stability/Device-Identity foundation first**, then feature groups below. Check items off as ported + device-tested.

_3134 labels → 524 modules across 190 areas._

## FOUNDATION — stability / anti-detection (do first)
- [ ] Block App Attest (DCAppAttestService) — DONE (needs device confirm)
- [ ] Device Identity: mask / roll / clear / manual set (serializedDeviceIdentity)
- [ ] Jailbreak-check neutralize (isJailbroken, FBFamilyIDDeviceIsJailbroken, _METADeviceAppearsJailbroken)
- [ ] Beta/TestFlight update-nag bypass
- [ ] Keychain login persistence
- [ ] Crash capture (DONE)

## PROFILE  (~407 labels, 8 modules)
- [ ] PROFILE_TRACKING  (235)
- [ ] PROFILE_ANALYZER  (83)
- [ ] PROFILE_ACTION  (30)
- [ ] PROFILE_FOLLOW  (20)
- [ ] PROFILE_SPOOFING  (16)
- [ ] PROFILE_GRID  (12)
- [ ] PROFILE_SPOOF  (10)
- [ ] PROFILE  (1)

## MEDIA  (~251 labels, 3 modules)
- [ ] MEDIA_VAULT  (152)
- [ ] MEDIA_WATCH  (97)
- [ ] MEDIA_NOT  (2)

## DM  (~211 labels, 17 modules)
- [ ] DM_KEEP  (66)
- [ ] DM_TRACKING  (50)
- [ ] DM_SEEN  (25)
- [ ] DM_INSTANTS  (24)
- [ ] DM_HIDE  (8)
- [ ] DM_NOTES  (8)
- [ ] DM_UPLOAD  (7)
- [ ] DM_GIF  (6)
- [ ] DM_CONFIRM  (4)
- [ ] DM_ERROR  (3)
- [ ] DM_AUDIO  (2)
- [ ] DM_SHARE  (2)
- [ ] DM_VIDEO  (2)
- [ ] DM_DOWNLOAD  (1)
- [ ] DM_FULL  (1)
- [ ] DM_SEND  (1)
- [ ] DM_VIEW  (1)

## STORAGE  (~189 labels, 50 modules)
- [ ] STORAGE_ACTION  (16)
- [ ] STORAGE_AUTOCLEAR  (13)
- [ ] STORAGE_INFO  (12)
- [ ] STORAGE_RESULT  (12)
- [ ] STORAGE_PROGRESS  (11)
- [ ] STORAGE_ERROR  (10)
- [ ] STORAGE_CATEGORY  (8)
- [ ] STORAGE_MENU  (8)
- [ ] STORAGE_SECTION  (8)
- [ ] STORAGE_MEASURED  (6)
- [ ] STORAGE_CLEANUP  (5)
- [ ] STORAGE_CONFIRM  (5)
- [ ] STORAGE_SEARCH  (5)
- [ ] STORAGE_DESTINATION  (4)
- [ ] STORAGE_PROTECTION  (4)
- [ ] STORAGE_SORT  (4)
- [ ] STORAGE_COMPRESS  (3)
- [ ] STORAGE_EXTENSION  (3)
- [ ] STORAGE_KIND  (3)
- [ ] STORAGE_LEVEL  (3)
- [ ] STORAGE_PASTE  (3)
- [ ] STORAGE_SCAN  (3)
- [ ] STORAGE_TOOL  (3)
- [ ] STORAGE_CLIPBOARD  (2)
- [ ] STORAGE_EMPTY  (2)
- [ ] STORAGE_ITEM  (2)
- [ ] STORAGE_LARGEST  (2)
- [ ] STORAGE_NEW  (2)
- [ ] STORAGE_NO  (2)
- [ ] STORAGE_RENAME  (2)
- [ ] STORAGE_SELECT  (2)
- [ ] STORAGE_UNAVAILABLE  (2)
- [ ] STORAGE_VIEW  (2)
- [ ] STORAGE_ANALYZE  (1)
- [ ] STORAGE_ARCHIVE  (1)
- [ ] STORAGE_AT  (1)
- [ ] STORAGE_CANCEL  (1)
- [ ] STORAGE_CHIP  (1)
- [ ] STORAGE_CREATE  (1)
- [ ] STORAGE_DEDUPE  (1)
- [ ] STORAGE_DEVICE  (1)
- [ ] STORAGE_DONE  (1)
- [ ] STORAGE_MEASURING  (1)
- [ ] STORAGE_OK  (1)
- [ ] STORAGE_OVERVIEW  (1)
- [ ] STORAGE_PERCENT  (1)
- [ ] STORAGE_SCANNING  (1)
- [ ] STORAGE_SHOW  (1)
- [ ] STORAGE_SKIPPED  (1)
- [ ] STORAGE_TITLE  (1)

## WHATS  (~171 labels, 1 modules)
- [ ] WHATS_NEW  (171)

## REELS  (~122 labels, 10 modules)
- [ ] REELS_LIMIT  (61)
- [ ] REELS_PLAYBACK  (18)
- [ ] REELS_FILTERING  (11)
- [ ] REELS_SCROLL  (11)
- [ ] REELS_BREAK  (6)
- [ ] REELS_USAGE  (6)
- [ ] REELS_LIKE  (4)
- [ ] REELS_AUTO  (2)
- [ ] REELS_REPOST  (2)
- [ ] REELS_VIEW  (1)

## BACKUP  (~113 labels, 39 modules)
- [ ] BACKUP_RESTORE  (19)
- [ ] BACKUP_STAGE  (10)
- [ ] BACKUP_ERROR  (7)
- [ ] BACKUP_HUB  (7)
- [ ] BACKUP_AUTO  (6)
- [ ] BACKUP_PASSWORD  (6)
- [ ] BACKUP_ACCOUNT  (5)
- [ ] BACKUP_STORAGE  (4)
- [ ] BACKUP_BACK  (3)
- [ ] BACKUP_DELETE  (3)
- [ ] BACKUP_DRIVE  (3)
- [ ] BACKUP_LAST  (3)
- [ ] BACKUP_SET  (3)
- [ ] BACKUP_SIGN  (3)
- [ ] BACKUP_ENCRYPTION  (2)
- [ ] BACKUP_FEATURES  (2)
- [ ] BACKUP_LICENSE  (2)
- [ ] BACKUP_RETENTION  (2)
- [ ] BACKUP_SIGNING  (2)
- [ ] BACKUP_UP  (2)
- [ ] BACKUP_ALLOW  (1)
- [ ] BACKUP_ALL  (1)
- [ ] BACKUP_BACKUP  (1)
- [ ] BACKUP_CANCEL  (1)
- [ ] BACKUP_CANCELLING  (1)
- [ ] BACKUP_CHANGE  (1)
- [ ] BACKUP_COMPONENT  (1)
- [ ] BACKUP_CONTINUE  (1)
- [ ] BACKUP_ENCRYPT  (1)
- [ ] BACKUP_EXPORT  (1)
- [ ] BACKUP_FAILED  (1)
- [ ] BACKUP_KEEP  (1)
- [ ] BACKUP_LOADING  (1)
- [ ] BACKUP_OK  (1)
- [ ] BACKUP_OPTIONS  (1)
- [ ] BACKUP_RUNNING  (1)
- [ ] BACKUP_SAVE  (1)
- [ ] BACKUP_TITLE  (1)
- [ ] BACKUP_UNKNOWN  (1)

## NOTIF  (~113 labels, 29 modules)
- [ ] NOTIF_LOG  (25)
- [ ] NOTIF_CAT  (14)
- [ ] NOTIF_HAPTICS  (6)
- [ ] NOTIF_ANIMATION  (5)
- [ ] NOTIF_BACKGROUND  (5)
- [ ] NOTIF_DURATION  (5)
- [ ] NOTIF_FEATURE  (5)
- [ ] NOTIF_STACKING  (5)
- [ ] NOTIF_PREVIEW  (4)
- [ ] NOTIF_PRIORITY  (4)
- [ ] NOTIF_SHOW  (4)
- [ ] NOTIF_BURST  (3)
- [ ] NOTIF_POSITION  (3)
- [ ] NOTIF_RESET  (3)
- [ ] NOTIF_STYLE  (3)
- [ ] NOTIF_FEATURES  (2)
- [ ] NOTIF_GENERIC  (2)
- [ ] NOTIF_ICON  (2)
- [ ] NOTIF_MAX  (2)
- [ ] NOTIF_SWIPE  (2)
- [ ] NOTIF_A11Y  (1)
- [ ] NOTIF_AND  (1)
- [ ] NOTIF_APPEARANCE  (1)
- [ ] NOTIF_BEHAVIOUR  (1)
- [ ] NOTIF_CORNER  (1)
- [ ] NOTIF_GLOBAL  (1)
- [ ] NOTIF_SETTINGS  (1)
- [ ] NOTIF_SOUND  (1)
- [ ] NOTIF_USE  (1)

## STORIES  (~113 labels, 10 modules)
- [ ] STORIES_ARCHIVE  (65)
- [ ] STORIES_FILTERING  (11)
- [ ] STORIES_PLAYBACK  (10)
- [ ] STORIES_MANUALLY  (9)
- [ ] STORIES_CONFIRM  (6)
- [ ] STORIES_BUTTON  (4)
- [ ] STORIES_BAR  (2)
- [ ] STORIES_LAYOUT  (2)
- [ ] STORIES_STOP  (2)
- [ ] STORIES_VIEWERS  (2)

## CHAT  (~102 labels, 1 modules)
- [ ] CHAT_THEME  (102)

## FOLLOW  (~87 labels, 1 modules)
- [ ] FOLLOW_REQUESTS  (87)

## ACTION  (~80 labels, 1 modules)
- [ ] ACTION_BUTTON  (80)

## SAVE  (~75 labels, 2 modules)
- [ ] SAVE_ALL  (74)
- [ ] SAVE_LABEL  (1)

## DOWNLOADS  (~73 labels, 13 modules)
- [ ] DOWNLOADS_STATUS  (14)
- [ ] DOWNLOADS_CLEAR  (9)
- [ ] DOWNLOADS_DESTINATION  (9)
- [ ] DOWNLOADS_PILL  (8)
- [ ] DOWNLOADS_PROCESSOR  (8)
- [ ] DOWNLOADS_BANNER  (6)
- [ ] DOWNLOADS_FILTER  (5)
- [ ] DOWNLOADS_FLOATING  (5)
- [ ] DOWNLOADS_DELETE  (3)
- [ ] DOWNLOADS_SELECT  (2)
- [ ] DOWNLOADS_SELECTED  (2)
- [ ] DOWNLOADS_AUTO  (1)
- [ ] DOWNLOADS_DESELECT  (1)

## DEVICE  (~67 labels, 1 modules)
- [ ] DEVICE_ID  (67)

## FEED  (~60 labels, 9 modules)
- [ ] FEED_FILTERING  (16)
- [ ] FEED_HEADER  (14)
- [ ] FEED_ACTION  (8)
- [ ] FEED_GIF  (7)
- [ ] FEED_COMMENTS  (6)
- [ ] FEED_IMAGE  (4)
- [ ] FEED_LIKE  (2)
- [ ] FEED_REPOST  (2)
- [ ] FEED_COPY  (1)

## DOWNLOAD  (~45 labels, 5 modules)
- [ ] DOWNLOAD_OPTIONS  (38)
- [ ] DOWNLOAD_MUSIC  (4)
- [ ] DOWNLOAD_ERROR  (1)
- [ ] DOWNLOAD_FULL  (1)
- [ ] DOWNLOAD_URL  (1)

## FR  (~45 labels, 2 modules)
- [ ] FR_MENU  (36)
- [ ] FR_SYMBOLS  (9)

## MESSAGES  (~44 labels, 1 modules)
- [ ] MESSAGES_ONLY  (44)

## AUTO  (~41 labels, 1 modules)
- [ ] AUTO_SAVE  (41)

## QUICK  (~41 labels, 1 modules)
- [ ] QUICK_CONTROLS  (41)

## INTERFACE  (~39 labels, 4 modules)
- [ ] INTERFACE_TAB  (30)
- [ ] INTERFACE_LAUNCH  (6)
- [ ] INTERFACE_MESSAGES  (2)
- [ ] INTERFACE_STORIES  (1)

## DATE  (~38 labels, 1 modules)
- [ ] DATE_FORMAT  (38)

## GRID  (~38 labels, 1 modules)
- [ ] GRID_FEED  (38)

## ENCODING  (~37 labels, 16 modules)
- [ ] ENCODING_AUDIO  (6)
- [ ] ENCODING_VIDEO  (6)
- [ ] ENCODING_H264  (5)
- [ ] ENCODING_ADVANCED  (3)
- [ ] ENCODING_RESET  (3)
- [ ] ENCODING_FASTSTART  (2)
- [ ] ENCODING_QUALITY  (2)
- [ ] ENCODING_SETTINGS  (2)
- [ ] ENCODING_CRF  (1)
- [ ] ENCODING_LEARN  (1)
- [ ] ENCODING_MAX  (1)
- [ ] ENCODING_PIXEL  (1)
- [ ] ENCODING_PRESET  (1)
- [ ] ENCODING_RESOLUTION  (1)
- [ ] ENCODING_SECTION  (1)
- [ ] ENCODING_VALUE  (1)

## PLAYBACK  (~34 labels, 21 modules)
- [ ] PLAYBACK_ACTION  (8)
- [ ] PLAYBACK_SKIP  (4)
- [ ] PLAYBACK_FRAME  (2)
- [ ] PLAYBACK_NEXT  (2)
- [ ] PLAYBACK_OPEN  (2)
- [ ] PLAYBACK_AUTO  (1)
- [ ] PLAYBACK_CONTROLS  (1)
- [ ] PLAYBACK_FULL  (1)
- [ ] PLAYBACK_KEEP  (1)
- [ ] PLAYBACK_LONG  (1)
- [ ] PLAYBACK_MUTE  (1)
- [ ] PLAYBACK_PAUSE  (1)
- [ ] PLAYBACK_PIP  (1)
- [ ] PLAYBACK_PLAY  (1)
- [ ] PLAYBACK_POSITION  (1)
- [ ] PLAYBACK_PREVIOUS  (1)
- [ ] PLAYBACK_RESET  (1)
- [ ] PLAYBACK_SAVE  (1)
- [ ] PLAYBACK_TAP  (1)
- [ ] PLAYBACK_TITLE  (1)
- [ ] PLAYBACK_VOLUME  (1)

## PROFILES  (~34 labels, 15 modules)
- [ ] PROFILES_CREATE  (6)
- [ ] PROFILES_ACCOUNT  (4)
- [ ] PROFILES_ACTION  (3)
- [ ] PROFILES_DUPLICATE  (3)
- [ ] PROFILES_LIST  (3)
- [ ] PROFILES_DEFAULT  (2)
- [ ] PROFILES_DELETE  (2)
- [ ] PROFILES_INVALID  (2)
- [ ] PROFILES_LOGGED  (2)
- [ ] PROFILES_SWITCHED  (2)
- [ ] PROFILES_NAME  (1)
- [ ] PROFILES_RENAME  (1)
- [ ] PROFILES_SETTINGS  (1)
- [ ] PROFILES_SHOW  (1)
- [ ] PROFILES_TITLE  (1)

## UPDATES  (~24 labels, 16 modules)
- [ ] UPDATES_HINT  (3)
- [ ] UPDATES_SUGGEST  (3)
- [ ] UPDATES_UPDATE  (3)
- [ ] UPDATES_ADD  (2)
- [ ] UPDATES_WEBSITE  (2)
- [ ] UPDATES_ALSO  (1)
- [ ] UPDATES_AVAILABLE  (1)
- [ ] UPDATES_CHANGES  (1)
- [ ] UPDATES_CLOSE  (1)
- [ ] UPDATES_COLLAPSED  (1)
- [ ] UPDATES_DOWNLOAD  (1)
- [ ] UPDATES_EXPANDED  (1)
- [ ] UPDATES_LATEST  (1)
- [ ] UPDATES_MISSED  (1)
- [ ] UPDATES_SKIP  (1)
- [ ] UPDATES_YOU  (1)

## LOCATION  (~21 labels, 14 modules)
- [ ] LOCATION_PICKER  (4)
- [ ] LOCATION_ENABLE  (2)
- [ ] LOCATION_NAME  (2)
- [ ] LOCATION_SAVED  (2)
- [ ] LOCATION_UPDATED  (2)
- [ ] LOCATION_ADD  (1)
- [ ] LOCATION_CHANGE  (1)
- [ ] LOCATION_CURRENT  (1)
- [ ] LOCATION_DEFAULT  (1)
- [ ] LOCATION_MENU  (1)
- [ ] LOCATION_NO  (1)
- [ ] LOCATION_RENAME  (1)
- [ ] LOCATION_SELECT  (1)
- [ ] LOCATION_SETTINGS  (1)

## UFI  (~21 labels, 2 modules)
- [ ] UFI_BUTTONS  (12)
- [ ] UFI_BUTTON  (9)

## SETTINGS  (~20 labels, 14 modules)
- [ ] SETTINGS_LOCK  (5)
- [ ] SETTINGS_SEARCH  (3)
- [ ] SETTINGS_ADS  (1)
- [ ] SETTINGS_DOWNLOAD  (1)
- [ ] SETTINGS_FEED  (1)
- [ ] SETTINGS_GENERAL  (1)
- [ ] SETTINGS_GRID  (1)
- [ ] SETTINGS_INSTANTS  (1)
- [ ] SETTINGS_INTERFACE  (1)
- [ ] SETTINGS_LOCKED  (1)
- [ ] SETTINGS_MESSAGES  (1)
- [ ] SETTINGS_PROFILE  (1)
- [ ] SETTINGS_REELS  (1)
- [ ] SETTINGS_STORIES  (1)

## CRASH  (~17 labels, 1 modules)
- [ ] CRASH_LOGS  (17)

## STORY  (~15 labels, 2 modules)
- [ ] STORY_GRADIENT  (11)
- [ ] STORY_MENU  (4)

## COLOR  (~14 labels, 1 modules)
- [ ] COLOR_PICKER  (14)

## FEATURE  (~13 labels, 2 modules)
- [ ] FEATURE_LOCK  (11)
- [ ] FEATURE_REQUIRES  (2)

## CLEAR  (~12 labels, 4 modules)
- [ ] CLEAR_CACHES  (9)
- [ ] CLEAR  (1)
- [ ] CLEAR_BADGES  (1)
- [ ] CLEAR_CAHCES  (1)

## DOWNLOADER  (~12 labels, 2 modules)
- [ ] DOWNLOADER_MEDIA  (10)
- [ ] DOWNLOADER_SHARE  (2)

## USERS  (~12 labels, 1 modules)
- [ ] USERS_LIST  (12)

## ADS  (~10 labels, 3 modules)
- [ ] ADS_HIDE  (6)
- [ ] ADS_OPEN  (2)
- [ ] ADS_SURFACES  (2)

## AUDIO  (~9 labels, 2 modules)
- [ ] AUDIO_TRIM  (8)
- [ ] AUDIO_URL  (1)

## FPE  (~9 labels, 9 modules)
- [ ] FPE_FLTDIV  (1)
- [ ] FPE_FLTINV  (1)
- [ ] FPE_FLTOVF  (1)
- [ ] FPE_FLTRES  (1)
- [ ] FPE_FLTSUB  (1)
- [ ] FPE_FLTUND  (1)
- [ ] FPE_INTDIV  (1)
- [ ] FPE_INTOVF  (1)
- [ ] FPE_NOOP  (1)

## ILL  (~9 labels, 9 modules)
- [ ] ILL_BADSTK  (1)
- [ ] ILL_COPROC  (1)
- [ ] ILL_ILLADR  (1)
- [ ] ILL_ILLOPC  (1)
- [ ] ILL_ILLOPN  (1)
- [ ] ILL_ILLTRP  (1)
- [ ] ILL_NOOP  (1)
- [ ] ILL_PRVOPC  (1)
- [ ] ILL_PRVREG  (1)

## DUPLICATE  (~8 labels, 2 modules)
- [ ] DUPLICATE_ALERT  (6)
- [ ] DUPLICATE_DESTINATION  (2)

## IMPORT  (~7 labels, 1 modules)
- [ ] IMPORT_SETTINGS  (7)

## NOTE  (~7 labels, 1 modules)
- [ ] NOTE_THEMES  (7)

## APP  (~6 labels, 4 modules)
- [ ] APP_ICON  (3)
- [ ] APP_CENTER  (1)
- [ ] APP_FOREGROUND  (1)
- [ ] APP_UTILITIES  (1)

## EXPORT  (~6 labels, 2 modules)
- [ ] EXPORT_SETTINGS  (5)
- [ ] EXPORT  (1)

## REPLACE  (~6 labels, 1 modules)
- [ ] REPLACE_IG  (6)

## RESET  (~6 labels, 2 modules)
- [ ] RESET_SETTINGS  (5)
- [ ] RESET_TO  (1)

## SAFE  (~6 labels, 1 modules)
- [ ] SAFE_MODE  (6)

## DELETE  (~5 labels, 2 modules)
- [ ] DELETE_WITH  (4)
- [ ] DELETE  (1)

## DESTINATION  (~5 labels, 4 modules)
- [ ] DESTINATION_IG  (2)
- [ ] DESTINATION_CLIPBOARD  (1)
- [ ] DESTINATION_LOCKED  (1)
- [ ] DESTINATION_UNLOCK  (1)

## FIX  (~5 labels, 2 modules)
- [ ] FIX_POPUPS  (3)
- [ ] FIX_DUPLICATE  (2)

## INSTANTS  (~5 labels, 1 modules)
- [ ] INSTANTS_USERS  (5)

## RELAUNCH  (~5 labels, 5 modules)
- [ ] RELAUNCH_DATA  (1)
- [ ] RELAUNCH_LATER  (1)
- [ ] RELAUNCH_MANUAL  (1)
- [ ] RELAUNCH_NOW  (1)
- [ ] RELAUNCH_SETTING  (1)

## BUS  (~4 labels, 4 modules)
- [ ] BUS_ADRALN  (1)
- [ ] BUS_ADRERR  (1)
- [ ] BUS_NOOP  (1)
- [ ] BUS_OBJERR  (1)

## CONFIRM  (~4 labels, 2 modules)
- [ ] CONFIRM_PULL  (2)
- [ ] CONFIRM_SCROLL  (2)

## GIF  (~4 labels, 1 modules)
- [ ] GIF_TITLE  (4)

## MANAGE  (~4 labels, 1 modules)
- [ ] MANAGE_SETTINGS  (4)

## RECENT  (~4 labels, 2 modules)
- [ ] RECENT_CHATS  (3)
- [ ] RECENT  (1)

## ADD  (~3 labels, 1 modules)
- [ ] ADD_USER  (3)

## CONTACT  (~3 labels, 2 modules)
- [ ] CONTACT_SUPPORT  (2)
- [ ] CONTACT_AND  (1)

## COPIED  (~3 labels, 2 modules)
- [ ] COPIED_TO  (2)
- [ ] COPIED_VALUE  (1)

## SEGV  (~3 labels, 3 modules)
- [ ] SEGV_ACCERR  (1)
- [ ] SEGV_MAPERR  (1)
- [ ] SEGV_NOOP  (1)

## COPY  (~2 labels, 2 modules)
- [ ] COPY_LINK  (1)
- [ ] COPY_SETTING  (1)

## DISABLE  (~2 labels, 1 modules)
- [ ] DISABLE_FEATURES  (2)

## ERROR  (~2 labels, 2 modules)
- [ ] ERROR  (1)
- [ ] ERROR_BANNER  (1)

## FFMPEG  (~2 labels, 1 modules)
- [ ] FFMPEG_LOGS  (2)

## IPHONE  (~2 labels, 2 modules)
- [ ] IPHONE_OS  (1)
- [ ] IPHONE_SIMULATOR  (1)

## TRAP  (~2 labels, 2 modules)
- [ ] TRAP_BRKPT  (1)
- [ ] TRAP_TRACE  (1)

## TWEAK  (~2 labels, 1 modules)
- [ ] TWEAK_LANGUAGE  (2)

## TYPE  (~2 labels, 1 modules)
- [ ] TYPE_ENCODING  (2)

## VIDEO  (~2 labels, 2 modules)
- [ ] VIDEO_AND  (1)
- [ ] VIDEO_URL  (1)

## WARNING  (~2 labels, 2 modules)
- [ ] WARNING  (1)
- [ ] WARNING_BANNER  (1)

## X86  (~2 labels, 2 modules)
- [ ] X86_32  (1)
- [ ] X86_64  (1)

## ACCOUNT  (~1 labels, 1 modules)
- [ ] ACCOUNT_AND  (1)

## APPLE  (~1 labels, 1 modules)
- [ ] APPLE_TVOS  (1)

## ARCHITECTURE  (~1 labels, 1 modules)
- [ ] ARCHITECTURE_UNKNOWN  (1)

## ARMV6  (~1 labels, 1 modules)
- [ ] ARMV6  (1)

## ARMV7  (~1 labels, 1 modules)
- [ ] ARMV7  (1)

## ASSERT  (~1 labels, 1 modules)
- [ ] ASSERT  (1)

## AUTOINCREMENT  (~1 labels, 1 modules)
- [ ] AUTOINCREMENT  (1)

## BTLFF  (~1 labels, 1 modules)
- [ ] BTLFF  (1)

## CEJKX  (~1 labels, 1 modules)
- [ ] CEJKX  (1)

## CLIPS  (~1 labels, 1 modules)
- [ ] CLIPS  (1)

## CONTINUE  (~1 labels, 1 modules)
- [ ] CONTINUE  (1)

## CONTRIBUTE  (~1 labels, 1 modules)
- [ ] CONTRIBUTE_LABEL  (1)

## DBBBANY  (~1 labels, 1 modules)
- [ ] DBBBANY  (1)

## DEBUG  (~1 labels, 1 modules)
- [ ] DEBUG  (1)

## DEFAULT  (~1 labels, 1 modules)
- [ ] DEFAULT  (1)

## DEVELOPER  (~1 labels, 1 modules)
- [ ] DEVELOPER_SECTION  (1)

## DIRECT  (~1 labels, 1 modules)
- [ ] DIRECT  (1)

## EAGAIN  (~1 labels, 1 modules)
- [ ] EAGAIN  (1)

## EBUSY  (~1 labels, 1 modules)
- [ ] EBUSY  (1)

## EDEADLK  (~1 labels, 1 modules)
- [ ] EDEADLK  (1)

## EEEEE  (~1 labels, 1 modules)
- [ ] EEEEE  (1)

## EINVAL  (~1 labels, 1 modules)
- [ ] EINVAL  (1)

## ENOMEM  (~1 labels, 1 modules)
- [ ] ENOMEM  (1)

## EPERM  (~1 labels, 1 modules)
- [ ] EPERM  (1)

## FRZRU9  (~1 labels, 1 modules)
- [ ] FRZRU9  (1)

## GOH4V  (~1 labels, 1 modules)
- [ ] GOH4V  (1)

## HCVIUM  (~1 labels, 1 modules)
- [ ] HCVIUM  (1)

## HTHTHTT  (~1 labels, 1 modules)
- [ ] HTHTHTT  (1)

## I6  (~1 labels, 1 modules)
- [ ] I6_7X  (1)

## IGPLUS  (~1 labels, 1 modules)
- [ ] IGPLUS_SETTINGS  (1)

## INTEGER  (~1 labels, 1 modules)
- [ ] INTEGER  (1)

## ISO8601  (~1 labels, 1 modules)
- [ ] ISO8601  (1)

## J1C9J  (~1 labels, 1 modules)
- [ ] J1C9J  (1)

## J1D9J  (~1 labels, 1 modules)
- [ ] J1D9J  (1)

## J5A9K  (~1 labels, 1 modules)
- [ ] J5A9K  (1)

## J9A9K  (~1 labels, 1 modules)
- [ ] J9A9K  (1)

## J9C9J  (~1 labels, 1 modules)
- [ ] J9C9J  (1)

## JAA9K  (~1 labels, 1 modules)
- [ ] JAA9K  (1)

## JIA9K  (~1 labels, 1 modules)
- [ ] JIA9K  (1)

## JIC9K  (~1 labels, 1 modules)
- [ ] JIC9K  (1)

## JID9K  (~1 labels, 1 modules)
- [ ] JID9K  (1)

## JMA9J  (~1 labels, 1 modules)
- [ ] JMA9J  (1)

## JMB9K  (~1 labels, 1 modules)
- [ ] JMB9K  (1)

## JMD9K  (~1 labels, 1 modules)
- [ ] JMD9K  (1)

## JOIN  (~1 labels, 1 modules)
- [ ] JOIN_DISCORD  (1)

## JQD9J  (~1 labels, 1 modules)
- [ ] JQD9J  (1)

## JUA9K  (~1 labels, 1 modules)
- [ ] JUA9K  (1)

## JYA9K  (~1 labels, 1 modules)
- [ ] JYA9K  (1)

## LICENSE  (~1 labels, 1 modules)
- [ ] LICENSE_REQUIRED  (1)

## LOADING  (~1 labels, 1 modules)
- [ ] LOADING  (1)

## MAC  (~1 labels, 1 modules)
- [ ] MAC_OS  (1)

## MULTIPLE  (~1 labels, 1 modules)
- [ ] MULTIPLE_URLS  (1)

## MUSIC  (~1 labels, 1 modules)
- [ ] MUSIC_STICKER  (1)

## NEXT  (~1 labels, 1 modules)
- [ ] NEXT_LABEL  (1)

## NO  (~1 labels, 1 modules)
- [ ] NO_DOWNLOADS  (1)

## OBJC  (~1 labels, 1 modules)
- [ ] OBJC_  (1)

## OK  (~1 labels, 1 modules)
- [ ] OK_LABEL  (1)

## OPEN  (~1 labels, 1 modules)
- [ ] OPEN_PHOTOS  (1)

## OS  (~1 labels, 1 modules)
- [ ] OS_UNKNOWN  (1)

## PATCH  (~1 labels, 1 modules)
- [ ] PATCH  (1)

## PKCS7  (~1 labels, 1 modules)
- [ ] PKCS7  (1)

## PPC64  (~1 labels, 1 modules)
- [ ] PPC64  (1)

## PVLVUT  (~1 labels, 1 modules)
- [ ] PVLVUT  (1)

## RENAME  (~1 labels, 1 modules)
- [ ] RENAME  (1)

## RFC822  (~1 labels, 1 modules)
- [ ] RFC822  (1)

## RRGGBB  (~1 labels, 1 modules)
- [ ] RRGGBB  (1)

## RRGGBBAA  (~1 labels, 1 modules)
- [ ] RRGGBBAA  (1)

## RUNNING  (~1 labels, 1 modules)
- [ ] RUNNING_IN  (1)

## SEARCH  (~1 labels, 1 modules)
- [ ] SEARCH  (1)

## SHARE  (~1 labels, 1 modules)
- [ ] SHARE  (1)

## SHOW  (~1 labels, 1 modules)
- [ ] SHOW_IN  (1)

## SIGABRT  (~1 labels, 1 modules)
- [ ] SIGABRT  (1)

## SIGALRM  (~1 labels, 1 modules)
- [ ] SIGALRM  (1)

## SIGBUS  (~1 labels, 1 modules)
- [ ] SIGBUS  (1)

## SIGCHLD  (~1 labels, 1 modules)
- [ ] SIGCHLD  (1)

## SIGCONT  (~1 labels, 1 modules)
- [ ] SIGCONT  (1)

## SIGEMT  (~1 labels, 1 modules)
- [ ] SIGEMT  (1)

## SIGFPE  (~1 labels, 1 modules)
- [ ] SIGFPE  (1)

## SIGHUP  (~1 labels, 1 modules)
- [ ] SIGHUP  (1)

## SIGILL  (~1 labels, 1 modules)
- [ ] SIGILL  (1)

## SIGINFO  (~1 labels, 1 modules)
- [ ] SIGINFO  (1)

## SIGINT  (~1 labels, 1 modules)
- [ ] SIGINT  (1)

## SIGIO  (~1 labels, 1 modules)
- [ ] SIGIO  (1)

## SIGIOT  (~1 labels, 1 modules)
- [ ] SIGIOT  (1)

## SIGKILL  (~1 labels, 1 modules)
- [ ] SIGKILL  (1)

## SIGNAL  (~1 labels, 1 modules)
- [ ] SIGNAL  (1)

## SIGPIPE  (~1 labels, 1 modules)
- [ ] SIGPIPE  (1)

## SIGPROF  (~1 labels, 1 modules)
- [ ] SIGPROF  (1)

## SIGQUIT  (~1 labels, 1 modules)
- [ ] SIGQUIT  (1)

## SIGSEGV  (~1 labels, 1 modules)
- [ ] SIGSEGV  (1)

## SIGSTOP  (~1 labels, 1 modules)
- [ ] SIGSTOP  (1)

## SIGSYS  (~1 labels, 1 modules)
- [ ] SIGSYS  (1)

## SIGTERM  (~1 labels, 1 modules)
- [ ] SIGTERM  (1)

## SIGTRAP  (~1 labels, 1 modules)
- [ ] SIGTRAP  (1)

## SIGTSTP  (~1 labels, 1 modules)
- [ ] SIGTSTP  (1)

## SIGTTIN  (~1 labels, 1 modules)
- [ ] SIGTTIN  (1)

## SIGTTOU  (~1 labels, 1 modules)
- [ ] SIGTTOU  (1)

## SIGURG  (~1 labels, 1 modules)
- [ ] SIGURG  (1)

## SIGUSR1  (~1 labels, 1 modules)
- [ ] SIGUSR1  (1)

## SIGUSR2  (~1 labels, 1 modules)
- [ ] SIGUSR2  (1)

## SIGVTALRM  (~1 labels, 1 modules)
- [ ] SIGVTALRM  (1)

## SIGWINCH  (~1 labels, 1 modules)
- [ ] SIGWINCH  (1)

## SIGXCPU  (~1 labels, 1 modules)
- [ ] SIGXCPU  (1)

## SIGXFSZ  (~1 labels, 1 modules)
- [ ] SIGXFSZ  (1)

## SUGGESTED  (~1 labels, 1 modules)
- [ ] SUGGESTED  (1)

## SUPPORT  (~1 labels, 1 modules)
- [ ] SUPPORT_SECTION  (1)

## SYNCING  (~1 labels, 1 modules)
- [ ] SYNCING  (1)

## TPLHLH  (~1 labels, 1 modules)
- [ ] TPLHLH  (1)

## TTLPP  (~1 labels, 1 modules)
- [ ] TTLPP  (1)

## UNAUTHORIZED  (~1 labels, 1 modules)
- [ ] UNAUTHORIZED  (1)

## UUUUUU  (~1 labels, 1 modules)
- [ ] UUUUUU  (1)

## VERBOSE  (~1 labels, 1 modules)
- [ ] VERBOSE  (1)

## VERSION  (~1 labels, 1 modules)
- [ ] VERSION_HISTORY  (1)

## VPAAE2  (~1 labels, 1 modules)
- [ ] VPAAE2  (1)

## YVCSZ  (~1 labels, 1 modules)
- [ ] YVCSZ  (1)
