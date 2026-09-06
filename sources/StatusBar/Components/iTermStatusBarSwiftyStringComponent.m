//
//  iTermStatusBarSwiftyStringComponent.m
//  iTerm2SharedARC
//
//  Created by George Nachman on 6/29/18.
//

#import "iTermStatusBarSwiftyStringComponent.h"

#import "iTermScriptHistory.h"
#import "iTermStatusBarComponentKnob.h"
#import "iTermVariableScope.h"
#import "iTermWarning.h"
#import "NSDictionary+iTerm.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const iTermStatusBarSwiftyStringComponentExpressionKey = @"expression";

@implementation iTermStatusBarSwiftyStringComponent {
    iTermSwiftyString *_swiftyString;
    NSString *_errorReason;
}

- (instancetype)initWithConfiguration:(NSDictionary<iTermStatusBarComponentConfigurationKey,id> *)configuration
                                scope:(nullable iTermVariableScope *)scope {
    self = [super initWithConfiguration:configuration scope:scope];
    if (self) {
        [self updateWithKnobValues:self.configuration[iTermStatusBarComponentConfigurationKeyKnobValues]];
    }
    return self;
}

- (NSString *)statusBarComponentShortDescription {
    return NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarswiftystringcomponent.interpolated_string.1976235c", nil, NSBundle.mainBundle, @"Interpolated String", @"Status bar component name.");
}

- (NSString *)statusBarComponentDetailedDescription {
    return NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarswiftystringcomponent.shows_the_evaluation_of_a_string_with_inline_expressions_which_may_include_session_variables_or_the_output_of_registered_scripting_functions.9f4d3a5a", nil, NSBundle.mainBundle, @"Shows the evaluation of a string with inline expressions which may include session variables or the output of registered scripting functions", @"Status bar component description.");
}

- (NSArray<iTermStatusBarComponentKnob *> *)statusBarComponentKnobs {
    iTermStatusBarComponentKnob *expressionKnob =
        [[iTermStatusBarComponentKnob alloc] initWithLabelText:NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarswiftystringcomponent.string_value.feb497c9", nil, NSBundle.mainBundle, @"String Value:", @"Status bar component setting label.")
                                                          type:iTermStatusBarComponentKnobTypeText
                                                   placeholder:NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarswiftystringcomponent.string_with_expressions.41f4f968", nil, NSBundle.mainBundle, @"String with \\(expressions)", @"Status bar component setting placeholder. Preserve the expression syntax.")
                                                  defaultValue:@""
                                                           key:iTermStatusBarSwiftyStringComponentExpressionKey];
    return [@[ expressionKnob ] arrayByAddingObjectsFromArray:[super statusBarComponentKnobs]];
}

+ (NSDictionary *)statusBarComponentDefaultKnobs {
    NSDictionary *fromSuper = [super statusBarComponentDefaultKnobs];
    return [fromSuper dictionaryByMergingDictionary:@{ iTermStatusBarSwiftyStringComponentExpressionKey: @"" }];
}

- (id)statusBarComponentExemplarWithBackgroundColor:(NSColor *)backgroundColor
                                          textColor:(NSColor *)textColor {
    if (!_swiftyString.swiftyString.length) {
        return @"\\(expression)";
    } else {
        return _swiftyString.swiftyString;
    }
}

- (BOOL)statusBarComponentCanStretch {
    return YES;
}

- (void)setStringValue:(NSString *)value {
    _value = [value copy];
    [self updateTextFieldIfNeeded];
}

- (BOOL)statusBarComponentIsEmpty {
    return _value.length == 0;
}

- (NSTextField *)newTextField {
    NSTextField *textField = [super newTextField];

    NSClickGestureRecognizer *recognizer = [[NSClickGestureRecognizer alloc] init];
    recognizer.buttonMask = 1;
    recognizer.numberOfClicksRequired = 1;
    recognizer.target = self;
    recognizer.action = @selector(onClick:);
    [textField addGestureRecognizer:recognizer];

    return textField;
}

- (void)onClick:(id)sender {
    if (_errorReason) {
        [iTermWarning showWarningWithTitle:_errorReason
                                   actions:@[ NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarswiftystringcomponent.ok.565339bc", nil, NSBundle.mainBundle, @"OK", @"User-facing action label in iTermStatusBarSwiftyStringComponent (actions).") ]
                                 accessory:nil
                                identifier:@"NoSyncInterpolatedStatusBarComponentError"
                               silenceable:kiTermWarningTypePersistent
                                   heading:NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarswiftystringcomponent.error.54a0e8c1", nil, NSBundle.mainBundle, @"Error", @"User-facing text in iTermStatusBarSwiftyStringComponent (heading).")
                                    window:self.statusBarComponentView.window];
    }
}

- (nullable NSArray<NSString *> *)stringVariants {
    return @[ _value ?: @"" ];
}

- (void)updateWithKnobValues:(NSDictionary<NSString *, id> *)knobValues {
    NSString *expression = knobValues[iTermStatusBarSwiftyStringComponentExpressionKey] ?: @"";
    __weak __typeof(self) weakSelf = self;
    if ([self.delegate statusBarComponentIsInSetupUI:self]) {
        _swiftyString = [[iTermSwiftyStringPlaceholder alloc] initWithString:expression];
        self.stringValue = expression;
    } else {
        _swiftyString = [[iTermAnnotatingSwiftyString alloc] initWithString:expression
                                                                     scope:self.scope
                                                        sideEffectsAllowed:false
                                                                  observer:^NSString *(NSString * _Nonnull newValue, NSError *error) {
                                                             return [weakSelf didEvaluateExpression:expression withResult:newValue error:error];
                                                         }];
        self.stringValue = _swiftyString.evaluatedString;
    }
}

- (NSString *)didEvaluateExpression:(NSString *)expression
                         withResult:(NSString *)newValue
                              error:(NSError *)error {
    static NSString *ladybug = @"🐞";
    if (error != nil) {
        NSString *message = [NSString stringWithFormat:@"Error while evaluating “%@”:\n%@", expression, error.localizedDescription];
        [[iTermScriptHistoryEntry globalEntry] addOutput:message completion:^{}];
        _errorReason = message;
        return ladybug;
    } else if (newValue != ladybug) {
        _errorReason = nil;
    }
    [self setStringValue:newValue];
    return newValue;
}

- (void)statusBarComponentSetKnobValues:(NSDictionary *)knobValues {
    [self updateWithKnobValues:knobValues];
    [super statusBarComponentSetKnobValues:knobValues];
}

- (NSDictionary *)statusBarComponentKnobValues {
    return self.configuration[iTermStatusBarComponentConfigurationKeyKnobValues];
}

@end

NS_ASSUME_NONNULL_END
