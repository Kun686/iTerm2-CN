// Production caller expressions and alert/history method. No script is launched.
#import <AppKit/AppKit.h>
#include <stdio.h>

static NSBundle *probeBundle;
static NSString *historyOutput;
static NSString *displayedTitle;
static NSString *displayedBody;
#undef NSLocalizedStringWithDefaultValue
#define NSLocalizedStringWithDefaultValue(key, tableName, bundle, defaultValue, comment) \
    [probeBundle localizedStringForKey:(key) value:(defaultValue) table:(tableName)]

@interface iTermScriptHistoryEntry : NSObject
+ (instancetype)globalEntry;
- (void)addOutput:(NSString *)output completion:(void (^)(void))completion;
@end
@implementation iTermScriptHistoryEntry
+ (instancetype)globalEntry { return [[self alloc] init]; }
- (void)addOutput:(NSString *)output completion:(void (^)(void))completion {
    historyOutput = output;
    completion();
}
@end

@interface ProbeAlert : NSAlert
@end
@implementation ProbeAlert
- (NSModalResponse)runModal {
    displayedTitle = self.messageText;
    displayedBody = self.informativeText;
    return NSModalResponseOK;
}
@end

#include "launcher-display-helper.inc"

static void probeDispatchAsync(dispatch_queue_t queue, dispatch_block_t block) {
    (void)queue;
    block();
}

@interface iTermAPIScriptLauncher : NSObject
+ (void)showIntelOnlyUnrunnableErrorForScript:(NSString *)fullPath recovery:(NSString *)recovery;
@end
@implementation iTermAPIScriptLauncher
// Execute the presentation block synchronously; this probe does not test queue timing.
#define dispatch_async probeDispatchAsync
#define NSAlert ProbeAlert
#include "launcher-show-error.inc"
#undef NSAlert
#undef dispatch_async
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2 || !(probeBundle = [NSBundle bundleWithPath:@(argv[1])])) {
            return 2;
        }
        NSArray<NSString *> *recoveries = @[
#include "launcher-recovery-callers.inc"
            @"Unknown recovery 用户数据 %@", @""
        ];
        NSMutableArray *rows = [NSMutableArray array];
        for (NSString *path in @[@"/synthetic/用户 Demo.py", @""]) {
            for (NSString *recovery in recoveries) {
                historyOutput = nil;
                displayedTitle = nil;
                displayedBody = nil;
                [iTermAPIScriptLauncher showIntelOnlyUnrunnableErrorForScript:path recovery:recovery];
                if (!historyOutput || !displayedTitle || !displayedBody) {
                    return 3;
                }
                [rows addObject:@{ @"history": historyOutput, @"title": displayedTitle,
                                   @"body": displayedBody, @"recovery": recovery }];
            }
        }
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:rows options:0 error:&error];
        NSString *json = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        return json && !error && puts(json.UTF8String) >= 0 ? 0 : 4;
    }
}
