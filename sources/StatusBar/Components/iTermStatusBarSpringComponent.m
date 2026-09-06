//
//  iTermStatusBarSpringComponent.m
//  iTerm2SharedARC
//
//  Created by George Nachman on 6/30/18.
//

#import "iTermStatusBarSpringComponent.h"

#import "NSDictionary+iTerm.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const iTermStatusBarSpringComponentSpringConstantKey = @"iTermStatusBarSpringComponentSpringConstantKey";
static NSString *const iTermStatusBarSpringComponentSizeMultipleKey = @"iTermStatusBarSpringComponentSizeMultipleKey";

@implementation iTermStatusBarSpringComponent {
    NSView *_view;
}

+ (instancetype)springComponentWithCompressionResistance:(double)compressionResistance {
    NSDictionary *knobs = @{ iTermStatusBarSpringComponentSpringConstantKey: @(compressionResistance) };
    NSDictionary *configuration = @{ iTermStatusBarComponentConfigurationKeyKnobValues: knobs };
    return [[iTermStatusBarSpringComponent alloc] initWithConfiguration:configuration
                                                                  scope:nil];
}

- (instancetype)initWithConfiguration:(NSDictionary<iTermStatusBarComponentConfigurationKey,id> *)configuration scope:(nullable iTermVariableScope *)scope {
    return [super initWithConfiguration:configuration scope:scope];
}

- (id)statusBarComponentExemplarWithBackgroundColor:(NSColor *)backgroundColor
                                          textColor:(NSColor *)textColor {
    switch (self.advancedConfiguration.layoutAlgorithm) {
        case iTermStatusBarLayoutAlgorithmSettingStable:
            return @"       ";
        case iTermStatusBarLayoutAlgorithmSettingTightlyPacked:
            return @"║〜〜║";
    }
}

- (NSString *)statusBarComponentShortDescription {
    switch (self.advancedConfiguration.layoutAlgorithm) {
        case iTermStatusBarLayoutAlgorithmSettingStable:
            return NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarspringcomponent.empty_space.65263a12", nil, NSBundle.mainBundle, @"Empty Space", @"Status bar component name.");
        case iTermStatusBarLayoutAlgorithmSettingTightlyPacked:
            return NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarspringcomponent.spring.db29e82a", nil, NSBundle.mainBundle, @"Spring", @"Status bar component name.");
    }
}

- (NSString *)statusBarComponentDetailedDescription {
    switch (self.advancedConfiguration.layoutAlgorithm) {
        case iTermStatusBarLayoutAlgorithmSettingStable:
            return NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarspringcomponent.empty_space_that_draws_only_a_background_color.ef612e88", nil, NSBundle.mainBundle, @"Empty space that draws only a background color.", @"Status bar component description.");
        case iTermStatusBarLayoutAlgorithmSettingTightlyPacked:
            return NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarspringcomponent.pushes_items_apart_use_one_spring_to_right_align_status_bar_elements_that_follow_it_use_two_to_center_those_inbetween.7b4ff689", nil, NSBundle.mainBundle, @"Pushes items apart. Use one spring to right-align status bar elements that follow it. Use two to center those inbetween.", @"Status bar component description.");
    }
}

- (NSView *)statusBarComponentView {
    if (!_view) {
        _view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, self.statusBarComponentMinimumWidth, 0)];
        _view.wantsLayer = YES;
        _view.layer.backgroundColor = [self color].CGColor;
    }
    return _view;
}

- (void)statusBarComponentSizeView:(NSView *)view toFitWidth:(CGFloat)width {
    NSRect rect = view.frame;
    rect.size.width = width;
    rect.size.height = view.superview.frame.size.height;
    view.frame = rect;
}

- (CGFloat)statusBarComponentMinimumWidth {
    return 0;
}

- (NSColor *)color {
    NSDictionary *knobValues = self.configuration[iTermStatusBarComponentConfigurationKeyKnobValues];
    return [knobValues[iTermStatusBarSharedBackgroundColorKey] colorValue] ?: [self statusBarBackgroundColor];
}

- (NSArray<iTermStatusBarComponentKnob *> *)statusBarComponentKnobs {
    iTermStatusBarComponentKnob *springConstantKnob = nil;

    switch (self.advancedConfiguration.layoutAlgorithm) {
        case iTermStatusBarLayoutAlgorithmSettingTightlyPacked:
            springConstantKnob =
            [[iTermStatusBarComponentKnob alloc] initWithLabelText:NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarbasecomponent.compression_resistance.86c8b1c0", nil, NSBundle.mainBundle, @"Compression Resistance:", @"Status bar advanced setting label.")
                                                              type:iTermStatusBarComponentKnobTypeDouble
                                                       placeholder:@""
                                                      defaultValue:@0.01
                                                               key:iTermStatusBarSpringComponentSpringConstantKey];
            break;
        case iTermStatusBarLayoutAlgorithmSettingStable:
            springConstantKnob =
            [[iTermStatusBarComponentKnob alloc] initWithLabelText:NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarbasecomponent.size_multiple.343d39f5", nil, NSBundle.mainBundle, @"Size Multiple:", @"Status bar advanced setting label.")
                                                              type:iTermStatusBarComponentKnobTypeDouble
                                                       placeholder:@""
                                                      defaultValue:@1
                                                               key:iTermStatusBarSpringComponentSizeMultipleKey];
            break;
    }
    iTermStatusBarComponentKnob *backgroundColorKnob =
    [[iTermStatusBarComponentKnob alloc] initWithLabelText:NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarspringcomponent.color.6b73191a", nil, NSBundle.mainBundle, @"Color", @"Status bar component setting label.")
                                                      type:iTermStatusBarComponentKnobTypeColor
                                               placeholder:nil
                                              defaultValue:nil
                                                       key:iTermStatusBarSharedBackgroundColorKey];
    return @[ springConstantKnob, backgroundColorKnob ];
}

+ (NSDictionary *)statusBarComponentDefaultKnobs {
    NSDictionary *fromSuper = [super statusBarComponentDefaultKnobs];
    return [fromSuper dictionaryByMergingDictionary:@{ iTermStatusBarSpringComponentSpringConstantKey: @0.01,
                                                       iTermStatusBarSpringComponentSizeMultipleKey: @1 }];
}

- (CGFloat)statusBarComponentSpringConstant {
    NSDictionary *knobValues = self.configuration[iTermStatusBarComponentConfigurationKeyKnobValues];
    NSNumber *number;
    switch (self.advancedConfiguration.layoutAlgorithm) {
        case iTermStatusBarLayoutAlgorithmSettingTightlyPacked:
            number = knobValues[iTermStatusBarSpringComponentSpringConstantKey];
            break;
        case iTermStatusBarLayoutAlgorithmSettingStable:
            number = knobValues[iTermStatusBarSpringComponentSizeMultipleKey];
            break;
    }
    return MAX(0.01, number ? number.doubleValue : 1);
}

- (BOOL)statusBarComponentCanStretch {
    return YES;
}

- (CGFloat)statusBarComponentPreferredWidth {
    return INFINITY;
}

- (BOOL)statusBarComponentHasMargins {
    return NO;
}

@end

NS_ASSUME_NONNULL_END
