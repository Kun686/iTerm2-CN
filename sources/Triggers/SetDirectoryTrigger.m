//
//  SetDirectoryTrigger.m
//  iTerm2
//
//  Created by George Nachman on 11/9/15.
//
//

#import "SetDirectoryTrigger.h"

#import "DebugLogging.h"

@implementation SetDirectoryTrigger

+ (NSString *)title {
  return NSLocalizedStringWithDefaultValue(@"ui.triggers.setdirectorytrigger.report_directory.974789f5", nil, NSBundle.mainBundle, @"Report Directory", @"Trigger action title.");
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Report Directory as “%@”", self.param];
}

- (BOOL)takesParameter{
  return YES;
}

- (NSString *)triggerOptionalParameterPlaceholderWithInterpolation:(BOOL)interpolation {
  return NSLocalizedStringWithDefaultValue(@"ui.triggers.setdirectorytrigger.directory.c8f84c3c", nil, NSBundle.mainBundle, @"Directory", @"Trigger parameter placeholder.");
}

- (BOOL)isIdempotent {
    return YES;
}

- (BOOL)performActionWithCapturedStrings:(NSArray<NSString *> *)stringArray
                          capturedRanges:(const NSRange *)capturedRanges
                               inSession:(id<iTermTriggerSession>)aSession
                                onString:(iTermStringLine *)stringLine
                    atAbsoluteLineNumber:(long long)lineNumber
                        useInterpolation:(BOOL)useInterpolation
                                    stop:(BOOL *)stop {
    // Need to stop the world to get scope, provided it is needed. Directory changes slow & rare that this is ok.
    id<iTermTriggerScopeProvider> scopeProvider = [aSession triggerSessionVariableScopeProvider:self];
    id<iTermTriggerCallbackScheduler> scheduler = [scopeProvider triggerCallbackScheduler];
    [[self paramWithBackreferencesReplacedWithValues:stringArray
                                             absLine:lineNumber
                                               scope:scopeProvider
                                    useInterpolation:useInterpolation] then:^(NSString * _Nonnull currentDirectory) {
        RLog(@"SetDirectoryTrigger completed substitution with %@", currentDirectory);
        if (currentDirectory.length) {
            [scheduler scheduleTriggerCallback:^{
                [aSession triggerSession:self setCurrentDirectory:currentDirectory];
            }];
        }
    }];
    return YES;
}


@end
