// Utilities & Customization.
//
//   ConfirmLike / ConfirmFollow: ask before the action to prevent accidental
//     taps. Hook the like / follow action method and, when the matching toggle
//     is ON, present a UIAlertController; call %orig only on confirm.
//   CopyText: add a long-press-to-copy on captions, comments and bios.
//   DetailedDates: replace Instagram's relative timestamps with a full date via
//     UNKNWFormat. Hook the label/formatter that produces the timestamp string
//     and substitute [UNKNWFormat detailedStringForDate:date] (or
//     detailedStringForUnix:) when kUNKNWDetailedDatesKey is ON.

#import "../UNKNW.h"
#import "../Core/UNKNWFormat.h"

%group UNKNWConfirmLike
// TODO: confirm before %orig of the like action when kUNKNWConfirmLikeKey ON.
%end

%group UNKNWConfirmFollow
// TODO: confirm before %orig of the follow action when kUNKNWConfirmFollowKey ON.
%end

%group UNKNWCopyText
// TODO: add long-press copy to caption/comment/bio labels.
%end

%group UNKNWDetailedDates
// TODO: substitute [UNKNWFormat detailedStringForDate:] for the timestamp text.
%end

void UNKNWInitConfirmLike(void)    { %init(UNKNWConfirmLike); }
void UNKNWInitConfirmFollow(void)  { %init(UNKNWConfirmFollow); }
void UNKNWInitCopyText(void)       { %init(UNKNWCopyText); }
void UNKNWInitDetailedDates(void)  { %init(UNKNWDetailedDates); }
