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
#import <objc/runtime.h>

// Interop: Instagram renders captions/comments/bios in IGCoreTextView, whose
// plain text is exposed on `text`.
@interface IGCoreTextView : UIView
@property (nonatomic, strong) NSString *text;
@end

static const void *kUNKNWCopyInstalled = &kUNKNWCopyInstalled;

static void UNKNWCopyToast(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
            if ([s isKindOfClass:UIWindowScene.class])
                for (UIWindow *w in ((UIWindowScene *)s).windows) if (w.isKeyWindow) { win = w; break; }
        if (!win) return;
        UILabel *l = [UILabel new];
        l.text = @"  Copied  "; l.textColor = UIColor.whiteColor;
        l.backgroundColor = [UIColor colorWithWhite:0 alpha:0.82];
        l.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        l.textAlignment = NSTextAlignmentCenter; l.layer.cornerRadius = 16; l.clipsToBounds = YES;
        [l sizeToFit]; CGRect f = l.frame; f.size.height = 32; f.size.width += 16; l.frame = f;
        l.center = CGPointMake(win.bounds.size.width/2, win.safeAreaInsets.top + 60); l.alpha = 0;
        [win addSubview:l];
        [UIView animateWithDuration:0.2 animations:^{ l.alpha = 1; } completion:^(BOOL _){
            [UIView animateWithDuration:0.3 delay:1.0 options:0 animations:^{ l.alpha = 0; }
                             completion:^(BOOL __){ [l removeFromSuperview]; }]; }];
    });
}

// Interop: the action methods we gate behind a confirmation.
@interface IGFollowController : NSObject @end
@interface IGUFIInteractionCountsView : UIView @end
@interface IGSundialViewerVerticalUFI : UIView @end
@interface IGFeedPhotoView : UIView @end

static UIViewController *UNKNWTopVC(void) {
    UIWindow *win = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
        if ([s isKindOfClass:UIWindowScene.class])
            for (UIWindow *w in ((UIWindowScene *)s).windows) if (w.isKeyWindow) { win = w; break; }
    UIViewController *vc = win.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

static void UNKNWConfirm(NSString *title, void (^onYes)(void)) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *top = UNKNWTopVC();
        if (!top) { if (onYes) onYes(); return; }
        UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:nil
                                                          preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [a addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *_){ if (onYes) onYes(); }]];
        [top presentViewController:a animated:YES completion:nil];
    });
}

%group UNKNWConfirmLike

%hook IGUFIInteractionCountsView           // feed like button
- (void)_onLikeButtonPressed:(id)arg1 {
    if (!UNKNWPrefBool(kUNKNWConfirmLikeKey, NO)) { %orig; return; }
    UNKNWConfirm(@"Like this post?", ^{ %orig; });
}
%end

%hook IGSundialViewerVerticalUFI           // reels like button
- (void)_didTapLikeButton:(id)arg1 {
    if (!UNKNWPrefBool(kUNKNWConfirmLikeKey, NO)) { %orig; return; }
    UNKNWConfirm(@"Like this reel?", ^{ %orig; });
}
%end

%hook IGFeedPhotoView                        // double-tap to like
- (void)_onDoubleTap:(id)arg1 {
    if (!UNKNWPrefBool(kUNKNWConfirmLikeKey, NO)) { %orig; return; }
    UNKNWConfirm(@"Like this post?", ^{ %orig; });
}
%end

%end

%group UNKNWConfirmFollow

%hook IGFollowController
- (void)_didPressFollowButton {
    if (!UNKNWPrefBool(kUNKNWConfirmFollowKey, NO)) { %orig; return; }
    UNKNWConfirm(@"Change follow status?", ^{ %orig; });
}
%end

%end

%group UNKNWCopyText

%hook IGCoreTextView

- (void)didMoveToWindow {
    %orig;
    if (!self.window || objc_getAssociatedObject(self, kUNKNWCopyInstalled)) return;
    objc_setAssociatedObject(self, kUNKNWCopyInstalled, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.userInteractionEnabled = YES;
    UILongPressGestureRecognizer *lp =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(unknw_copyText:)];
    lp.minimumPressDuration = 0.5;
    [self addGestureRecognizer:lp];
}

%new
- (void)unknw_copyText:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    NSString *t = nil;
    @try { t = [self valueForKey:@"text"]; } @catch (__unused id e) {}
    if (t.length) { UIPasteboard.generalPasteboard.string = t; UNKNWCopyToast(); }
}

%end

%end

%group UNKNWDetailedDates
// TODO: substitute [UNKNWFormat detailedStringForDate:] for the timestamp text.
%end

void UNKNWInitConfirmLike(void)    { %init(UNKNWConfirmLike); }
void UNKNWInitConfirmFollow(void)  { %init(UNKNWConfirmFollow); }
void UNKNWInitCopyText(void)       { %init(UNKNWCopyText); }
void UNKNWInitDetailedDates(void)  { %init(UNKNWDetailedDates); }
