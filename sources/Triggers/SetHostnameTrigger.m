//
//  SetHostnameTrigger.m
//  iTerm2
//
//  Created by George Nachman on 11/9/15.
//
//

#import "SetHostnameTrigger.h"

@implementation SetHostnameTrigger

+ (NSString *)title {
    return NSLocalizedStringWithDefaultValue(@"ui.triggers.sethostnametrigger.report_user_host.3028a648", nil, NSBundle.mainBundle, @"Report User & Host", @"Trigger action title.");
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Report User & Host as “%@”", self.param];
}

- (BOOL)takesParameter{
    return YES;
}

- (NSString *)triggerOptionalParameterPlaceholderWithInterpolation:(BOOL)interpolation {
    return NSLocalizedStringWithDefaultValue(@"ui.triggers.sethostnametrigger.username_hostname.d5c25947", nil, NSBundle.mainBundle, @"username@hostname", @"Nontranslatable example format for the Set Hostname trigger parameter.");
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
    // Need to stop the world to get scope, provided it is needed. Hostname changes are slow & rare that this is ok.
    id<iTermTriggerScopeProvider> scopeProvider = [aSession triggerSessionVariableScopeProvider:self];
    id<iTermTriggerCallbackScheduler> scheduler = [scopeProvider triggerCallbackScheduler];
    [[self paramWithBackreferencesReplacedWithValues:stringArray
                                             absLine:lineNumber
                                               scope:scopeProvider
                                    useInterpolation:useInterpolation] then:^(NSString * _Nonnull remoteHost) {
        if (remoteHost.length) {
            [scheduler scheduleTriggerCallback:^{
                [aSession triggerSession:self setRemoteHostName:remoteHost];
            }];
        }
    }];
    return YES;
}

@end
