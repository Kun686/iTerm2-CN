//
//  InteractiveScriptTrigger.m
//  iTerm
//
//  Created by George Nachman on 9/24/11.
//  Copyright 2011 Georgetech. All rights reserved.
//

#import "CoprocessTrigger.h"
#import "iTermAnnouncementViewController.h"
#import "PTYSession.h"
#import "iTerm2SharedARC-Swift.h"

static NSString *const kSuppressCoprocessTriggerWarning = @"NoSyncSuppressCoprocessTriggerWarning";

@implementation CoprocessTrigger

+ (NSString *)title {
    return NSLocalizedStringWithDefaultValue(@"ui.triggers.coprocesstrigger.run_coprocess.18345782", nil, NSBundle.mainBundle, @"Run Coprocess…", @"Trigger action title.");
}

- (NSString *)description {
    return [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.triggers.coprocesstrigger.run_coprocess.98b997b4", nil, NSBundle.mainBundle, @"Run Coprocess “%@”", @"Trigger action summary. Preserve the placeholder."), self.param];
}

- (BOOL)takesParameter {
    return YES;
}

- (NSString *)triggerOptionalParameterPlaceholderWithInterpolation:(BOOL)interpolation {
    return NSLocalizedStringWithDefaultValue(@"ui.triggers.coprocesstrigger.enter_coprocess_command_to_run.5a0f5c0b", nil, NSBundle.mainBundle, @"Enter coprocess command to run", @"Trigger parameter placeholder.");
}

// Requires a live session to launch a coprocess
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
    // Need to stop the world to get scope, provided it is needed. Coprocesses are so slow & rare that this is ok.
    id<iTermTriggerScopeProvider> scopeProvider = [aSession triggerSessionVariableScopeProvider:self];
    id<iTermTriggerCallbackScheduler> scheduler = [scopeProvider triggerCallbackScheduler];
    [[self paramWithBackreferencesReplacedWithValues:stringArray
                                             absLine:lineNumber
                                               scope:scopeProvider
                                    useInterpolation:useInterpolation] then:^(NSString * _Nonnull command) {
        [scheduler scheduleTriggerCallback:^{
            [aSession triggerSession:self
          launchCoprocessWithCommand:command
                          identifier:kSuppressCoprocessTriggerWarning
                              silent:self.isSilent];
        }];
    }];
    return YES;
}

- (BOOL)isSilent {
    return NO;
}

@end

@implementation MuteCoprocessTrigger

+ (NSString *)title {
    return NSLocalizedStringWithDefaultValue(@"ui.triggers.coprocesstrigger.run_silent_coprocess.4269812b", nil, NSBundle.mainBundle, @"Run Silent Coprocess…", @"Trigger action title.");
}

- (BOOL)takesParameter {
    return YES;
}

- (NSString *)triggerOptionalParameterPlaceholderWithInterpolation:(BOOL)interpolation {
    return NSLocalizedStringWithDefaultValue(@"ui.triggers.coprocesstrigger.enter_coprocess_command_to_run.5a0f5c0b", nil, NSBundle.mainBundle, @"Enter coprocess command to run", @"Trigger parameter placeholder.");
}

- (BOOL)isSilent {
    return YES;
}

@end
