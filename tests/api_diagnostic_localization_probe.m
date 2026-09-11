// Production expression/consumer excerpts; no network, installation or disk logs.
#import <AppKit/AppKit.h>
#include <stdio.h>

static NSBundle *probeBundle;
static NSString *capturedLog;
#undef NSLocalizedStringWithDefaultValue
#define NSLocalizedStringWithDefaultValue(key, tableName, bundle, defaultValue, comment) \
    [probeBundle localizedStringForKey:(key) value:(defaultValue) table:(tableName)]
#define DLog(format, ...) capturedLog = [NSString stringWithFormat:format, ##__VA_ARGS__]

@interface ArchiveProbe : NSObject
@property(nonatomic, copy) NSString *name;
@end
@implementation ArchiveProbe
@end

static NSDictionary *snapshot(NSString *errorMessage) {
    BOOL quiet = NO;
    NSURL *location = nil;
#include "import-log.inc"
    return @{ @"message": errorMessage, @"log": capturedLog };
}

static NSDictionary *firstSnapshot(NSString *message, ...) {
    return snapshot(message);
}

static NSDictionary *secondSnapshot(NSURL *url, NSString *message, ...) {
    (void)url;
    return snapshot(message);
}

#include "download-display-helper.inc"

@interface iTermOptionalComponentDownloadPhase : NSObject {
    NSInteger _continuationsLeft;
}
@property(nonatomic, copy) NSURL *url;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) iTermOptionalComponentDownloadPhase *(^nextPhaseFactory)(iTermOptionalComponentDownloadPhase *);
@property(nonatomic) BOOL downloading;
@property(nonatomic, strong) NSURLSessionDownloadTask *task;
@end
@implementation iTermOptionalComponentDownloadPhase
#include "phase-init.inc"
#include "phase-description.inc"
@end

@interface DownloadDisplayProbe : NSObject {
    NSTextField *_titleLabel;
    NSTextField *_progressLabel;
    NSButton *_button;
    BOOL _showingMessage;
}
- (void)showMessage:(NSString *)message;
- (NSString *)displayPhase:(iTermOptionalComponentDownloadPhase *)phase;
- (NSString *)title;
@end
@implementation DownloadDisplayProbe
- (instancetype)init {
    self = [super init];
    if (self) {
        _titleLabel = [[NSTextField alloc] init];
        _progressLabel = [[NSTextField alloc] init];
        _button = [[NSButton alloc] init];
    }
    return self;
}
- (NSString *)displayPhase:(iTermOptionalComponentDownloadPhase *)phase {
#include "phase-display.inc"
    return _titleLabel.stringValue;
}
- (NSString *)title { return _titleLabel.stringValue; }
#include "show-message.inc"
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2 || !(probeBundle = [NSBundle bundleWithPath:@(argv[1])])) {
            return 2;
        }
        NSMutableArray *imports = [NSMutableArray array];
        ArchiveProbe *archive = [[ArchiveProbe alloc] init];
        archive.name = @"synthetic 用户脚本";
        NSError *externalError = [NSError errorWithDomain:@"synthetic" code:1
                                                userInfo:@{NSLocalizedDescriptionKey: @"external 原文"}];
        NSError *error = externalError;
        NSError *innerError = nil;
        BOOL canceled = NO;
#include "import-calls.inc"
        DownloadDisplayProbe *display = [[DownloadDisplayProbe alloc] init];
        NSMutableArray *phases = [NSMutableArray array];
        NSArray *titles = @[
#include "phase-titles.inc"
        ];
        for (NSString *title in titles) {
            iTermOptionalComponentDownloadPhase *phase = [[iTermOptionalComponentDownloadPhase alloc]
                initWithURL:[NSURL URLWithString:@"https://example.invalid/synthetic"]
                title:title nextPhaseFactory:nil];
            [phases addObject:@{ @"stored": phase.title, @"description": phase.description,
                                 @"displayed": [display displayPhase:phase] }];
        }
        NSMutableArray *passthrough = [NSMutableArray array];
        for (NSString *value in @[@"", @"User-provided 用户内容", @"Unknown future status"]) {
            [display showMessage:value];
            [passthrough addObject:@{ @"displayed": display.title, @"log": capturedLog }];
        }
#include "status-message.inc"
        NSDictionary *result = @{ @"imports": imports, @"phases": phases,
                                  @"passthrough": passthrough,
                                  @"status": @{ @"displayed": display.title, @"log": capturedLog } };
        NSError *jsonError = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:result options:0 error:&jsonError];
        NSString *json = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        return json && !jsonError && puts(json.UTF8String) >= 0 ? 0 : 3;
    }
}
