// Real rich-stat branch and original MRC join; no App, Git, session or network.
#import <Foundation/Foundation.h>
#include <stdio.h>

static NSBundle *probeBundle;
#undef NSLocalizedStringWithDefaultValue
#define NSLocalizedStringWithDefaultValue(key, tableName, bundle, fallback, comment) \
    [probeBundle localizedStringForKey:(key) value:(fallback) table:(tableName)]

@interface NSArray (ProbeJoin)
- (NSAttributedString *)attributedComponentsJoinedByAttributedString:(NSAttributedString *)joiner;
@end
@implementation NSArray (ProbeJoin)
#include "join-method.inc"
@end

@interface ProbeState : NSObject
@property(nonatomic) NSInteger filesAdded;
@property(nonatomic) NSInteger filesModified;
@property(nonatomic) NSInteger filesDeleted;
@property(nonatomic) NSInteger linesInserted;
@property(nonatomic) NSInteger linesDeleted;
@end
@implementation ProbeState
@end

@interface ProbeMaker : NSObject
@property(nonatomic, assign) ProbeState *currentState;
- (NSAttributedString *)stats;
- (NSAttributedString *)attributedStringWithString:(NSString *)string;
@end
@implementation ProbeMaker
- (NSAttributedString *)attributedStringWithString:(NSString *)string {
    // Stand-in for font/color attributes; retain the actual formatted text.
    return [[[NSAttributedString alloc] initWithString:string ?: @""] autorelease];
}
- (NSAttributedString *)stats {
#include "rich-stats.inc"
    // The zero-count case exits this excerpt; the legacy branch is not tested.
    return nil;
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3 || !(probeBundle = [NSBundle bundleWithPath:@(argv[1])])) { return 2; }
        NSData *input = [NSData dataWithContentsOfFile:@(argv[2])];
        if (!input) { return 3; }
        NSArray *cases = [NSJSONSerialization JSONObjectWithData:input options:0 error:nil];
        if (![cases isKindOfClass:NSArray.class]) { return 4; }
        NSMutableArray *rows = [NSMutableArray array];
        for (NSDictionary *values in cases) {
            if (![values isKindOfClass:NSDictionary.class]) { return 5; }
            ProbeState *state = [[ProbeState alloc] init];
            [state setValuesForKeysWithDictionary:values];
            ProbeMaker *maker = [[ProbeMaker alloc] init];
            maker.currentState = state;
            [rows addObject:@{ @"text": maker.stats.string ?: NSNull.null,
                               @"counts": [state dictionaryWithValuesForKeys:values.allKeys] }];
            [maker release];
            [state release];
        }
        NSData *data = [NSJSONSerialization dataWithJSONObject:rows options:0 error:nil];
        return data && fwrite(data.bytes, 1, data.length, stdout) == data.length ? 0 : 6;
    }
}
