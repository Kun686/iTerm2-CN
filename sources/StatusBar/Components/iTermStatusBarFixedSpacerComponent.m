//
//  iTermStatusBarFixedSpacerComponent.m
//  iTerm2SharedARC
//
//  Created by George Nachman on 6/30/18.
//

#import "iTermStatusBarFixedSpacerComponent.h"

#import "NSDictionary+iTerm.h"

static NSString *const iTermStatusBarFixedSpacerComponentWidthKnob = @"iTermStatusBarFixedSpacerComponentWidthKnob";

NS_ASSUME_NONNULL_BEGIN

@implementation iTermStatusBarFixedSpacerComponent {
    NSView *_view;
    CGFloat _width;
}

- (instancetype)initWithConfiguration:(NSDictionary<iTermStatusBarComponentConfigurationKey,id> *)configuration
                                scope:(nullable iTermVariableScope *)scope {
    self = [super initWithConfiguration:configuration scope:scope];
    if (self) {
        _width = [self widthInDictionary:configuration[iTermStatusBarComponentConfigurationKeyKnobValues]];
    }
    return self;
}

- (CGFloat)widthInDictionary:(NSDictionary *)knobValues {
    return [knobValues[iTermStatusBarFixedSpacerComponentWidthKnob] doubleValue] ?: 5;
}


- (id)statusBarComponentExemplarWithBackgroundColor:(NSColor *)backgroundColor
                                          textColor:(NSColor *)textColor {
    return @"╠══╣";
}

- (NSString *)statusBarComponentShortDescription {
    return NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarfixedspacercomponent.fixed_size_spacer.b96e04d5", nil, NSBundle.mainBundle, @"Fixed-size Spacer", @"Status bar component name.");
}

- (NSString *)statusBarComponentDetailedDescription {
    return NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarfixedspacercomponent.adds_a_fixed_amount_of_space.7ca17be9", nil, NSBundle.mainBundle, @"Adds a fixed amount of space", @"Status bar component description.");
}

- (NSView *)statusBarComponentView {
    if (!_view) {
        _view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, self.statusBarComponentMinimumWidth, 0)];
        _view.wantsLayer = YES;
        _view.layer.backgroundColor = [self statusBarBackgroundColor].CGColor;
    }
    return _view;
}

- (CGFloat)statusBarComponentMinimumWidth {
    return _width;
}

- (NSColor *)statusBarBackgroundColor {
    NSDictionary *knobValues = self.configuration[iTermStatusBarComponentConfigurationKeyKnobValues];
    return [knobValues[iTermStatusBarSharedBackgroundColorKey] colorValue] ?: [super statusBarBackgroundColor];
}

- (NSArray<iTermStatusBarComponentKnob *> *)statusBarComponentKnobs {
    iTermStatusBarComponentKnob *backgroundColorKnob =
    [[iTermStatusBarComponentKnob alloc] initWithLabelText:NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarfixedspacercomponent.color.6b73191a", nil, NSBundle.mainBundle, @"Color", @"Status bar component setting label.")
                                                      type:iTermStatusBarComponentKnobTypeColor
                                               placeholder:nil
                                              defaultValue:nil
                                                       key:iTermStatusBarSharedBackgroundColorKey];
    iTermStatusBarComponentKnob *widthKnob =
    [[iTermStatusBarComponentKnob alloc] initWithLabelText:NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarfixedspacercomponent.width.3019947b", nil, NSBundle.mainBundle, @"Width", @"Status bar component setting label.")
                                                      type:iTermStatusBarComponentKnobTypeDouble
                                               placeholder:nil
                                              defaultValue:@5
                                                       key:iTermStatusBarFixedSpacerComponentWidthKnob];
    return @[ backgroundColorKnob, widthKnob, [self newPriorityKnob] ];
}

+ (NSDictionary *)statusBarComponentDefaultKnobs {
    NSDictionary *knobs = [super statusBarComponentDefaultKnobs];
    knobs = [knobs dictionaryByMergingDictionary:@{ iTermStatusBarFixedSpacerComponentWidthKnob: @5 }];
    knobs = [knobs dictionaryBySettingObject:@(iTermStatusBarBaseComponentDefaultPriority)
                                      forKey:iTermStatusBarPriorityKey];
    return knobs;
}


@end

NS_ASSUME_NONNULL_END
