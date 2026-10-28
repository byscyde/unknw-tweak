// UNKNWFormat — small presentation helpers used by the customization features.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UNKNWFormat : NSObject

/// A verbose, unambiguous timestamp, e.g. "Mon, 28 Oct 2026 · 14:03".
/// Used by the "Detailed dates" feature in place of Instagram's relative text.
+ (NSString *)detailedStringForDate:(NSDate *)date;

/// Same, from a UNIX timestamp (seconds).
+ (NSString *)detailedStringForUnix:(NSTimeInterval)seconds;

@end

NS_ASSUME_NONNULL_END
