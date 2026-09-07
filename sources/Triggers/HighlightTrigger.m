//
//  HighlightTrigger.m
//  iTerm2
//
//  Created by George Nachman on 9/23/11.
//

#import "HighlightTrigger.h"
#import "NSColor+iTerm.h"
#import "NSDictionary+iTerm.h"
#import "NSImage+iTerm.h"
#import "ScreenChar.h"

NSString * const kHighlightForegroundColor = @"kHighlightForegroundColor";
NSString * const kHighlightBackgroundColor = @"kHighlightBackgroundColor";


// Preserve these values - they are the tags and are saved in preferences.
enum {
    kYellowOnBlackHighlight,
    kBlackOnYellowHighlight,
    kWhiteOnRedHighlight,
    kRedOnWhiteHighlight,
    kBlackOnOrangeHighlight,
    kOrangeOnBlackHighlight,
    kBlackOnPurpleHighlight,
    kPurpleOnBlackHighlight,

    kBlackHighlight = 1000,
    kDarkGrayHighlight,
    kLightGrayHighlight,
    kWhiteHighlight,
    kGrayHighlight,
    kRedHighlight,
    kGreenHighlight,
    kBlueHighlight,
    kCyanHighlight,
    kYellowHighlight,
    kMagentaHighlight,
    kOrangeHighlight,
    kPurpleHighlight,
    kBrownHighlight,

    kBlackBackgroundHighlight = 2000,
    kDarkGrayBackgroundHighlight,
    kLightGrayBackgroundHighlight,
    kWhiteBackgroundHighlight,
    kGrayBackgroundHighlight,
    kRedBackgroundHighlight,
    kGreenBackgroundHighlight,
    kBlueBackgroundHighlight,
    kCyanBackgroundHighlight,
    kYellowBackgroundHighlight,
    kMagentaBackgroundHighlight,
    kOrangeBackgroundHighlight,
    kPurpleBackgroundHighlight,
    kBrownBackgroundHighlight,


};

@implementation HighlightTrigger {
    NSDictionary *_cachedColors;
}

+ (NSString *)title {
    return NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.highlight_text.b6130a2f", nil, NSBundle.mainBundle, @"Highlight Text…", @"Trigger action title.");
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Highlight text %@ over %@", self.textColor.humanReadableDescription ?: @"(no color)", self.backgroundColor.humanReadableDescription ?: @"(no color))"];
}

- (NSString *)triggerOptionalParameterPlaceholderWithInterpolation:(BOOL)interpolation {
    return @"";
}

- (BOOL)takesParameter
{
    return YES;
}

- (BOOL)paramIsPopupButton {
    return NO;
}

- (BOOL)paramIsTwoColorWells {
    return YES;
}

- (BOOL)isIdempotent {
    return YES;
}

- (void)sanitize {
    NSDictionary *colors = [self colorsPreservingColorSpace:YES];
    self.textColor = colors[kHighlightForegroundColor];
    self.backgroundColor = colors[kHighlightBackgroundColor];
}

- (NSColor *)textColorInParam:(id)param {
    NSDictionary *colors = [HighlightTrigger colorsPreservingColorSpace:NO param:param];
    return colors[kHighlightForegroundColor];
}

- (NSColor *)backgroundColorInParam:(id)param {
    NSDictionary *colors = [HighlightTrigger colorsPreservingColorSpace:NO param:param];
    return colors[kHighlightBackgroundColor];
}

