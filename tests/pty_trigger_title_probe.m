// The driver includes production assignments and diagnostic methods verbatim.
// No PTY, shell command, notification, preference or Keychain operation is run.
#import <Foundation/Foundation.h>
#include <stdio.h>

#undef NSLocalizedStringWithDefaultValue
#define NSLocalizedStringWithDefaultValue(key, tableName, bundle, defaultValue, comment) \
    [probeBundle localizedStringForKey:(key) value:(defaultValue) table:(tableName)]

@interface TriggerTitleProbeRunner : NSObject {
    BOOL _running;
}
@property(nonatomic, copy) NSString *command;
@property(nonatomic, copy) NSString *shell;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *path;
@property(nonatomic, copy) NSString *notificationTitle;
- (NSString *)redactedDescription;
@end

@implementation TriggerTitleProbeRunner
#include "runner-description.inc"
#include "runner-redacted-description.inc"
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) {
            return 2;
        }
        NSBundle *probeBundle = [NSBundle bundleWithPath:@(argv[1])];
        if (!probeBundle) {
            return 3;
        }
        TriggerTitleProbeRunner *runner = [[TriggerTitleProbeRunner alloc] init];
        NSString *command = @"synthetic command payload; never executed";

#include "trigger-title.inc"

        NSDictionary *result = @{ @"title": runner.title,
                                  @"notificationTitle": runner.notificationTitle,
                                  @"command": runner.command,
                                  @"description": runner.description,
                                  @"redactedDescription": runner.redactedDescription };
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:result options:0 error:&error];
        if (!data || error) {
            return 4;
        }
        NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return json && puts(json.UTF8String) >= 0 ? 0 : 5;
    }
}
