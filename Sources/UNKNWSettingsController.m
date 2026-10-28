#import "UNKNW.h"
#import "Features.h"
#import "UNKNWSettingsController.h"
#import "Core/UNKNWLicense.h"
#import <objc/runtime.h>

static const void *kFeatureKey = &kFeatureKey;

#pragma mark - Settings panel

@implementation UNKNWSettingsController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"UNKNW";
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(dismissSelf)];
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark Layout

// Section 0 = General (master switch + license). Sections 1..N = categories.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1 + (NSInteger)UNKNWCategories().count;
}

- (NSString *)categoryForSection:(NSInteger)section {
    return UNKNWCategories()[section - 1];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 2; // master switch + license
    return (NSInteger)UNKNWFeaturesInCategory([self categoryForSection:section]).count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return (section == 0) ? @"General" : [self categoryForSection:section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"Toggling a feature takes effect the next time Instagram is relaunched.";
    }
    return nil;
}

#pragma mark Cells

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                   reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Enable UNKNW";
            cell.detailTextLabel.text = @"Master switch for all features";
            UISwitch *toggle = [UISwitch new];
            toggle.on = UNKNWPrefBool(kUNKNWEnabledKey, YES);
            objc_setAssociatedObject(toggle, kFeatureKey, kUNKNWEnabledKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [toggle addTarget:self action:@selector(masterChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
        } else {
            NSString *stored = UNKNWLicense.shared.key;
            cell.textLabel.text = @"License";
            cell.detailTextLabel.text = stored.length ? @"Tap to manage · key saved" : @"Tap to enter your license key";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
        return cell;
    }

    UNKNWFeature *feature = UNKNWFeaturesInCategory([self categoryForSection:indexPath.section])[indexPath.row];
    cell.textLabel.text = feature.title;
    cell.detailTextLabel.text = feature.detail;

    switch (feature.kind) {
        case UNKNWFeatureKindToggle: {
            UISwitch *toggle = [UISwitch new];
            toggle.on = UNKNWPrefBool(feature.key, feature.defaultBool);
            objc_setAssociatedObject(toggle, kFeatureKey, feature, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
            break;
        }
        case UNKNWFeatureKindStepper: {
            double value = UNKNWPrefNumber(feature.key, feature.defaultNumber);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ — %ld", feature.detail, (long)value];
            UIStepper *stepper = [UIStepper new];
            stepper.minimumValue = feature.minValue;
            stepper.maximumValue = feature.maxValue;
            stepper.stepValue = feature.stepValue;
            stepper.value = value;
            objc_setAssociatedObject(stepper, kFeatureKey, feature, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [stepper addTarget:self action:@selector(stepperChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = stepper;
            break;
        }
        case UNKNWFeatureKindSegment: {
            UISegmentedControl *segment = [[UISegmentedControl alloc] initWithItems:feature.options];
            segment.selectedSegmentIndex = (NSInteger)UNKNWPrefNumber(feature.key, feature.defaultNumber);
            [segment sizeToFit];
            objc_setAssociatedObject(segment, kFeatureKey, feature, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [segment addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = segment;
            break;
        }
    }
    return cell;
}

#pragma mark Actions

- (void)masterChanged:(UISwitch *)toggle {
    UNKNWPrefSetBool(kUNKNWEnabledKey, toggle.isOn);
}

- (void)toggleChanged:(UISwitch *)toggle {
    UNKNWFeature *feature = objc_getAssociatedObject(toggle, kFeatureKey);
    if (feature) UNKNWPrefSetBool(feature.key, toggle.isOn);
}

- (void)stepperChanged:(UIStepper *)stepper {
    UNKNWFeature *feature = objc_getAssociatedObject(stepper, kFeatureKey);
    if (feature) {
        UNKNWPrefSetNumber(feature.key, stepper.value);
        [self.tableView reloadData];
    }
}

- (void)segmentChanged:(UISegmentedControl *)segment {
    UNKNWFeature *feature = objc_getAssociatedObject(segment, kFeatureKey);
    if (feature) UNKNWPrefSetNumber(feature.key, segment.selectedSegmentIndex);
}

#pragma mark License row

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0 && indexPath.row == 1) {
        [self presentLicenseSheet];
    }
}

- (void)presentLicenseSheet {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"UNKNW License"
                                            message:@"Enter your license key. Settings can be backed up to and restored from the server."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"License key";
        field.text = UNKNWLicense.shared.key;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Save & Validate"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        NSString *key = alert.textFields.firstObject.text;
        [UNKNWLicense.shared validateKey:key completion:^(BOOL valid, NSString *message) {
            [weakSelf toast:valid ? @"License valid" : (message ?: @"Invalid license")];
            [weakSelf.tableView reloadData];
        }];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Back up settings"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        [UNKNWLicense.shared backupSettings:^(BOOL ok, NSString *message) {
            [weakSelf toast:message ?: (ok ? @"Backed up" : @"Backup failed")];
        }];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Restore settings"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        [UNKNWLicense.shared restoreSettings:^(BOOL ok, NSString *message) {
            [weakSelf toast:message ?: (ok ? @"Restored — relaunch to apply" : @"Restore failed")];
            [weakSelf.tableView reloadData];
        }];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)toast:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.4 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
    }];
}

@end

#pragma mark - Gesture handler

@implementation UNKNWGestureHandler

+ (instancetype)shared {
    static UNKNWGestureHandler *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [UNKNWGestureHandler new]; });
    return shared;
}

- (void)handleGesture:(UIGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self presentSettings];
    }
}

#pragma mark UIGestureRecognizerDelegate

// The Home-icon gesture should only begin when the long-press lands on the
// bottom-left corner (where Instagram's Home tab sits). The two-finger gesture
// has no location constraint. Never block the app's own recognizers.
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    if (![gesture.name isEqualToString:@"UNKNWHomeGesture"]) return YES;
    UIView *view = touch.window ?: touch.view;
    if (!view) return NO;
    CGPoint point = [touch locationInView:view];
    CGSize size = view.bounds.size;
    BOOL inTabBarBand = point.y >= size.height - 100.0;
    BOOL inHomeColumn = point.x <= size.width * 0.25;
    return inTabBarBand && inHomeColumn;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}

- (UIViewController *)topViewController {
    UIWindow *keyWindow = nil;
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        if (window.isKeyWindow) { keyWindow = window; break; }
    }
    UIViewController *top = keyWindow.rootViewController;
    while (top.presentedViewController) {
        top = top.presentedViewController;
    }
    return top;
}

- (void)presentSettings {
    UIViewController *top = [self topViewController];
    if (!top) return;
    if ([top isKindOfClass:[UINavigationController class]] &&
        [[(UINavigationController *)top topViewController] isKindOfClass:[UNKNWSettingsController class]]) {
        return;
    }
    UNKNWSettingsController *settings = [[UNKNWSettingsController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settings];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [top presentViewController:nav animated:YES completion:nil];
}

@end