- (NSDictionary *)menuItemsForPoupupButton {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.yellow_on_black.761765b9", nil, NSBundle.mainBundle, @"Yellow on Black", @"Highlight trigger color option."), [NSNumber numberWithInt:(int)kYellowOnBlackHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.black_on_yellow.e1ee5d3e", nil, NSBundle.mainBundle, @"Black on Yellow", @"Highlight trigger color option."), [NSNumber numberWithInt:(int)kBlackOnYellowHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.white_on_red.83b5edbd", nil, NSBundle.mainBundle, @"White on Red", @"Highlight trigger color option."),    [NSNumber numberWithInt:(int)kWhiteOnRedHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.red_on_white.81fa7d2c", nil, NSBundle.mainBundle, @"Red on White", @"Highlight trigger color option."),    [NSNumber numberWithInt:(int)kRedOnWhiteHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.black_on_orange.9bec7a8a", nil, NSBundle.mainBundle, @"Black on Orange", @"Highlight trigger color option."), [NSNumber numberWithInt:(int)kBlackOnOrangeHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.orange_on_black.455c2e0e", nil, NSBundle.mainBundle, @"Orange on Black", @"Highlight trigger color option."), [NSNumber numberWithInt:(int)kOrangeOnBlackHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.purple_on_black.3317ead3", nil, NSBundle.mainBundle, @"Purple on Black", @"Highlight trigger color option."), [NSNumber numberWithInt:(int)kPurpleOnBlackHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.black_on_purple.d76ca289", nil, NSBundle.mainBundle, @"Black on Purple", @"Highlight trigger color option."), [NSNumber numberWithInt:(int)kBlackOnPurpleHighlight],

            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.black_foreground.fc077eb5", nil, NSBundle.mainBundle, @"Black Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kBlackHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.blue_foreground.ceaf9af9", nil, NSBundle.mainBundle, @"Blue Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kBlueHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.brown_foreground.b44985bf", nil, NSBundle.mainBundle, @"Brown Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kBrownHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.cyan_foreground.11db9503", nil, NSBundle.mainBundle, @"Cyan Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kCyanHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.dark_gray_foreground.09e92a52", nil, NSBundle.mainBundle, @"Dark Gray Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kDarkGrayHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.gray_foreground.18b5036f", nil, NSBundle.mainBundle, @"Gray Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kGrayHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.green_foreground.fa77200c", nil, NSBundle.mainBundle, @"Green Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kGreenHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.light_gray_foreground.852ec861", nil, NSBundle.mainBundle, @"Light Gray Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kLightGrayHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.magenta_foreground.46eba388", nil, NSBundle.mainBundle, @"Magenta Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kMagentaHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.orange_foreground.ee40fa4d", nil, NSBundle.mainBundle, @"Orange Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kOrangeHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.purple_foreground.193e532b", nil, NSBundle.mainBundle, @"Purple Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kPurpleHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.red_foreground.00e89ff4", nil, NSBundle.mainBundle, @"Red Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kRedHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.white_foreground.c12073d6", nil, NSBundle.mainBundle, @"White Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kWhiteHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.yellow_foreground.804fd792", nil, NSBundle.mainBundle, @"Yellow Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kYellowHighlight],

            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.black_background.b04caa23", nil, NSBundle.mainBundle, @"Black Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kBlackBackgroundHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.blue_background.990b650d", nil, NSBundle.mainBundle, @"Blue Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kBlueBackgroundHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.brown_background.13494d58", nil, NSBundle.mainBundle, @"Brown Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kBrownBackgroundHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.cyan_background.f5cf08c2", nil, NSBundle.mainBundle, @"Cyan Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kCyanBackgroundHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.dark_gray_background.04082214", nil, NSBundle.mainBundle, @"Dark Gray Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kDarkGrayBackgroundHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.gray_background.21c8f560", nil, NSBundle.mainBundle, @"Gray Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kGrayBackgroundHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.green_background.375e1e8f", nil, NSBundle.mainBundle, @"Green Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kGreenBackgroundHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.light_gray_background.6b018f49", nil, NSBundle.mainBundle, @"Light Gray Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kLightGrayBackgroundHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.magenta_background.64552500", nil, NSBundle.mainBundle, @"Magenta Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kMagentaBackgroundHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.orange_background.e283a2e6", nil, NSBundle.mainBundle, @"Orange Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kOrangeBackgroundHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.purple_background.0a86ae56", nil, NSBundle.mainBundle, @"Purple Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kPurpleBackgroundHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.red_background.be2d0745", nil, NSBundle.mainBundle, @"Red Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kRedBackgroundHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.white_background.c18f4c71", nil, NSBundle.mainBundle, @"White Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kWhiteBackgroundHighlight],
            NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.yellow_background.8222644b", nil, NSBundle.mainBundle, @"Yellow Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kYellowBackgroundHighlight],

            nil];
}

