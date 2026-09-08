// Executes production list helpers and the close-alert message construction.
// Does not enumerate real jobs, show a modal alert, or close a session.
#import <AppKit/AppKit.h>
#include <stdio.h>

static NSBundle *probeBundle;
#undef NSLocalizedStringWithDefaultValue
#define NSLocalizedStringWithDefaultValue(key, tableName, bundle, defaultValue, comment) \
    [probeBundle localizedStringForKey:(key) value:(defaultValue) table:(tableName)]

@interface NSArray (CloseListProbe)
- (instancetype)mapWithBlock:(id (^NS_NOESCAPE)(id))block;
- (NSDictionary<id, NSArray *> *)classifyWithBlock:(id (^)(id))block;
- (NSArray *)countedInstancesStrings;
- (NSString *)componentsJoinedWithOxfordComma;
- (NSString *)componentsJoinedWithOxfordCommaAndConjunction:(NSString *)conjunction;
@end
@implementation NSArray (CloseListProbe)
#include "close-list-helpers.inc"
@end

static NSString *closeMessage(NSArray *names, NSString *identifier, NSString *additionalMessage) {
#include "close-list-message.inc"
    return message;
}

// Characterization only: the third-party getter overrides the inherited setter.
@interface CloseLabelProbe : NSAccessibilityElement
@end
@implementation CloseLabelProbe
#include "close-label-getter.inc"
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2 || !(probeBundle = [NSBundle bundleWithPath:@(argv[1])])) {
            return 2;
        }
        NSArray *many = @[@"a", @"b", @"c", @"d", @"e", @"f", @"g", @"h", @"i", @"j", @"k", @"l"];
        NSArray *cases = @[@[], @[@"sleep"], @[@"sleep", @"Python"], @[@"c", @"a", @"b"],
                           [many subarrayWithRange:NSMakeRange(0, 10)],
                           [many subarrayWithRange:NSMakeRange(0, 11)], many,
                           @[@"sleep", @"sleep"], @[@"sleep", @"Python", @"sleep"],
                           @[@"User and 用户 %@ “job”"],
                           @[@"User and 用户 %@ “job”", @"User and 用户 %@ “job”"]];
        NSMutableArray *rows = [NSMutableArray array];
        for (NSArray *names in cases) {
            for (NSString *additional in @[@"", @"Extra 用户 %@\nsecond line"]) {
                [rows addObject:@{@"names": names, @"additional": additional,
                                  @"body": closeMessage(names, @"Synthetic Window", additional),
                                  @"genericJoined": [names componentsJoinedWithOxfordComma]}];
            }
        }
        CloseLabelProbe *label = [[CloseLabelProbe alloc] init];
        NSString *before = label.accessibilityLabel;
        label.accessibilityLabel = @"Synthetic replacement";
        NSDictionary *result = @{@"rows": rows, @"axBefore": before, @"axAfter": label.accessibilityLabel};
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:result options:0 error:&error];
        NSString *json = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        return json && !error && puts(json.UTF8String) >= 0 ? 0 : 3;
    }
}
