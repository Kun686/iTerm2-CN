//
//  ScriptTrigger.m
//  iTerm
//
//  Created by George Nachman on 9/23/11.
//

#import "ScriptTrigger.h"
#import "DebugLogging.h"
#import "iTerm2SharedARC-Swift.h"
#import "iTermAdvancedSettingsModel.h"
#import "iTermBackgroundCommandRunner.h"
#import "iTermCommandRunnerPool.h"
#import "RegexKitLite.h"
#import "NSStringITerm.h"
#include <sys/types.h>
#include <pwd.h>

@implementation ScriptTrigger

+ (iTermBackgroundCommandRunnerPool *)commandRunnerPool {
    static iTermBackgroundCommandRunnerPool *pool;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pool = [[iTermBackgroundCommandRunnerPool alloc] initWithCapacity:[iTermAdvancedSettingsModel maximumNumberOfTriggerCommands]];
    });
    return pool;
}

+ (NSString *)title
{
    return NSLocalizedStringWithDefaultValue(@"ui.triggers.scripttrigger.run_command.91eb0214", nil, NSBundle.mainBundle, @"Run Command…", @"Trigger action title.");
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Run Command “%@”", self.param];
}

- (BOOL)takesParameter
{
    return YES;
}

- (NSString *)triggerOptionalParameterPlaceholderWithInterpolation:(BOOL)interpolation {
    return NSLocalizedStringWithDefaultValue(@"ui.triggers.scripttrigger.enter_command_to_run.3fcf9c3a", nil, NSBundle.mainBundle, @"Enter command to run", @"Trigger parameter placeholder.");
}

- (NSSet<NSNumber *> *)allowedMatchTypes {
    NSMutableSet *set = [NSMutableSet setWithObject:@(iTermTriggerMatchTypeRegex)];
    [set unionSet:[iTermEventTriggerMatchTypeHelper allEventTypesSet]];
    return set;
}


- (BOOL)performActionWithCapturedStrings:(NSArray<NSString *> *)stringArray
                          capturedRanges:(const NSRange *)capturedRanges
                               inSession:(id<iTermTriggerSession>)aSession
                                onString:(iTermStringLine *)stringLine
                    atAbsoluteLineNumber:(long long)lineNumber
                        useInterpolation:(BOOL)useInterpolation
                                    stop:(BOOL *)stop {
    // Need to stop the world to get scope, provided it is needed. Running a command is so slow & rare that this is ok.
    id<iTermTriggerScopeProvider> scopeProvider = [aSession triggerSessionVariableScopeProvider:self];
    id<iTermTriggerCallbackScheduler> scheduler = [scopeProvider triggerCallbackScheduler];
    [[self paramWithBackreferencesReplacedWithValues:stringArray
                                             absLine:lineNumber
                                               scope:scopeProvider
                                    useInterpolation:useInterpolation] then:^(NSString * _Nonnull command) {
        [scheduler scheduleTriggerCallback:^{
            [self runCommand:command session:aSession];
        }];
    }];
    return YES;
}

- (void)runCommand:(NSString *)command session:(id<iTermTriggerSession>)session {
    // command has regex capture groups from terminal output interpolated in; keep it out of the ring.
    RLog(@"Invoking command %@", RLogRedact(command, @(command.length)));

    [session triggerSession:self runCommand:command withRunnerPool:[ScriptTrigger commandRunnerPool]];
}

@end
