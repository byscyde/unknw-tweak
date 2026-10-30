#import "UNKNW.h"
#import "Features.h"
#import "UNKNWSettingsController.h"
#import "Core/UNKNWLicense.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static const void *kFeatureKey = &kFeatureKey;

#pragma mark - Theme (scyde.dev design language)

// Signature palette: a violet→gold gradient over a near-black surface.
static UIColor *UNKNWAccent(void)   { return [UIColor colorWithRed:0.557 green:0.510 blue:0.941 alpha:1.0]; } // violet #8E82F0
static UIColor *UNKNWGold(void)     { return [UIColor colorWithRed:0.906 green:0.773 blue:0.420 alpha:1.0]; } // gold   #E7C56B
static UIColor *UNKNWBG(void)       { return [UIColor colorWithRed:0.039 green:0.043 blue:0.055 alpha:1.0]; } // #0A0B0E
static UIColor *UNKNWSurface(void)  { return [UIColor colorWithRed:0.086 green:0.090 blue:0.106 alpha:1.0]; } // #16171B
static UIColor *UNKNWHairline(void) { return [UIColor colorWithWhite:1.0 alpha:0.07]; }
static UIColor *UNKNWTextDim(void)  { return [UIColor colorWithRed:0.557 green:0.561 blue:0.600 alpha:1.0]; } // #8E8F99

// Per-row glyph tint, kept to a cohesive violet/gold family (scyde uses mostly
// violet glyphs with gold highlights).
static UIColor *UNKNWCategoryColor(NSString *category) {
    static NSDictionary<NSString *, UIColor *> *colors = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIColor *v = UNKNWAccent();
        UIColor *v2 = [UIColor colorWithRed:0.64 green:0.58 blue:0.97 alpha:1];
        colors = @{
            @"Feed": v, @"Reels": v2, @"Stories": UNKNWGold(),
            @"Messages": v, @"Profile": v2, @"Download Manager": v, @"General": UNKNWTextDim(),
        };
    });
    return colors[category] ?: UNKNWAccent();
}

