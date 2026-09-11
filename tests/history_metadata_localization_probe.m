// Real public formatting methods; only the clock and resource bundle are isolated.
#import <Foundation/Foundation.h>
#include <stdio.h>
#import "NSDateFormatterExtras.h"

static NSBundle *probeBundle;
static NSDate *probeNow;

#undef NSLocalizedStringWithDefaultValue
#define NSLocalizedStringWithDefaultValue(key, tableName, bundle, defaultValue, comment) \
    [probeBundle localizedStringForKey:(key) value:(defaultValue) table:(tableName)]

@implementation NSDateFormatter (HistoryMetadataProbe)
#include "history-date-methods.inc"
@end

#ifdef CN_TEST_COMPOSER_DETAIL
static NSString *composerHistoryDetail(NSDate *date) {
#include "history-composer-detail.inc"
}
#else
@interface NSString (HistoryMetadataProbe)
+ (NSString *)it_formatBytes:(double)bytes;
@end
@implementation NSString (HistoryMetadataProbe)
#include "history-bytes-method.inc"
@end
#endif

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2 || !(probeBundle = [NSBundle bundleWithPath:@(argv[1])])) {
            return 2;
        }
        probeNow = [NSDate dateWithTimeIntervalSinceReferenceDate:1000000];
#ifdef CN_TEST_COMPOSER_DETAIL
        NSDictionary *snapshot = @{@"details": @[
            composerHistoryDetail(probeNow),
            composerHistoryDetail([probeNow dateByAddingTimeInterval:-120])
        ]};
#else
        NSMutableArray *dates = [NSMutableArray array];
        for (NSNumber *seconds in @[@0, @60, @120, @3600, @7200, @86400,
                                   @172800, @561600, @604800, @1209600]) {
            NSDate *date = [probeNow dateByAddingTimeInterval:-seconds.doubleValue];
            [dates addObject:@{
                @"upper": [NSDateFormatter dateDifferenceStringFromDate:date],
                @"lower": [NSDateFormatter dateDifferenceStringFromDate:date
                                                               options:iTermDateDifferenceOptionsLowercase]
            }];
        }
        NSMutableArray *sizes = [NSMutableArray array];
        for (NSNumber *bytes in @[@0, @90, @999, @1000, @10000, @1000000]) {
            [sizes addObject:[NSString it_formatBytes:bytes.doubleValue]];
        }
        NSDictionary *snapshot = @{@"dates": dates, @"sizes": sizes};
#endif
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:snapshot
                                                     options:0 error:&error];
        NSString *json = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        return json && !error && puts(json.UTF8String) >= 0 ? 0 : 3;
    }
}
