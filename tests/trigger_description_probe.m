// Real title/description methods and Foundation %@ dispatch, without sessions,
// matcher execution, shell-prompt callbacks, preferences or user data access.
#import <Foundation/Foundation.h>
#include <stdio.h>

static NSBundle *probeBundle;
#undef NSLocalizedStringWithDefaultValue
#define NSLocalizedStringWithDefaultValue(key, tableName, bundle, defaultValue, comment) \
    [probeBundle localizedStringForKey:(key) value:(defaultValue) table:(tableName)]

@interface TriggerDescriptionProbe : NSObject
+ (NSString *)title;
- (NSString *)matchedLog;
@end

@implementation TriggerDescriptionProbe
+ (NSString *)title { return @""; }
- (NSString *)matchedLog {
    NSString *s = @"synthetic";
#include "trigger-matched-log.inc"
}
@end

@interface StopTrigger : TriggerDescriptionProbe
@end
@implementation StopTrigger
#include "StopTrigger.inc"
@end

@interface iTermShellPromptTrigger : TriggerDescriptionProbe
@end
@implementation iTermShellPromptTrigger
#include "iTermShellPromptTrigger.inc"
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2 || !(probeBundle = [NSBundle bundleWithPath:@(argv[1])])) {
            return 2;
        }
        NSMutableArray *rows = [NSMutableArray array];
        for (Class cls in @[ StopTrigger.class, iTermShellPromptTrigger.class ]) {
            TriggerDescriptionProbe *trigger = [[cls alloc] init];
            [rows addObject:@{ @"class": NSStringFromClass(cls), @"title": [cls title],
                               @"description": trigger.description, @"matchedLog": trigger.matchedLog }];
        }
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:rows options:0 error:&error];
        return data && !error && fwrite(data.bytes, 1, data.length, stdout) == data.length ? 0 : 3;
    }
}
