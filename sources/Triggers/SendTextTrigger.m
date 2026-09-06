//
//  SendTextTrigger.m
//  iTerm
//
//  Created by George Nachman on 9/24/11.
//

#import "SendTextTrigger.h"
#import "PTYSession.h"
#import "iTerm2SharedARC-Swift.h"

@implementation SendTextTrigger

+ (NSString *)title
{
    return NSLocalizedStringWithDefaultValue(@"ui.triggers.sendtexttrigger.send_text.31619199", nil, NSBundle.mainBundle, @"Send Text…", @"Trigger action title.");
}

- (NSString *)description {
    return [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.triggers.sendtexttrigger.send_text.6ec594c7", nil, NSBundle.mainBundle, @"Send text “%@”", @"Trigger action summary. Preserve the placeholder."), self.param];
}

- (BOOL)takesParameter
{
    return YES;
}

- (NSString *)triggerOptionalParameterPlaceholderWithInterpolation:(BOOL)interpolation {
    return NSLocalizedStringWithDefaultValue(@"ui.triggers.sendtexttrigger.enter_text_to_send.da82d0ba", nil, NSBundle.mainBundle, @"Enter text to send", @"Trigger parameter placeholder.");
}

// Requires a live session to send text to
- (NSSet<NSNumber *> *)allowedMatchTypes {
    NSMutableSet *set = [NSMutableSet setWithObject:@(iTermTriggerMatchTypeRegex)];
    [set unionSet:[iTermEventTriggerMatchTypeHelper allEventTypesExceptSessionEndedSet]];
    return set;
}


- (BOOL)performActionWithCapturedStrings:(NSArray<NSString *> *)stringArray
                          capturedRanges:(const NSRange *)capturedRanges
                               inSession:(id<iTermTriggerSession>)aSession
                                onString:(iTermStringLine *)stringLine
                    atAbsoluteLineNumber:(long long)lineNumber
                        useInterpolation:(BOOL)useInterpolation
                                    stop:(BOOL *)stop {
    // Need to stop the world to get scope, provided it is needed. This will be a modest performance issue at most.
    id<iTermTriggerScopeProvider> scopeProvider = [aSession triggerSessionVariableScopeProvider:self];
    id<iTermTriggerCallbackScheduler> scheduler = [scopeProvider triggerCallbackScheduler];
    [[self paramWithBackreferencesReplacedWithValues:stringArray
                                             absLine:lineNumber
                                               scope:scopeProvider
                                    useInterpolation:useInterpolation] then:^(NSString * _Nonnull message) {
        [scheduler scheduleTriggerCallback:^{
            [aSession triggerSession:self writeText:message];
        }];
    }];
    return YES;
}

@end
