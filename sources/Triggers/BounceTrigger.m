//
//  BounceTrigger.m
//  iTerm
//
//  Created by George Nachman on 9/23/11.
//

#import "BounceTrigger.h"
#import "iTerm2SharedARC-Swift.h"

// How to bounce. The parameter takes an integer value equal to one of these. This is the tag.
typedef NS_ENUM(int, BounceTriggerParamTag) {
    kBounceTriggerParamTagBounceUntilFocus,
    kBounceTriggerParamTagBounceOnce,
};

@implementation BounceTrigger

+ (NSString *)title
{
    return NSLocalizedStringWithDefaultValue(@"ui.triggers.bouncetrigger.bounce_dock_icon.fb1a9eef", nil, NSBundle.mainBundle, @"Bounce Dock Icon", @"Trigger action title.");
}

- (NSString *)description {
    NSString *frequency = self.bounceType == NSCriticalRequest
        ? NSLocalizedStringWithDefaultValue(@"ui.triggers.bouncetrigger.until_focused.e42e0059", nil, NSBundle.mainBundle, @"until focused", @"Phrase in a trigger summary.")
        : NSLocalizedStringWithDefaultValue(@"ui.triggers.bouncetrigger.once.200651a8", nil, NSBundle.mainBundle, @"once", @"Phrase in a trigger summary.");
    return [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.triggers.bouncetrigger.bounce_dock_icon.2ce912c7", nil, NSBundle.mainBundle, @"Bounce dock icon %@", @"Trigger action summary. Preserve the placeholder."), frequency];
}

- (NSString *)paramPlaceholder
{
    return @"";
}

- (BOOL)takesParameter
{
    return YES;
}

- (BOOL)paramIsPopupButton
{
    return YES;
}

- (BOOL)isIdempotent {
    return YES;
}

- (NSSet<NSNumber *> *)allowedMatchTypes {
    NSMutableSet *set = [NSMutableSet setWithObject:@(iTermTriggerMatchTypeRegex)];
    [set unionSet:[iTermEventTriggerMatchTypeHelper allEventTypesSet]];
    return set;
}

- (NSInteger)indexForObject:(id)object {
    int i = 0;
    for (NSNumber *n in [self objectsSortedByValueInDict:[self menuItemsForPoupupButton]]) {
        if ([n isEqual:object]) {
            return i;
        }
        i++;
    }
    return -1;
}

- (id)objectAtIndex:(NSInteger)index {
    int i = 0;

    for (NSNumber *n in [self objectsSortedByValueInDict:[self menuItemsForPoupupButton]]) {
        if (i == index) {
            return n;
        }
        i++;
    }
    return nil;
}

+ (NSString *)stringForParameter:(BounceTriggerParamTag)parameter {
    switch (parameter) {
        case kBounceTriggerParamTagBounceUntilFocus:
            return NSLocalizedStringWithDefaultValue(@"ui.triggers.bouncetrigger.bounce_until_activated.2dd837b1", nil, NSBundle.mainBundle, @"Bounce Until Activated", @"User-facing text in BounceTrigger (stringForParameter:).");
        case kBounceTriggerParamTagBounceOnce:
            return NSLocalizedStringWithDefaultValue(@"ui.triggers.bouncetrigger.bounce_once.0c9c8142", nil, NSBundle.mainBundle, @"Bounce Once", @"User-facing text in BounceTrigger (paramAttributedString).");
    }
    return NSLocalizedStringWithDefaultValue(@"ui.triggers.bouncetrigger.bounce_until_activated.2dd837b1", nil, NSBundle.mainBundle, @"Bounce Until Activated", @"User-facing text in BounceTrigger (stringForParameter:).");
}

- (NSDictionary *)menuItemsForPoupupButton
{
    return @{ @(kBounceTriggerParamTagBounceUntilFocus): [BounceTrigger stringForParameter:kBounceTriggerParamTagBounceUntilFocus],
              @(kBounceTriggerParamTagBounceOnce): [BounceTrigger stringForParameter:kBounceTriggerParamTagBounceOnce] };
}

- (NSRequestUserAttentionType)bounceType
{
    switch ([self.param intValue]) {
        case kBounceTriggerParamTagBounceUntilFocus:
            return NSCriticalRequest;

        case kBounceTriggerParamTagBounceOnce:
            return NSInformationalRequest;

        default:
            return NSCriticalRequest;
    }
}

- (BOOL)performActionWithCapturedStrings:(NSArray<NSString *> *)stringArray
                          capturedRanges:(const NSRange *)capturedRanges
                               inSession:(id<iTermTriggerSession>)aSession
                                onString:(iTermStringLine *)stringLine
                    atAbsoluteLineNumber:(long long)lineNumber
                        useInterpolation:(BOOL)useInterpolation
                                    stop:(BOOL *)stop {
    const NSRequestUserAttentionType bounceType = [self bounceType];
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSApp requestUserAttention:bounceType];
    });
    return YES;
}

- (int)defaultIndex {
    return [self indexForObject:@(kBounceTriggerParamTagBounceUntilFocus)];
}

- (NSAttributedString *)paramAttributedString {
    return [[NSAttributedString alloc] initWithString:[BounceTrigger stringForParameter:[[NSNumber castFrom:self.param] intValue]]
                                           attributes:self.regularAttributes];
}

@end
