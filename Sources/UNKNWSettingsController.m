#import "UNKNW.h"
#import "Features.h"
#import "UNKNWSettingsController.h"
#import "Core/UNKNWLicense.h"
#import <objc/runtime.h>

static const void *kFeatureKey = &kFeatureKey;

#pragma mark - Category sub-screen

// One per top-level category (Feed, Reels, …). Shows that category's sections
// and renders toggle/stepper/segment rows.
@interface UNKNWCategoryController : UITableViewController
- (instancetype)initWithCategory:(NSString *)category;
@end

@implementation UNKNWCategoryController {
    NSString *_category;
    NSArray<NSString *> *_sections;
}

- (instancetype)initWithCategory:(NSString *)category {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _category = [category copy];
        _sections = UNKNWSectionsInCategory(category);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = _category;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)_sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)UNKNWFeaturesInCategorySection(_category, _sections[section]).count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *name = _sections[section];
    return name.length ? name.uppercaseString : nil;
}

- (UNKNWFeature *)featureAt:(NSIndexPath *)indexPath {
    return UNKNWFeaturesInCategorySection(_category, _sections[indexPath.section])[indexPath.row];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];

    UNKNWFeature *feature = [self featureAt:indexPath];
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

- (void)toggleChanged:(UISwitch *)toggle {
    UNKNWFeature *feature = objc_getAssociatedObject(toggle, kFeatureKey);
    if (feature) UNKNWPrefSetBool(feature.key, toggle.isOn);
}

- (void)stepperChanged:(UIStepper *)stepper {
    UNKNWFeature *feature = objc_getAssociatedObject(stepper, kFeatureKey);
    if (feature) { UNKNWPrefSetNumber(feature.key, stepper.value); [self.tableView reloadData]; }
}

- (void)segmentChanged:(UISegmentedControl *)segment {
    UNKNWFeature *feature = objc_getAssociatedObject(segment, kFeatureKey);
    if (feature) UNKNWPrefSetNumber(feature.key, segment.selectedSegmentIndex);
}

@end

#pragma mark - Diagnostics (class log viewer / share)

@interface UNKNWDiagnosticsController : UIViewController
@end

@implementation UNKNWDiagnosticsController {
    UITextView *_textView;
}

- (NSURL *)logURL {
    NSURL *appSupport = [NSFileManager.defaultManager URLForDirectory:NSApplicationSupportDirectory
                                                             inDomain:NSUserDomainMask
                                                    appropriateForURL:nil create:YES error:nil];
    return [[appSupport URLByAppendingPathComponent:@"UNKNW" isDirectory:YES]
            URLByAppendingPathComponent:@"classes.log"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Diagnostics";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    _textView = [[UITextView alloc] initWithFrame:self.view.bounds];
    _textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _textView.editable = NO;
    _textView.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    [self.view addSubview:_textView];
    self.navigationItem.rightBarButtonItems = @[
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(share)],
        [[UIBarButtonItem alloc] initWithTitle:@"Copy" style:UIBarButtonItemStylePlain target:self action:@selector(copyAll)],
        [[UIBarButtonItem alloc] initWithTitle:@"Clear" style:UIBarButtonItemStylePlain target:self action:@selector(clearLog)],
    ];
    [self reload];
}

- (void)reload {
    NSString *text = [NSString stringWithContentsOfURL:[self logURL] encoding:NSUTF8StringEncoding error:nil];
    _textView.text = text.length ? text
        : @"(empty)\n\nEnable Developer Logging (General), force-quit Instagram, reopen, then navigate. Class names are logged here.";
    if (text.length > 2) {
        [_textView scrollRangeToVisible:NSMakeRange(_textView.text.length - 1, 1)];
    }
}

- (void)share {
    UIActivityViewController *activity =
        [[UIActivityViewController alloc] initWithActivityItems:@[[self logURL]] applicationActivities:nil];
    activity.popoverPresentationController.sourceView = self.view;
    activity.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width - 40, 0, 40, 40);
    [self presentViewController:activity animated:YES completion:nil];
}

- (void)copyAll { UIPasteboard.generalPasteboard.string = _textView.text ?: @""; }

