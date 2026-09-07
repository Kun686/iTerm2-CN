// Compile actual NSError expressions from TerminalFile and SCPFile without
// opening their network, filesystem, authentication, or notification paths.
#import <Foundation/Foundation.h>
#include <stdio.h>

#undef NSLocalizedStringWithDefaultValue
#define NSLocalizedStringWithDefaultValue(key, tableName, bundle, defaultValue, comment) \
    [probeBundle localizedStringForKey:(key) value:(defaultValue) table:(tableName)]

#include "scp-error-factory.inc"

@interface TransferErrorProbe : NSObject
- (NSArray<NSError *> *)terminalErrors:(NSBundle *)probeBundle;
- (NSError *)errorWithDescription:(NSString *)description;
@end

@implementation TransferErrorProbe
#include "terminal-error-factory.inc"

- (NSArray<NSError *> *)terminalErrors:(NSBundle *)probeBundle {
    (void)probeBundle;
    return @[
#include "terminal-error-expressions.inc"
    ];
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3) {
            return 2;
        }
        NSBundle *probeBundle = [NSBundle bundleWithPath:@(argv[1])];
        if (!probeBundle) {
            return 3;
        }
        NSArray<NSError *> *errors;
        if ([@(argv[2]) isEqualToString:@"terminal"]) {
            errors = [[[TransferErrorProbe alloc] init] terminalErrors:probeBundle];
        } else if ([@(argv[2]) isEqualToString:@"scp"]) {
            errors = @[
#include "scp-error-expressions.inc"
            ];
        } else {
            return 4;
        }
        NSMutableArray *records = [NSMutableArray array];
        for (NSError *error in errors) {
            [records addObject:@{ @"domain": error.domain, @"code": @(error.code),
                                  @"message": error.localizedDescription }];
        }
        NSError *serializationError = nil;
        NSData *json = [NSJSONSerialization dataWithJSONObject:records options:0 error:&serializationError];
        if (!json || serializationError || fwrite(json.bytes, 1, json.length, stdout) != json.length) {
            return 5;
        }
        return 0;
    }
}
