// Actual row-construction prefix, three callers, and three save expressions.
// No visualization, external account access, disk persistence or trigger action.
#import <AppKit/AppKit.h>
#include <stdio.h>

static NSBundle *probeBundle;
#undef NSLocalizedStringWithDefaultValue
#define NSLocalizedStringWithDefaultValue(key, tableName, bundle, defaultValue, comment) \
    [probeBundle localizedStringForKey:(key) value:(defaultValue) table:(tableName)]

@interface TriggerRowProbe : NSObject <NSTextFieldDelegate> {
    NSTextField *_regexTextField;
    NSTextField *_regexLabel;
    NSTextField *_nameTextField;
    NSTextField *_jobTextField;
}
- (NSDictionary *)snapshot;
@end

@implementation TriggerRowProbe
#include "trigger-row-construction.inc"
- (NSArray<NSView *> *)createRows {
#include "trigger-row-calls.inc"
}
- (NSDictionary *)savedForEvent:(BOOL)isEventTrigger {
#include "trigger-row-save.inc"
}
- (NSDictionary *)snapshot {
    NSArray<NSView *> *views = [self createRows];
    NSMutableArray *labels = [NSMutableArray array];
    NSMutableArray<NSTextField *> *fields = [NSMutableArray array];
    for (NSView *view in views) {
        [labels addObject:[(NSTextField *)view.subviews[0] stringValue]];
        [fields addObject:(NSTextField *)view.subviews[1]];
    }
    NSArray *bound = @[@(_regexTextField == fields[0]), @(_nameTextField == fields[1]),
                       @(_jobTextField == fields[2])];
    NSMutableArray *rows = [NSMutableArray array];
    for (NSString *value in @[@"^CN_TRIGGER_TEST$", @"", @"用户 %@ .* (x)\\n"]) {
        for (NSTextField *field in fields) {
            field.stringValue = value;
        }
        for (NSNumber *event in @[@NO, @YES]) {
            NSMutableDictionary *row = [@{@"input": value, @"event": event} mutableCopy];
            @try {
                row[@"saved"] = [self savedForEvent:event.boolValue];
            } @catch (NSException *exception) {
                row[@"exception"] = exception.name;
            }
            [rows addObject:row];
        }
    }
    NSView *unknown = [self createRowWithLabelText:@"Synthetic 用户 %@:" hasVisualizationButton:NO];
    return @{@"labels": labels, @"bound": bound, @"rows": rows,
             @"jobPlaceholder": fields[2].placeholderString ?: @"",
             @"unknownLabel": [(NSTextField *)unknown.subviews[0] stringValue]};
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2 || !(probeBundle = [NSBundle bundleWithPath:@(argv[1])])) {
            return 2;
        }
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:[[[TriggerRowProbe alloc] init] snapshot]
                                                     options:0 error:&error];
        NSString *json = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        return json && !error && puts(json.UTF8String) >= 0 ? 0 : 3;
    }
}