- (void)clearLog {
    [@"" writeToURL:[self logURL] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [self reload];
}

@end

#pragma mark - Root menu

@implementation UNKNWSettingsController {
    NSArray<NSString *> *_categories;
}

- (instancetype)init {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _categories = UNKNWCategories();
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"UNKNW";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self action:@selector(dismissSelf)];
}

- (void)dismissSelf { [self dismissViewControllerAnimated:YES completion:nil]; }

// Section 0: master switch. Section 1: categories. Section 2: license.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    if (section == 1) return (NSInteger)_categories.count;
    return 2; // Account & License, Diagnostics
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return @"Toggling a feature takes effect the next time Instagram is relaunched.";
    if (section == 1 && !UNKNWLicense.shared.isActivated)
        return @"\U0001F512 Locked — activate a license under Account & License to unlock features.";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = @"Enable UNKNW";
        cell.detailTextLabel.text = @"Master switch for all features";
        UISwitch *toggle = [UISwitch new];
        toggle.on = UNKNWPrefBool(kUNKNWEnabledKey, YES);
        [toggle addTarget:self action:@selector(masterChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        return cell;
    }
    if (indexPath.section == 1) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        NSString *category = _categories[indexPath.row];
        cell.textLabel.text = category;
        cell.imageView.image = [UIImage systemImageNamed:UNKNWCategoryIcon(category)];
        cell.imageView.tintColor = [UIColor labelColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.imageView.tintColor = [UIColor labelColor];
    if (indexPath.row == 0) {
        NSString *stored = UNKNWLicense.shared.key;
        BOOL activated = UNKNWLicense.shared.isActivated;
        cell.textLabel.text = @"Account & License";
        cell.detailTextLabel.text = activated ? @"Activated · tap to manage"
            : (stored.length ? @"Not activated · tap to retry" : @"Tap to enter your license key");
        cell.imageView.image = [UIImage systemImageNamed:(activated ? @"checkmark.seal" : @"lock")];
    } else {
        cell.textLabel.text = @"Diagnostics";
        cell.detailTextLabel.text = @"View / share the class log (for hook discovery)";
        cell.imageView.image = [UIImage systemImageNamed:@"ladybug"];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1) {
        NSString *category = _categories[indexPath.row];
        [self.navigationController pushViewController:[[UNKNWCategoryController alloc] initWithCategory:category] animated:YES];
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            [self presentLicenseSheet];
        } else {
            [self.navigationController pushViewController:[UNKNWDiagnosticsController new] animated:YES];
        }
    }
}

- (void)masterChanged:(UISwitch *)toggle { UNKNWPrefSetBool(kUNKNWEnabledKey, toggle.isOn); }

#pragma mark License

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
    [alert addAction:[UIAlertAction actionWithTitle:@"Save & Activate" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *key = alert.textFields.firstObject.text;
        [UNKNWLicense.shared activateKey:key completion:^(BOOL activated, NSString *message) {
            [weakSelf toast:activated ? @"License activated" : (message ?: @"Activation failed")];
            [weakSelf.tableView reloadData];
        }];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Back up settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [UNKNWLicense.shared backupSettings:^(BOOL ok, NSString *message) { [weakSelf toast:message ?: (ok ? @"Backed up" : @"Backup failed")]; }];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Restore settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [UNKNWLicense.shared restoreSettings:^(BOOL ok, NSString *message) {
            [weakSelf toast:message ?: (ok ? @"Restored — relaunch to apply" : @"Restore failed")];
            [weakSelf.tableView reloadData];
        }];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)toast:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
    if (gesture.state == UIGestureRecognizerStateBegan) [self presentSettings];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    if (![gesture.name isEqualToString:@"UNKNWHomeGesture"]) return YES;
    UIView *view = touch.window ?: touch.view;
    if (!view) return NO;
    CGPoint point = [touch locationInView:view];
    CGSize size = view.bounds.size;
    return (point.y >= size.height - 100.0) && (point.x <= size.width * 0.25);
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
    while (top.presentedViewController) top = top.presentedViewController;
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
