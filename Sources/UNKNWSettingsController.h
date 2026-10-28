#import <UIKit/UIKit.h>

// The in-app settings panel. On a non-jailbroken install there is no Settings.app
// bundle, so this UITableViewController is the control surface for the tweak.
@interface UNKNWSettingsController : UITableViewController
@end

// Singleton that owns the gesture action and presents the panel. Tweak.x wires a
// gesture recognizer to -[UNKNWGestureHandler handleGesture:].
@interface UNKNWGestureHandler : NSObject
+ (instancetype)shared;
- (void)handleGesture:(UIGestureRecognizer *)gesture;
- (void)presentSettings;
@end