// scyde-style icon tile: dark squircle + hairline border + tinted glyph.
static UIImage *UNKNWIconChip(NSString *symbol, UIColor *tint) {
    CGSize size = CGSizeMake(30, 30);
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    UIImage *out = [r imageWithActions:^(UIGraphicsImageRendererContext *__unused ctx) {
        UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0.75, 0.75, size.width - 1.5, size.height - 1.5) cornerRadius:9];
        [[UIColor colorWithRed:0.118 green:0.122 blue:0.149 alpha:1.0] setFill];
        [p fill];
        p.lineWidth = 1.0;
        [[UIColor colorWithWhite:1.0 alpha:0.10] setStroke];
        [p stroke];
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold];
        UIImage *s = [[UIImage systemImageNamed:symbol withConfiguration:cfg]
                      imageWithTintColor:tint renderingMode:UIImageRenderingModeAlwaysOriginal];
        CGSize ss = s.size;
        [s drawInRect:CGRectMake((size.width - ss.width) / 2.0, (size.height - ss.height) / 2.0, ss.width, ss.height)];
    }];
    return [out imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

#pragma mark - Branded header

@interface UNKNWHeaderView : UIView
@end

@implementation UNKNWHeaderView {
    CAGradientLayer *_wash;    // violet→gold diagonal glow over the dark card
    CAGradientLayer *_topbar;  // thin violet→gold accent line (scyde's progress bar)
}
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = UIColor.clearColor;

        _topbar = [CAGradientLayer layer];
        _topbar.colors = @[(id)UNKNWAccent().CGColor, (id)UNKNWGold().CGColor];
        _topbar.startPoint = CGPointMake(0, 0.5);
        _topbar.endPoint = CGPointMake(1, 0.5);
        _topbar.cornerRadius = 1.5;
        [self.layer addSublayer:_topbar];

        _wash = [CAGradientLayer layer];
        _wash.colors = @[(id)[UNKNWAccent() colorWithAlphaComponent:0.32].CGColor,
                         (id)[UIColor colorWithRed:0.086 green:0.090 blue:0.110 alpha:1.0].CGColor,
                         (id)[UNKNWGold() colorWithAlphaComponent:0.24].CGColor];
        _wash.locations = @[@0.0, @0.55, @1.0];
        _wash.startPoint = CGPointMake(0.05, 0.0);
        _wash.endPoint = CGPointMake(0.95, 1.0);
        _wash.cornerRadius = 20;
        _wash.borderWidth = 1.0;
        _wash.borderColor = [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;
        [self.layer addSublayer:_wash];

        // Wordmark: "UNKNW" in white heavy with a gold period (scyde's mark).
        UIFont *markFont = [UIFont systemFontOfSize:34 weight:UIFontWeightHeavy];
        NSMutableAttributedString *mark =
            [[NSMutableAttributedString alloc] initWithString:@"UNKNW"
                attributes:@{NSForegroundColorAttributeName: UIColor.whiteColor, NSFontAttributeName: markFont}];
        [mark appendAttributedString:[[NSAttributedString alloc] initWithString:@"."
                attributes:@{NSForegroundColorAttributeName: UNKNWGold(), NSFontAttributeName: markFont}]];
        UILabel *title = [UILabel new];
        title.attributedText = mark;

        UILabel *sub = [UILabel new];
        sub.text = [NSString stringWithFormat:@"Instagram, your way · v%@", UNKNW_VERSION];
        sub.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        sub.textColor = [UIColor colorWithWhite:1.0 alpha:0.72];

        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[title, sub]];
        stack.axis = UILayoutConstraintAxisVertical;
        stack.spacing = 3;
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:stack];
        [NSLayoutConstraint activateConstraints:@[
            [stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:34],
            [stack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:5],
        ]];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    _topbar.frame = CGRectMake(16, 0, self.bounds.size.width - 32, 3);
    _wash.frame = CGRectMake(16, 12, self.bounds.size.width - 32, self.bounds.size.height - 20);
}
@end

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
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.tableView.backgroundColor = UNKNWBG();
    self.tableView.separatorColor = UNKNWHairline();
    // Let rows grow so a full-width segmented control sits on its own line
    // instead of overflowing across the cell.
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 64;
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
    UNKNWFeature *feature = [self featureAt:indexPath];
    if (feature.kind == UNKNWFeatureKindSegment) return [self segmentCellForFeature:feature];

    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = UNKNWSurface();
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.textColor = UNKNWTextDim();

    cell.textLabel.text = feature.title;
    cell.detailTextLabel.text = feature.detail;
    cell.imageView.image = [UIImage systemImageNamed:UNKNWFeatureIcon(feature.key)];
    cell.imageView.tintColor = UNKNWCategoryColor(_category);

    switch (feature.kind) {
        case UNKNWFeatureKindToggle: {
            UISwitch *toggle = [UISwitch new];
            toggle.onTintColor = UNKNWAccent();
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
        case UNKNWFeatureKindSegment:
            break; // handled by -segmentCellForFeature: above
    }
    return cell;
}

