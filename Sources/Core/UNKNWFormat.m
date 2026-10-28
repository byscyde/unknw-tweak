#import "UNKNWFormat.h"

@implementation UNKNWFormat

+ (NSDateFormatter *)formatter {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        formatter = [NSDateFormatter new];
        formatter.locale = [NSLocale currentLocale];
        // e.g. "Mon, 28 Oct 2026 · 14:03"
        formatter.dateFormat = @"EEE, d MMM yyyy '·' HH:mm";
    });
    return formatter;
}

+ (NSString *)detailedStringForDate:(NSDate *)date {
    if (!date) return @"";
    return [[self formatter] stringFromDate:date];
}

+ (NSString *)detailedStringForUnix:(NSTimeInterval)seconds {
    return [self detailedStringForDate:[NSDate dateWithTimeIntervalSince1970:seconds]];
}

@end
