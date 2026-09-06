//
//  CaptureTrigger.m
//  iTerm
//
//  Created by George Nachman on 5/22/14.
//
//

#import "CaptureTrigger.h"

#import "CapturedOutput.h"
#import "iTermAnnouncementViewController.h"
#import "iTermApplicationDelegate.h"
#import "iTermCapturedOutputMark.h"
#import "iTermShellHistoryController.h"
#import "iTermToolbeltView.h"
#import "PTYTab.h"
#import "VT100ScreenMark.h"

@implementation CaptureTrigger

+ (NSString *)title {
    return NSLocalizedStringWithDefaultValue(@"ui.triggers.capturetrigger.capture_output.2543ca4b", nil, NSBundle.mainBundle, @"Capture Output", @"Trigger action title.");
}

- (NSString *)description {
    if ([NSString castFrom:self.param].length > 0) {
        return [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.triggers.capturetrigger.capture_output_running_on_double_click.4e9d0f95", nil, NSBundle.mainBundle, @"Capture output, running “%@” on double-click", @"Trigger action summary. Preserve the placeholder."), self.param];
    } else {
        return NSLocalizedStringWithDefaultValue(@"ui.triggers.capturetrigger.capture_output.2543ca4b", nil, NSBundle.mainBundle, @"Capture Output", @"Trigger action summary.");
    }
}

- (BOOL)takesParameter {
    return YES;
}

- (NSString *)triggerOptionalParameterPlaceholderWithInterpolation:(BOOL)interpolation {
    return NSLocalizedStringWithDefaultValue(@"ui.triggers.capturetrigger.coprocess_to_run_on_activation.d97dd8bc", nil, NSBundle.mainBundle, @"Coprocess to run on activation", @"Trigger parameter placeholder.");
}

- (void)showCaptureOutputToolInSession:(id<iTermTriggerSession>)aSession {
    return [aSession triggerSessionShowCapturedOutputTool:self];
}

- (BOOL)performActionWithCapturedStrings:(NSArray<NSString *> *)stringArray
                          capturedRanges:(const NSRange *)capturedRanges
                               inSession:(id<iTermTriggerSession>)aSession
                                onString:(iTermStringLine *)stringLine
                    atAbsoluteLineNumber:(long long)lineNumber
                        useInterpolation:(BOOL)useInterpolation
                                    stop:(BOOL *)stop {
    if (![aSession triggerSessionIsShellIntegrationInstalled:self]) {
        [aSession triggerSessionShowShellIntegrationRequiredAnnouncement:self];
    } else {
        [aSession triggerSessionShowCapturedOutputToolNotVisibleAnnouncementIfNeeded:self];
    }
    CapturedOutput *output = [[[CapturedOutput alloc] init] autorelease];
    output.absoluteLineNumber = lineNumber;
    output.line = stringLine.stringValue;
    const BOOL interpolate = [aSession triggerSessionShouldUseInterpolatedStrings:self];
    output.promisedCommand = [self paramWithBackreferencesReplacedWithValues:stringArray
                                                                     absLine:lineNumber
                                                                       scope:[aSession triggerSessionVariableScopeProvider:self]
                                                            useInterpolation:interpolate];
    output.values = stringArray;
    [aSession triggerSession:self didCaptureOutput:output];
    return NO;
}

@end
