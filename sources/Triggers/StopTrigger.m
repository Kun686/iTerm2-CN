//
//  StopTrigger.m
//  iTerm2
//
//  Created by George Nachman on 5/15/15.
//
//

#import "StopTrigger.h"

@implementation StopTrigger

+ (NSString *)title {
  return NSLocalizedStringWithDefaultValue(@"ui.triggers.stoptrigger.stop_processing_triggers.d310e6b3", nil, NSBundle.mainBundle, @"Stop Processing Triggers", @"Trigger action title.");
}

- (NSString *)description {
    return @"Stop Processing Triggers";
}

- (BOOL)takesParameter {
  return NO;
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
    *stop = YES;
    return NO;
}

@end
