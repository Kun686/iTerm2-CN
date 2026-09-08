// Original ScriptImporter callback/log expressions; only log destinations differ.
#import <AppKit/AppKit.h>

@interface iTermScriptHistoryEntry : NSObject
@property(nonatomic, copy) NSString *output;
+ (instancetype)globalEntry;
- (void)addOutput:(NSString *)message completion:(void (^)(void))completion;
@end
@implementation iTermScriptHistoryEntry
+ (instancetype)globalEntry {
    static iTermScriptHistoryEntry *entry;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ entry = [[self alloc] init]; });
    return entry;
}
- (void)addOutput:(NSString *)message completion:(void (^)(void))completion {
    self.output = message;
    completion();
}
@end

NSDictionary *UVUpgradeMessageSnapshot(NSString *message) {
    NSAlert *alert = [[NSAlert alloc] init];
#include "uv-upgrade-history.inc"
#include "uv-upgrade-display.inc"
    return @{ @"history": [iTermScriptHistoryEntry globalEntry].output,
              @"displayed": alert.informativeText };
}

NSDictionary *UVImportSnapshot(NSError *error) {
    __block NSString *forwarded;
    __block NSString *completionLog;
    NSString *installLog;
    NSURL *location = nil;
    void (^completion)(NSString *, BOOL, NSURL *) = ^(NSString *errorMessage, BOOL quiet, NSURL *location) {
#define DLog(format, ...) completionLog = [NSString stringWithFormat:format, ##__VA_ARGS__]
#include "uv-import-completion-log.inc"
#undef DLog
        forwarded = errorMessage;
    };
#define RLog(format, ...) installLog = [NSString stringWithFormat:format, ##__VA_ARGS__]
#include "uv-import-install-log.inc"
#undef RLog
#include "uv-import-forward.inc"
    return @{ @"forwarded": forwarded, @"completionLog": completionLog, @"installLog": installLog };
}
