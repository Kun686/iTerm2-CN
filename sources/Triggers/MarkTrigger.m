//
//  MarkTrigger.m
//  iTerm
//
//  Created by George Nachman on 4/22/14.
//
//

#import "MarkTrigger.h"
#import "PTYScrollView.h"
#import "iTerm2SharedARC-Swift.h"
#import "SessionView.h"

// Whether to stop scrolling.
typedef enum {
    kMarkTriggerParamTagKeepScrolling,
    kMarkTriggerParamTagStopScrolling,
} MarkTriggerParam;

@implementation MarkTrigger

+ (NSString *)title {
    return NSLocalizedStringWithDefaultValue(@"ui.triggers.marktrigger.set_mark.ae11f7ac", nil, NSBundle.mainBundle, @"Set Mark", @"Trigger action title.");
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Set Mark and %@ scrolling", [self shouldStopScrolling] ? @"stop" : @"continue"];
}

- (NSString *)triggerOptionalParameterPlaceholderWithInterpolation:(BOOL)interpolation {
    return @"";
}

- (BOOL)takesParameter {
    return YES;
}

- (BOOL)paramIsPopupButton {
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

- (NSDictionary *)menuItemsForPoupupButton
{
    return @{ @(kMarkTriggerParamTagKeepScrolling): NSLocalizedStringWithDefaultValue(@"ui.triggers.marktrigger.keep_scrolling.4e9a386c", nil, NSBundle.mainBundle, @"Keep Scrolling", @"Trigger popup option."),
              @(kMarkTriggerParamTagStopScrolling): NSLocalizedStringWithDefaultValue(@"ui.triggers.marktrigger.stop_scrolling.1c1df101", nil, NSBundle.mainBundle, @"Stop Scrolling", @"Trigger popup option.") };
}

- (BOOL)shouldStopScrolling {
    return [self.param intValue] == kMarkTriggerParamTagStopScrolling;
}

- (BOOL)performActionWithCapturedStrings:(NSArray<NSString *> *)stringArray
                          capturedRanges:(const NSRange *)capturedRanges
                               inSession:(id<iTermTriggerSession>)aSession
                                onString:(iTermStringLine *)stringLine
                    atAbsoluteLineNumber:(long long)lineNumber
                        useInterpolation:(BOOL)useInterpolation
                                    stop:(BOOL *)stop {
    [aSession triggerSession:self saveCursorLineAndStopScrolling:[self shouldStopScrolling]];
    return YES;
}

- (int)defaultIndex {
    return [self indexForObject:@(kMarkTriggerParamTagKeepScrolling)];
}

- (NSAttributedString *)paramAttributedString {
    NSString *message = self.shouldStopScrolling ? NSLocalizedStringWithDefaultValue(@"ui.triggers.marktrigger.and_stop_scrolling.bc5c3332", nil, NSBundle.mainBundle, @"and stop scrolling", @"User-facing text in MarkTrigger (paramAttributedString).") : @"";
    return [[NSAttributedString alloc] initWithString:message attributes:self.regularAttributes];
}

@end
