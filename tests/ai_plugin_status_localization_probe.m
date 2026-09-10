// Exercise the actual settings callback without plugins, UI windows or timers.
#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#include <stdio.h>

static NSBundle *probeBundle;
static NSMutableArray<NSString *> *probeLogs;
static NSUInteger scheduledChecks;
static BOOL aiAllowed;

#undef NSLocalizedStringWithDefaultValue
#define NSLocalizedStringWithDefaultValue(key, tableName, bundle, defaultValue, comment) \
    [probeBundle localizedStringForKey:(key) value:(defaultValue) table:(tableName)]
#define DLog(...) [probeLogs addObject:[NSString stringWithFormat:__VA_ARGS__]]

static void recordSchedule(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block) {
    scheduledChecks++;
}
#define dispatch_after recordSchedule

@interface StatusControl : NSObject
@property(nonatomic, copy) NSString *stringValue;
@property(nonatomic, copy) NSString *title;
@property(nonatomic) SEL action;
@property(nonatomic) BOOL enabled;
@property(nonatomic) NSUInteger fitCount;
- (void)sizeToFit;
@end
@implementation StatusControl
- (void)sizeToFit { self.fitCount++; }
@end

@interface iTermAdvancedSettingsModel : NSObject
+ (BOOL)generativeAIAllowed;
@end
@implementation iTermAdvancedSettingsModel
+ (BOOL)generativeAIAllowed { return aiAllowed; }
@end

@interface PluginStatusProbe : NSObject {
    StatusControl *_pluginStatus;
    StatusControl *_installPluginButton;
    BOOL _pluginOK;
    NSUInteger _updates;
}
- (void)validatePlugin;
- (void)installPlugin:(id)sender;
- (void)revealPlugin:(id)sender;
- (void)updateAIEnabled;
- (NSDictionary *)snapshot:(NSString *)problem;
@end

@implementation PluginStatusProbe
#include "plugin-status-callback.inc"
- (void)validatePlugin { abort(); }
- (void)installPlugin:(id)sender { abort(); }
- (void)revealPlugin:(id)sender { abort(); }
- (void)updateAIEnabled { _updates++; }
- (NSDictionary *)snapshot:(NSString *)problem {
    _pluginStatus = [StatusControl new];
    _installPluginButton = [StatusControl new];
    _updates = 0;
    scheduledChecks = 0;
    probeLogs = [NSMutableArray array];
    [self setPluginProblem:problem];
    return @{@"input": problem ?: NSNull.null,
             @"display": _pluginStatus.stringValue,
             @"button": _installPluginButton.title,
             @"action": NSStringFromSelector(_installPluginButton.action),
             @"enabled": @(_installPluginButton.enabled),
             @"ok": @(_pluginOK), @"updates": @(_updates),
             @"fits": @(_installPluginButton.fitCount),
             @"scheduled": @(scheduledChecks), @"logs": probeLogs.copy};
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2 || !(probeBundle = [NSBundle bundleWithPath:@(argv[1])])) {
            return 2;
        }
        NSMutableArray *rows = [NSMutableArray array];
        PluginStatusProbe *probe = [PluginStatusProbe new];
        for (NSNumber *allowed in @[@NO, @YES]) {
            aiAllowed = allowed.boolValue;
            for (id problem in @[@"Plugin not found", @"", @"Synthetic 用户 %@\n/path",
                                 @"Plugin not found: /synthetic", NSNull.null]) {
                NSMutableDictionary *row = [[probe snapshot:problem == NSNull.null ? nil : problem] mutableCopy];
                row[@"allowed"] = allowed;
                [rows addObject:row];
            }
        }
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:rows options:0 error:&error];
        NSString *json = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        return json && !error && puts(json.UTF8String) >= 0 ? 0 : 3;
    }
}