- (NSArray *)groupedMenuItemsForPopupButton {
    NSDictionary *fgbg = [NSDictionary dictionaryWithObjectsAndKeys:
                          NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.yellow_on_black.761765b9", nil, NSBundle.mainBundle, @"Yellow on Black", @"Highlight trigger color option."), [NSNumber numberWithInt:(int)kYellowOnBlackHighlight],
                          NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.black_on_yellow.e1ee5d3e", nil, NSBundle.mainBundle, @"Black on Yellow", @"Highlight trigger color option."), [NSNumber numberWithInt:(int)kBlackOnYellowHighlight],
                          NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.white_on_red.83b5edbd", nil, NSBundle.mainBundle, @"White on Red", @"Highlight trigger color option."),    [NSNumber numberWithInt:(int)kWhiteOnRedHighlight],
                          NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.red_on_white.81fa7d2c", nil, NSBundle.mainBundle, @"Red on White", @"Highlight trigger color option."),    [NSNumber numberWithInt:(int)kRedOnWhiteHighlight],
                          NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.black_on_orange.9bec7a8a", nil, NSBundle.mainBundle, @"Black on Orange", @"Highlight trigger color option."), [NSNumber numberWithInt:(int)kBlackOnOrangeHighlight],
                          NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.orange_on_black.455c2e0e", nil, NSBundle.mainBundle, @"Orange on Black", @"Highlight trigger color option."), [NSNumber numberWithInt:(int)kOrangeOnBlackHighlight],
                          NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.purple_on_black.3317ead3", nil, NSBundle.mainBundle, @"Purple on Black", @"Highlight trigger color option."), [NSNumber numberWithInt:(int)kPurpleOnBlackHighlight],
                          NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.black_on_purple.d76ca289", nil, NSBundle.mainBundle, @"Black on Purple", @"Highlight trigger color option."), [NSNumber numberWithInt:(int)kBlackOnPurpleHighlight],
                          nil];
    NSDictionary *fg = [NSDictionary dictionaryWithObjectsAndKeys:
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.black_foreground.fc077eb5", nil, NSBundle.mainBundle, @"Black Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kBlackHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.blue_foreground.ceaf9af9", nil, NSBundle.mainBundle, @"Blue Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kBlueHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.brown_foreground.b44985bf", nil, NSBundle.mainBundle, @"Brown Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kBrownHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.cyan_foreground.11db9503", nil, NSBundle.mainBundle, @"Cyan Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kCyanHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.dark_gray_foreground.09e92a52", nil, NSBundle.mainBundle, @"Dark Gray Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kDarkGrayHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.gray_foreground.18b5036f", nil, NSBundle.mainBundle, @"Gray Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kGrayHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.green_foreground.fa77200c", nil, NSBundle.mainBundle, @"Green Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kGreenHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.light_gray_foreground.852ec861", nil, NSBundle.mainBundle, @"Light Gray Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kLightGrayHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.magenta_foreground.46eba388", nil, NSBundle.mainBundle, @"Magenta Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kMagentaHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.orange_foreground.ee40fa4d", nil, NSBundle.mainBundle, @"Orange Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kOrangeHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.purple_foreground.193e532b", nil, NSBundle.mainBundle, @"Purple Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kPurpleHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.red_foreground.00e89ff4", nil, NSBundle.mainBundle, @"Red Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kRedHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.white_foreground.c12073d6", nil, NSBundle.mainBundle, @"White Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kWhiteHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.yellow_foreground.804fd792", nil, NSBundle.mainBundle, @"Yellow Foreground", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kYellowHighlight],
                        nil];

    NSDictionary *bg = [NSDictionary dictionaryWithObjectsAndKeys:
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.black_background.b04caa23", nil, NSBundle.mainBundle, @"Black Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kBlackBackgroundHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.blue_background.990b650d", nil, NSBundle.mainBundle, @"Blue Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kBlueBackgroundHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.brown_background.13494d58", nil, NSBundle.mainBundle, @"Brown Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kBrownBackgroundHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.cyan_background.f5cf08c2", nil, NSBundle.mainBundle, @"Cyan Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kCyanBackgroundHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.gray_background.21c8f560", nil, NSBundle.mainBundle, @"Gray Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kDarkGrayBackgroundHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.gray_background.21c8f560", nil, NSBundle.mainBundle, @"Gray Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kGrayBackgroundHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.green_background.375e1e8f", nil, NSBundle.mainBundle, @"Green Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kGreenBackgroundHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.light_gray_background.6b018f49", nil, NSBundle.mainBundle, @"Light Gray Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kLightGrayBackgroundHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.magenta_background.64552500", nil, NSBundle.mainBundle, @"Magenta Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kMagentaBackgroundHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.orange_background.e283a2e6", nil, NSBundle.mainBundle, @"Orange Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kOrangeBackgroundHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.purple_background.0a86ae56", nil, NSBundle.mainBundle, @"Purple Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kPurpleBackgroundHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.red_background.be2d0745", nil, NSBundle.mainBundle, @"Red Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kRedBackgroundHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.white_background.c18f4c71", nil, NSBundle.mainBundle, @"White Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kWhiteBackgroundHighlight],
                        NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.yellow_background.8222644b", nil, NSBundle.mainBundle, @"Yellow Background", @"Highlight trigger color option."),  [NSNumber numberWithInt:(int)kYellowBackgroundHighlight],
                        nil];
    return [NSArray arrayWithObjects:fgbg, fg, bg, nil];
}

