//
//  iTermStatusBarPlaceholderComponent.m
//  iTerm2SharedARC
//
//  Created by George Nachman on 09/03/19.
//

#import "iTermStatusBarPlaceholderComponent.h"

NS_ASSUME_NONNULL_BEGIN

@implementation iTermStatusBarPlaceholderComponent

- (NSString *)statusBarComponentShortDescription {
    return NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarplaceholdercomponent.placeholder.f4b24fed", nil, NSBundle.mainBundle, @"Placeholder", @"Status bar component name.");
}

- (NSString *)statusBarComponentDetailedDescription {
    return NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarplaceholdercomponent.placeholder.f4b24fed", nil, NSBundle.mainBundle, @"Placeholder", @"Status bar component description.");
}

- (id)statusBarComponentExemplarWithBackgroundColor:(NSColor *)backgroundColor
                                          textColor:(NSColor *)textColor {
    assert(NO);
    return @"";
}

- (BOOL)statusBarComponentCanStretch {
    return YES;
}

- (BOOL)statusBarComponentIsInternal {
    return YES;
}

- (nullable NSString *)stringValue {
    return NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarplaceholdercomponent.click_here_to_configure_status_bar.ac0d1b29", nil, NSBundle.mainBundle, @"Click here to configure status bar", @"Status bar configuration prompt.");
}

- (nullable NSString *)stringValueForCurrentWidth {
    return self.stringValue;
}

- (nullable NSArray<NSString *> *)stringVariants {
    return @[ self.stringValue ?: @"" ];
}

- (nullable NSString *)statusBarComponentCopyableString {
    return nil;
}

- (BOOL)statusBarComponentHandlesClicks {
    return YES;
}

- (void)statusBarComponentDidClickWithView:(NSView *)view {
    [self.delegate statusBarComponentOpenStatusBarPreferences:self];
}

- (BOOL)statusBarComponentIsEmpty {
    // This is used to ensure there is at least one component, so it mustn't be hidden due to emptiness.
    return NO;
}

@end

NS_ASSUME_NONNULL_END