// A full-width segmented control on its own line, under the title/detail, so
// long option lists never overflow across the cell.
- (UITableViewCell *)segmentCellForFeature:(UNKNWFeature *)feature {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = UNKNWSurface();

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:UNKNWFeatureIcon(feature.key)]];
    icon.tintColor = UNKNWCategoryColor(_category);
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [icon.widthAnchor constraintEqualToConstant:24].active = YES;
    [icon.heightAnchor constraintEqualToConstant:24].active = YES;

    UILabel *title = [UILabel new];
    title.text = feature.title;
    title.font = [UIFont systemFontOfSize:17];
    UILabel *detail = [UILabel new];
    detail.text = feature.detail;
    detail.font = [UIFont systemFontOfSize:13];
    detail.textColor = UNKNWTextDim();
    detail.numberOfLines = 0;

    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[title, detail]];
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 2;

    UIStackView *headerRow = [[UIStackView alloc] initWithArrangedSubviews:@[icon, textStack]];
    headerRow.axis = UILayoutConstraintAxisHorizontal;
    headerRow.spacing = 12;
    headerRow.alignment = UIStackViewAlignmentCenter;

    UISegmentedControl *segment = [[UISegmentedControl alloc] initWithItems:feature.options];
    segment.selectedSegmentIndex = (NSInteger)UNKNWPrefNumber(feature.key, feature.defaultNumber);
    segment.selectedSegmentTintColor = UNKNWAccent();
    objc_setAssociatedObject(segment, kFeatureKey, feature, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [segment addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];

    UIStackView *outer = [[UIStackView alloc] initWithArrangedSubviews:@[headerRow, segment]];
    outer.axis = UILayoutConstraintAxisVertical;
    outer.spacing = 10;
    outer.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:outer];
    UILayoutGuide *m = cell.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [outer.topAnchor constraintEqualToAnchor:m.topAnchor constant:6],
        [outer.bottomAnchor constraintEqualToAnchor:m.bottomAnchor constant:-6],
        [outer.leadingAnchor constraintEqualToAnchor:m.leadingAnchor],
        [outer.trailingAnchor constraintEqualToAnchor:m.trailingAnchor],
    ]];
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

- (NSURL *)dirURL {
    NSURL *appSupport = [NSFileManager.defaultManager URLForDirectory:NSApplicationSupportDirectory
                                                             inDomain:NSUserDomainMask
                                                    appropriateForURL:nil create:YES error:nil];
    return [appSupport URLByAppendingPathComponent:@"UNKNW" isDirectory:YES];
}
- (NSURL *)logURL   { return [[self dirURL] URLByAppendingPathComponent:@"classes.log"]; }
- (NSURL *)crashURL { return [[self dirURL] URLByAppendingPathComponent:@"crash.log"]; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Diagnostics";
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.view.backgroundColor = UNKNWBG();
    _textView = [[UITextView alloc] initWithFrame:self.view.bounds];
    _textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _textView.editable = NO;
    _textView.backgroundColor = UNKNWBG();
    _textView.textColor = [UIColor colorWithWhite:0.86 alpha:1.0];
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
    NSString *crash = [NSString stringWithContentsOfURL:[self crashURL] encoding:NSUTF8StringEncoding error:nil];
    NSString *classes = [NSString stringWithContentsOfURL:[self logURL] encoding:NSUTF8StringEncoding error:nil];
    NSMutableString *out = [NSMutableString string];
    if (crash.length) {
        [out appendString:@"════════ CRASH LOG (send this) ════════\n"];
        [out appendString:crash];
        [out appendString:@"\n════════ END CRASH LOG ════════\n\n"];
    }
    if (classes.length) [out appendString:classes];
    _textView.text = out.length ? out
        : @"(empty)\n\nNo crash recorded yet. If Instagram crashes, its exact cause appears here at the top on the next launch. Enable Developer Logging (General) to also log view-controller class names.";
    // Keep the crash block (top) in view rather than scrolling to the bottom.
    [_textView scrollRangeToVisible:NSMakeRange(0, 1)];
}

- (void)share {
    NSMutableArray *items = [NSMutableArray array];
    if ([NSFileManager.defaultManager fileExistsAtPath:[self crashURL].path]) [items addObject:[self crashURL]];
    [items addObject:[self logURL]];
    UIActivityViewController *activity =
        [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
    activity.popoverPresentationController.sourceView = self.view;
    activity.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width - 40, 0, 40, 40);
    [self presentViewController:activity animated:YES completion:nil];
}

- (void)copyAll { UIPasteboard.generalPasteboard.string = _textView.text ?: @""; }