- (BOOL)instantTriggerCanFireMultipleTimesPerLine {
    return YES;
}

- (NSInteger)indexForObject:(id)object {
    int i = 0;
    BOOL isFirst = YES;
    for (NSDictionary *dict in [self groupedMenuItemsForPopupButton]) {
        if (!isFirst) {
            ++i;
        }
        isFirst = NO;
        for (NSNumber *n in [self objectsSortedByValueInDict:dict]) {
            if ([n isEqual:object]) {
                return i;
            }
            i++;
        }
    }
    return -1;
}

- (id)objectAtIndex:(NSInteger)theIndex {
    int i = 0;
    BOOL isFirst = YES;
    for (NSDictionary *dict in [self groupedMenuItemsForPopupButton]) {
        if (!isFirst) {
            ++i;
        }
        isFirst = NO;
        for (NSNumber *n in [self objectsSortedByValueInDict:dict]) {
            if (i == theIndex) {
                return n;
            }
            i++;
        }
    }
    return nil;
}

- (NSDictionary *)dictionaryWithForegroundColor:(NSColor *)foreground
                                backgroundColor:(NSColor *)background {
    return [HighlightTrigger dictionaryWithForegroundColor:foreground
                                           backgroundColor:background];
}

+ (NSDictionary *)dictionaryWithForegroundColor:(NSColor *)foreground
                                backgroundColor:(NSColor *)background {
    return [NSDictionary dictionaryWithObjectsAndKeys:foreground, kHighlightForegroundColor, background, kHighlightBackgroundColor, nil];
}

- (NSDictionary *)dictionaryWithForegroundColor:(NSColor *)foreground {
    return [HighlightTrigger dictionaryWithForegroundColor:foreground];
}

+ (NSDictionary *)dictionaryWithForegroundColor:(NSColor *)foreground {
    return [NSDictionary dictionaryWithObjectsAndKeys:foreground, kHighlightForegroundColor, nil];
}

- (NSDictionary *)dictionaryWithBackgroundColor:(NSColor *)background {
    return [HighlightTrigger dictionaryWithBackgroundColor:background];
}

+ (NSDictionary *)dictionaryWithBackgroundColor:(NSColor *)background {
    return [NSDictionary dictionaryWithObjectsAndKeys:background, kHighlightBackgroundColor, nil];
}

- (NSString *)stringValue {
    return [self stringForTextColor:self.textColor backgroundColor:self.backgroundColor];
}

