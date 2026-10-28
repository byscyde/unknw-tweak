// The feature registry: the single source of truth for which controls exist.
//
// The loader (Tweak.x) and the in-app settings panel both read this list, so a
// feature appears in the UI and gets wired into the hook loader from one
// declaration. Features are grouped by category and can be one of three kinds.

#import <Foundation/Foundation.h>

typedef void (*UNKNWFeatureInit)(void);

typedef NS_ENUM(NSInteger, UNKNWFeatureKind) {
    UNKNWFeatureKindToggle,   // on/off switch
    UNKNWFeatureKindStepper,  // numeric value (min..max step)
    UNKNWFeatureKindSegment,  // one of N labelled options
};

@interface UNKNWFeature : NSObject
@property (nonatomic, copy)   NSString *key;           // NSUserDefaults key
@property (nonatomic, copy)   NSString *category;      // section header
@property (nonatomic, copy)   NSString *title;
@property (nonatomic, copy)   NSString *detail;        // subtitle
@property (nonatomic, assign) UNKNWFeatureKind kind;

// Toggle
@property (nonatomic, assign) BOOL defaultBool;
@property (nonatomic, assign) UNKNWFeatureInit initializer; // run at load if ON; may be NULL

// Stepper
@property (nonatomic, assign) double defaultNumber;
@property (nonatomic, assign) double minValue;
@property (nonatomic, assign) double maxValue;
@property (nonatomic, assign) double stepValue;

// Segment
@property (nonatomic, copy)   NSArray<NSString *> *options; // labels; default index via defaultNumber
@end

@interface UNKNWFeature (Builders)
+ (instancetype)toggle:(NSString *)key category:(NSString *)category title:(NSString *)title
                detail:(NSString *)detail defaultOn:(BOOL)defaultOn init:(UNKNWFeatureInit)init;
+ (instancetype)stepper:(NSString *)key category:(NSString *)category title:(NSString *)title
                 detail:(NSString *)detail value:(double)value min:(double)min max:(double)max step:(double)step;
+ (instancetype)segment:(NSString *)key category:(NSString *)category title:(NSString *)title
                 detail:(NSString *)detail options:(NSArray<NSString *> *)options defaultIndex:(NSInteger)defaultIndex;
@end

// Ordered list of every control, excluding the master switch and license row.
NSArray<UNKNWFeature *> *UNKNWAllFeatures(void);

// Category headers in display order (derived from the feature list).
NSArray<NSString *> *UNKNWCategories(void);

// Features belonging to one category, in registry order.
NSArray<UNKNWFeature *> *UNKNWFeaturesInCategory(NSString *category);