- (void)clearLog {
    [@"" writeToURL:[self logURL] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [@"" writeToURL:[self crashURL] atomically:YES encoding:NSUTF8StringEncoding error:nil];
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
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.tableView.backgroundColor = UNKNWBG();
    self.tableView.separatorColor = UNKNWHairline();

    UINavigationBar *bar = self.navigationController.navigationBar;
    bar.prefersLargeTitles = YES;
    bar.tintColor = UNKNWAccent();
    UINavigationBarAppearance *ap = [UINavigationBarAppearance new];
    [ap configureWithOpaqueBackground];
    ap.backgroundColor = UNKNWBG();
    ap.shadowColor = UIColor.clearColor;
    ap.largeTitleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor};
    ap.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor};
    bar.standardAppearance = ap;
    bar.scrollEdgeAppearance = ap;
    bar.compactAppearance = ap;

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self action:@selector(dismissSelf)];
    UNKNWHeaderView *header =
        [[UNKNWHeaderView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 150)];
    self.tableView.tableHeaderView = header;
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
        cell.backgroundColor = UNKNWSurface();
        cell.detailTextLabel.textColor = UNKNWTextDim();
        cell.textLabel.text = @"Enable UNKNW";
        cell.detailTextLabel.text = @"Master switch for all features";
        cell.imageView.image = UNKNWIconChip(@"bolt.fill", UNKNWGold());
        UISwitch *toggle = [UISwitch new];
        toggle.onTintColor = UNKNWAccent();
        toggle.on = UNKNWPrefBool(kUNKNWEnabledKey, YES);
        [toggle addTarget:self action:@selector(masterChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        return cell;
    }
    if (indexPath.section == 1) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.backgroundColor = UNKNWSurface();
        NSString *category = _categories[indexPath.row];
        cell.textLabel.text = category;
        cell.imageView.image = UNKNWIconChip(UNKNWCategoryIcon(category), UNKNWCategoryColor(category));
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = UNKNWSurface();
    cell.detailTextLabel.textColor = UNKNWTextDim();
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    if (indexPath.row == 0) {
        NSString *stored = UNKNWLicense.shared.key;
        BOOL activated = UNKNWLicense.shared.isActivated;
        cell.textLabel.text = @"Account & License";
        cell.detailTextLabel.text = activated ? @"Activated · tap to manage"
            : (stored.length ? @"Not activated · tap to retry" : @"Tap to enter your license key");
        cell.imageView.image = UNKNWIconChip(activated ? @"checkmark.seal.fill" : @"lock.fill", UNKNWAccent());
    } else {
        cell.textLabel.text = @"Diagnostics";
        cell.detailTextLabel.text = @"View / share the class log (for hook discovery)";
        cell.imageView.image = UNKNWIconChip(@"ladybug.fill", [UIColor colorWithRed:0.55 green:0.57 blue:0.62 alpha:1]);
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
    nav.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    [top presentViewController:nav animated:YES completion:nil];
}

@end

#pragma mark - What's New (one-time per version)

void UNKNWMaybeShowWhatsNew(void) {
    NSString *seen = UNKNWPrefString(kUNKNWLastSeenVersionKey, @"");
    if ([seen isEqualToString:UNKNW_VERSION]) return;  // already shown for this version
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *top = [[UNKNWGestureHandler shared] topViewController];
        if (!top || top.presentedViewController) return;  // retry next launch if the UI isn't ready
        UNKNWPrefSetString(kUNKNWLastSeenVersionKey, UNKNW_VERSION);
        NSString *body =
            @"• Reels video download — hold a reel or tap the save button\n"
            @"• Posts & profile pictures save in full resolution\n"
            @"• A floating save button (switch it to hold-only or off in Download Manager)\n"
            @"• Ads removed from the feed and from reels\n"
            @"• Hide your story-seen receipts\n"
            @"• A freshly redesigned panel\n\n"
            @"Open UNKNW any time with a two-finger long-press, or a long-press in the bottom-left corner.";
        UIAlertController *a =
            [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"What's New in UNKNW %@", UNKNW_VERSION]
                                                message:body
                                         preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Let's go" style:UIAlertActionStyleDefault handler:nil]];
        [top presentViewController:a animated:YES completion:nil];
    });
}