- (NSString *)stringForTextColor:(NSColor *)textColor backgroundColor:(NSColor *)backgroundColor {
    return [NSString stringWithFormat:@"{%@,%@}",
            textColor.hexStringPreservingColorSpace ?: @"",
            backgroundColor.hexStringPreservingColorSpace ?: @""];
}

- (NSColor *)textColor {
    NSDictionary *colors = [self colorsPreservingColorSpace:NO];
    return colors[kHighlightForegroundColor];
}

- (NSColor *)backgroundColor {
    NSDictionary *colors = [self colorsPreservingColorSpace:NO];
    return colors[kHighlightBackgroundColor];
}

- (void)setTextColor:(NSColor *)textColor {
    [super setTextColor:textColor];
    NSMutableArray *temp = [[self stringsForColors] mutableCopy];
    temp[0] = textColor ? textColor.hexStringPreservingColorSpace: @"";
    self.param = [NSString stringWithFormat:@"{%@,%@}", temp[0], temp[1]];
}

- (void)setBackgroundColor:(NSColor *)backgroundColor {
    [super setBackgroundColor:backgroundColor];
    NSMutableArray *temp = [[self stringsForColors] mutableCopy];
    temp[1] = backgroundColor ? backgroundColor.hexStringPreservingColorSpace: @"";
    self.param = [NSString stringWithFormat:@"{%@,%@}", temp[0], temp[1]];
}

- (void)setParam:(id)param {
    _cachedColors = nil;
    [super setParam:param];
}

// Returns a string of the form {text components,background components} from self.param.
- (NSArray<NSString *> *)stringsForColors {
    return [HighlightTrigger stringsForColorsInParam:self.param];
}

+ (NSArray<NSString *> *)stringsForColorsInParam:(id)param {
    if (param == nil) {
        return @[ [[NSColor whiteColor] hexString], [[NSColor redColor] hexString] ];
    }
    if ([param isKindOfClass:[NSString class]] &&
        [param hasPrefix:@"{"] && [param hasSuffix:@"}"]) {
        NSString *stringParam = param;
        NSString *inner = [param substringWithRange:NSMakeRange(1, stringParam.length - 2)];
        NSArray *parts = [inner componentsSeparatedByString:@","];
        if (parts.count == 2) {
            return parts;
        }
        return @[ @"", @"" ];
    }

    if ([param isKindOfClass:[NSNumber class]]) {
        NSNumber *numberParam = param;
        NSDictionary *dict = [self colorDictionaryForInteger:numberParam.intValue];
        NSColor *text = dict[kHighlightForegroundColor];
        NSColor *background = dict[kHighlightBackgroundColor];
        return @[ text ? text.hexString : @"",
                  background ? background.hexString : @"" ];
    }

    return @[ @"", @"" ];
}

// Returns a dictionary with text and background color from the self.param string.
- (NSDictionary<NSString *, NSColor *> *)colorsPreservingColorSpace:(BOOL)preserveColorSpace {
    if (_cachedColors) {
        return _cachedColors;
    }
    NSDictionary *dict = [HighlightTrigger colorsPreservingColorSpace:preserveColorSpace param:self.param];
    _cachedColors = [dict copy];
    return dict;
}

+ (NSDictionary<NSString *, NSColor *> *)colorsPreservingColorSpace:(BOOL)preserveColorSpace
                                                              param:(id)param {
    NSArray *parts = [HighlightTrigger stringsForColorsInParam:param];
    NSMutableDictionary<NSString *, NSColor *> *dict = [NSMutableDictionary dictionary];
    NSColor *textColor = nil;
    NSColor *backgroundColor = nil;
    if (parts.count == 2) {
        if (preserveColorSpace) {
            textColor = [NSColor colorPreservingColorspaceFromString:parts[0]];
            backgroundColor = [NSColor colorPreservingColorspaceFromString:parts[1]];
        } else {
            textColor = [NSColor colorWithString:parts[0]];
            backgroundColor = [NSColor colorWithString:parts[1]];
        }
    }
    if (textColor) {
        dict[kHighlightForegroundColor] = textColor;
    }
    if (backgroundColor) {
        dict[kHighlightBackgroundColor] = backgroundColor;
    }
    return dict;
}

