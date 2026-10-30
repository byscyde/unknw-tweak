// The feature registry: the single source of truth for which controls exist.
//
// Features are grouped into categories (the top-level menu) and, within a
// category, into named sections (the grouped blocks on a category's sub-screen).
// The loader (Tweak.x) and the in-app panel both read this list.

#import <Foundation/Foundation.h>

typedef void (*UNKNWFeatureInit)(void);

typedef NS_ENUM(NSInteger, UNKNWFeatureKind) {
    UNKNWFeatureKindToggle,   // on/off switch
    UNKNWFeatureKindStepper,  // numeric value (min..max step)
    UNKNWFeatureKindSegment,  // one of N labelled options
};

@interface UNKNWFeature : NSObject
@property (nonatomic, copy)   NSString *key;           // NSUserDefaults key
@property (nonatomic, copy)   NSString *category;      // top-level menu entry
@property (nonatomic, copy)   NSString *section;       // block within the category ("" = unnamed)
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
+ (instancetype)toggle:(NSString *)key category:(NSString *)category section:(NSString *)section
                 title:(NSString *)title detail:(NSString *)detail
             defaultOn:(BOOL)defaultOn init:(UNKNWFeatureInit)init;
+ (instancetype)stepper:(NSString *)key category:(NSString *)category section:(NSString *)section
                  title:(NSString *)title detail:(NSString *)detail
                  value:(double)value min:(double)min max:(double)max step:(double)step;
+ (instancetype)segment:(NSString *)key category:(NSString *)category section:(NSString *)section
                  title:(NSString *)title detail:(NSString *)detail
                options:(NSArray<NSString *> *)options defaultIndex:(NSInteger)defaultIndex;
@end

// Every control, excluding the master switch and the license row.
NSArray<UNKNWFeature *> *UNKNWAllFeatures(void);

// Top-level categories in display order.
NSArray<NSString *> *UNKNWCategories(void);

// An SF Symbol name for a category's menu icon.
NSString *UNKNWCategoryIcon(NSString *category);

// An SF Symbol name for an individual feature row (keyed by its pref key).
NSString *UNKNWFeatureIcon(NSString *key);

// Ordered section names within a category ("" for the leading unnamed block).
NSArray<NSString *> *UNKNWSectionsInCategory(NSString *category);

// Features within one category+section, in registry order.
NSArray<UNKNWFeature *> *UNKNWFeaturesInCategorySection(NSString *category, NSString *section);
