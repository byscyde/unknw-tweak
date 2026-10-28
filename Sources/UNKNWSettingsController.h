#import <UIKit/UIKit.h>

// The in-app settings panel. On a non-jailbroken install there is no Settings.app
// bundle, so this UITableViewController is the control surface for the tweak.
@interface UNKNWSettingsController : UITableViewController
@end

// Singleton that owns the gesture action and presents the panel. Tweak.x wires
// the gesture recognizers to -[UNKNWGestureHandler handleGesture:]. It is also
// the recognizers' delegate so the Home-icon gesture only fires in the tab-bar
// corner and never blocks the app's own gestures.
@interface UNKNWGestureHandler : NSObject <UIGestureRecognizerDelegate>
+ (instancetype)shared;
- (void)handleGesture:(UIGestureRecognizer *)gesture;
- (void)presentSettings;
@end