- (NSDictionary *)colorDictionaryForInteger:(int)param {
    return [HighlightTrigger colorDictionaryForInteger:param];
}

+ (NSDictionary *)colorDictionaryForInteger:(int)param {
    switch (param) {
        case kYellowOnBlackHighlight:
            return [self dictionaryWithForegroundColor:[NSColor yellowColor] backgroundColor:[NSColor blackColor]];

        case kBlackOnYellowHighlight:
            return [self dictionaryWithForegroundColor:[NSColor blackColor] backgroundColor:[NSColor yellowColor]];

        case kWhiteOnRedHighlight:
            return [self dictionaryWithForegroundColor:[NSColor whiteColor] backgroundColor:[NSColor redColor]];

        case kRedOnWhiteHighlight:
            return [self dictionaryWithForegroundColor:[NSColor redColor] backgroundColor:[NSColor whiteColor]];

        case kBlackOnOrangeHighlight:
            return [self dictionaryWithForegroundColor:[NSColor blackColor] backgroundColor:[NSColor orangeColor]];

        case kOrangeOnBlackHighlight:
            return [self dictionaryWithForegroundColor:[NSColor orangeColor] backgroundColor:[NSColor blackColor]];

        case kBlackOnPurpleHighlight:
            return [self dictionaryWithForegroundColor:[NSColor blackColor] backgroundColor:[NSColor purpleColor]];

        case kPurpleOnBlackHighlight:
            return [self dictionaryWithForegroundColor:[NSColor purpleColor] backgroundColor:[NSColor blackColor]];

        case kBlackHighlight:
            return [self dictionaryWithForegroundColor:[NSColor blackColor]];

        case kDarkGrayHighlight:
            return [self dictionaryWithForegroundColor:[NSColor darkGrayColor]];

        case kLightGrayHighlight:
            return [self dictionaryWithForegroundColor:[NSColor lightGrayColor]];

        case kWhiteHighlight:
            return [self dictionaryWithForegroundColor:[NSColor whiteColor]];

        case kGrayHighlight:
            return [self dictionaryWithForegroundColor:[NSColor grayColor]];

        case kRedHighlight:
            return [self dictionaryWithForegroundColor:[NSColor redColor]];

        case kGreenHighlight:
            return [self dictionaryWithForegroundColor:[NSColor greenColor]];

        case kBlueHighlight:
            return [self dictionaryWithForegroundColor:[NSColor blueColor]];

        case kCyanHighlight:
            return [self dictionaryWithForegroundColor:[NSColor cyanColor]];

        case kYellowHighlight:
            return [self dictionaryWithForegroundColor:[NSColor yellowColor]];

        case kMagentaHighlight:
            return [self dictionaryWithForegroundColor:[NSColor magentaColor]];

        case kOrangeHighlight:
            return [self dictionaryWithForegroundColor:[NSColor orangeColor]];

        case kPurpleHighlight:
            return [self dictionaryWithForegroundColor:[NSColor purpleColor]];

        case kBrownHighlight:
            return [self dictionaryWithForegroundColor:[NSColor brownColor]];

        case kBlackBackgroundHighlight:
            return [self dictionaryWithBackgroundColor:[NSColor blackColor]];

        case kDarkGrayBackgroundHighlight:
            return [self dictionaryWithBackgroundColor:[NSColor darkGrayColor]];

        case kLightGrayBackgroundHighlight:
            return [self dictionaryWithBackgroundColor:[NSColor lightGrayColor]];

        case kWhiteBackgroundHighlight:
            return [self dictionaryWithBackgroundColor:[NSColor whiteColor]];

        case kGrayBackgroundHighlight:
            return [self dictionaryWithBackgroundColor:[NSColor grayColor]];

        case kRedBackgroundHighlight:
            return [self dictionaryWithBackgroundColor:[NSColor redColor]];

        case kGreenBackgroundHighlight:
            return [self dictionaryWithBackgroundColor:[NSColor greenColor]];

        case kBlueBackgroundHighlight:
            return [self dictionaryWithBackgroundColor:[NSColor blueColor]];

        case kCyanBackgroundHighlight:
            return [self dictionaryWithBackgroundColor:[NSColor cyanColor]];

        case kYellowBackgroundHighlight:
            return [self dictionaryWithBackgroundColor:[NSColor yellowColor]];

        case kMagentaBackgroundHighlight:
            return [self dictionaryWithBackgroundColor:[NSColor magentaColor]];

        case kOrangeBackgroundHighlight:
            return [self dictionaryWithBackgroundColor:[NSColor orangeColor]];

        case kPurpleBackgroundHighlight:
            return [self dictionaryWithBackgroundColor:[NSColor purpleColor]];

        case kBrownBackgroundHighlight:
            return [self dictionaryWithBackgroundColor:[NSColor brownColor]];
    }
    return nil;
}

