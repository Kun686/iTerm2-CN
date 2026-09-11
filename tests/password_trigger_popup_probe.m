// Compile the real menu/index methods, not account loading or action execution.
#import <Foundation/Foundation.h>
#include <stdio.h>

static NSBundle *probeBundle;
#undef NSLocalizedStringWithDefaultValue
#define NSLocalizedStringWithDefaultValue(key, tableName, bundle, defaultValue, comment) \
    [probeBundle localizedStringForKey:(key) value:(defaultValue) table:(tableName)]
#include "password-sentinel.inc"

@interface PopupBase : NSObject
- (NSArray *)objectsSortedByValueInDict:(NSDictionary *)dict;
@end
@implementation PopupBase
#include "base-sort.inc"
@end

// A finite fixture adapter keeps the untouched production bounds expression
// warning-clean under -Wextra: count is signed, like its index argument. All
// ordering and enumeration still use Foundation's real NSArray operations.
@interface SyntheticAccountNames : NSObject <NSFastEnumeration>
@property(nonatomic, copy) NSArray *values;
@property(nonatomic, readonly) NSInteger count;
- (NSArray *)sortedArrayUsingSelector:(SEL)selector;
@end
@implementation SyntheticAccountNames
- (NSInteger)count { return (NSInteger)self.values.count; }
- (NSArray *)sortedArrayUsingSelector:(SEL)selector {
    return [self.values sortedArrayUsingSelector:selector];
}
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                objects:(id __unsafe_unretained [])buffer
                                  count:(NSUInteger)length {
    return [self.values countByEnumeratingWithState:state objects:buffer count:length];
}
@end

@interface PasswordPopupProbe : PopupBase
@property(nonatomic, strong) SyntheticAccountNames *accountNames;
- (NSArray *)sortedAccountNames;
- (NSInteger)indexForObject:(id)object;
- (id)objectAtIndex:(NSInteger)index;
- (NSDictionary *)menuItemsForPoupupButton;
- (int)defaultIndex;
@end
@implementation PasswordPopupProbe
// Fixtures provide the post-loading list directly. Never call the real loader.
- (void)addUnlockToAccountNamesIfNeeded {}
#include "password-popup.inc"
@end

static NSArray *DisplayedKeys(PasswordPopupProbe *trigger, NSDictionary *items) {
#include "popup-order.inc"
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2 || !(probeBundle = [NSBundle bundleWithPath:@(argv[1])])) {
            return 2;
        }
        NSString *sentinel = PasswordTriggerPlaceholderString;
        NSArray *fixtures = @[ @[], @[sentinel], @[@"Z"], @[@"Z", sentinel],
                               @[sentinel, @"A"], @[sentinel, @"O"], @[sentinel, @"S"],
                               @[sentinel, @"中文"], @[@"Z", @"A", @"合成名称"] ];
        NSMutableArray *snapshots = [NSMutableArray array];
        for (NSArray *names in fixtures) {
            PasswordPopupProbe *trigger = [[PasswordPopupProbe alloc] init];
            trigger.accountNames = [[SyntheticAccountNames alloc] init];
            trigger.accountNames.values = names;
            NSDictionary *menu = [trigger menuItemsForPoupupButton];
            NSArray *order = DisplayedKeys(trigger, menu);
            NSMutableArray *rows = [NSMutableArray array];
            for (NSUInteger index = 0; index < order.count; index++) {
                NSString *key = order[index];
                [rows addObject:@{ @"index": @(index), @"key": key, @"label": menu[key],
                                   @"savedKey": [trigger objectAtIndex:index] ?: [NSNull null],
                                   @"restoredIndex": @([trigger indexForObject:key]) }];
            }
            [snapshots addObject:@{
                @"names": names, @"displayOrder": order, @"rows": rows,
                @"baselineOrder": [names sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)],
                @"namesUnchanged": @([trigger.accountNames.values isEqual:names]),
                @"boundsChecked": @([trigger objectAtIndex:-1] == nil && [trigger objectAtIndex:names.count] == nil),
                @"defaultIndex": @([trigger defaultIndex])
            }];
        }
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:snapshots options:0 error:&error];
        return data && !error && fwrite(data.bytes, 1, data.length, stdout) == data.length ? 0 : 3;
    }
}
