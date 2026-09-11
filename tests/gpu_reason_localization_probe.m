// Exercises actual display and diagnostic code without creating any GPU/session.
#import <Foundation/Foundation.h>
#import "iTermMetalUnavailableReason.h"
#include <stdio.h>

static NSBundle *probeBundle;
#undef NSLocalizedStringWithDefaultValue
#define NSLocalizedStringWithDefaultValue(key, tableName, bundle, defaultValue, comment) \
    [probeBundle localizedStringForKey:(key) value:(defaultValue) table:(tableName)]

@interface GPUReasonProbe : NSObject
- (NSString *)gpuUnavailableStringForReason:(iTermMetalUnavailableReason)reason;
@end
@implementation GPUReasonProbe
#include "gpu-display-method.inc"
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2 || !(probeBundle = [NSBundle bundleWithPath:@(argv[1])])) {
            return 2;
        }
        GPUReasonProbe *probe = [[GPUReasonProbe alloc] init];
        NSMutableDictionary *rows = [NSMutableDictionary dictionary];
#define ADD_REASON(name, value) \
        rows[name] = @{@"diagnostic": iTermMetalUnavailableReasonDescription(value) ?: NSNull.null, \
                       @"display": [probe gpuUnavailableStringForReason:value] ?: NSNull.null}
#include "gpu-reason-cases.inc"
#undef ADD_REASON
        NSString *control = [probeBundle localizedStringForKey:@"ui.appkit.itermapplicationdelegate.gpu_renderer_availability.bd16bac3"
                                                       value:nil table:nil];
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:@{@"rows": rows, @"control": control}
                                                      options:0 error:&error];
        NSString *json = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        return json && !error && puts(json.UTF8String) >= 0 ? 0 : 3;
    }
}