- (BOOL)performActionWithCapturedStrings:(NSArray<NSString *> *)stringArray
                          capturedRanges:(const NSRange *)capturedRanges
                               inSession:(id<iTermTriggerSession>)aSession
                                onString:(iTermStringLine *)stringLine
                    atAbsoluteLineNumber:(long long)lineNumber
                        useInterpolation:(BOOL)useInterpolation
                                    stop:(BOOL *)stop {
    NSRange rangeInString = capturedRanges[0];
    NSRange rangeInScreenChars = [stringLine rangeOfScreenCharsForRangeInString:rangeInString];

    [aSession triggerSession:self
        highlightTextInRange:rangeInScreenChars
                absoluteLine:lineNumber
                      colors:[self colorsPreservingColorSpace:NO]];
    return YES;
}

- (NSAttributedString *)paramAttributedString {
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];

    [result appendAttributedString:[[NSAttributedString alloc] initWithString:NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.text.21784f40", nil, NSBundle.mainBundle, @"Text: ", @"User-facing text in HighlightTrigger (paramAttributedString).")]];

    NSTextAttachment *textColorAttachment = [[NSTextAttachment alloc] init];
    textColorAttachment.image = [self imageForColor:self.textColor];
    NSAttributedString *textAttachmentString = [NSAttributedString attributedStringWithAttachment:textColorAttachment];
    NSMutableAttributedString *mutableTextAttachmentString = [textAttachmentString mutableCopy];
    // Lower the image by adjusting the baseline offset.
    [mutableTextAttachmentString addAttribute:NSBaselineOffsetAttributeName value:@(-2) range:NSMakeRange(0, mutableTextAttachmentString.length)];
    [result appendAttributedString:mutableTextAttachmentString];

    [result appendAttributedString:[[NSAttributedString alloc] initWithString:NSLocalizedStringWithDefaultValue(@"ui.triggers.highlighttrigger.background.effa332c", nil, NSBundle.mainBundle, @" Background: ", @"User-facing text in HighlightTrigger (paramAttributedString).")]];

    NSTextAttachment *backgroundColorAttachment = [[NSTextAttachment alloc] init];
    backgroundColorAttachment.image = [self imageForColor:self.backgroundColor];
    NSAttributedString *backgroundAttachmentString = [NSAttributedString attributedStringWithAttachment:backgroundColorAttachment];
    NSMutableAttributedString *mutableBackgroundAttachmentString = [backgroundAttachmentString mutableCopy];
    // Lower the image by adjusting the baseline offset.
    [mutableBackgroundAttachmentString addAttribute:NSBaselineOffsetAttributeName value:@(-2) range:NSMakeRange(0, mutableBackgroundAttachmentString.length)];
    [result appendAttributedString:mutableBackgroundAttachmentString];

    return result;
}

- (NSImage *)imageForColor:(NSColor *)color {
    return [NSImage it_imageForColorSwatch:color size:NSMakeSize(22, 14)];
}

@end
