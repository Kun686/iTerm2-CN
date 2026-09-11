//
//  iTermCursorBlinkFadePreset.m
//  iTerm2
//

#import "iTermCursorBlinkFadePreset.h"

@implementation iTermCursorBlinkFadePreset

- (instancetype)initWithName:(NSString *)name
              fadeInDuration:(NSTimeInterval)fadeInDuration
             fadeOutDuration:(NSTimeInterval)fadeOutDuration
                 fadeInCurve:(iTermCursorBlinkFadeCurve)fadeInCurve
                fadeOutCurve:(iTermCursorBlinkFadeCurve)fadeOutCurve
                visibleDwell:(NSTimeInterval)visibleDwell
                 hiddenDwell:(NSTimeInterval)hiddenDwell {
    self = [super init];
    if (self) {
        _name = [name copy];
        _fadeInDuration = fadeInDuration;
        _fadeOutDuration = fadeOutDuration;
        _fadeInCurve = fadeInCurve;
        _fadeOutCurve = fadeOutCurve;
        _visibleDwell = visibleDwell;
        _hiddenDwell = hiddenDwell;
    }
    return self;
}

+ (NSArray<iTermCursorBlinkFadePreset *> *)presets {
    static NSArray<iTermCursorBlinkFadePreset *> *presets;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        presets = @[
            // Slow, meditative, symmetric breath.
            [[iTermCursorBlinkFadePreset alloc] initWithName:NSLocalizedStringWithDefaultValue(@"ui.settings.itermcursorblinkfadepreset.breathing.762c550a", nil, NSBundle.mainBundle, @"Breathing", @"Cursor blink fade preset name.")
                                              fadeInDuration:0.9
                                             fadeOutDuration:0.9
                                                 fadeInCurve:iTermCursorBlinkFadeCurveEaseInOut
                                                fadeOutCurve:iTermCursorBlinkFadeCurveEaseInOut
                                                visibleDwell:0.5
                                                 hiddenDwell:0.5],
            // Neutral, constant-rate fade.
            [[iTermCursorBlinkFadePreset alloc] initWithName:NSLocalizedStringWithDefaultValue(@"ui.settings.itermcursorblinkfadepreset.linear.e6950b45", nil, NSBundle.mainBundle, @"Linear", @"Cursor blink fade preset name.")
                                              fadeInDuration:0.4
                                             fadeOutDuration:0.4
                                                 fadeInCurve:iTermCursorBlinkFadeCurveLinear
                                                fadeOutCurve:iTermCursorBlinkFadeCurveLinear
                                                visibleDwell:0.7
                                                 hiddenDwell:0.5],
            // Quick but still smooth.
            [[iTermCursorBlinkFadePreset alloc] initWithName:NSLocalizedStringWithDefaultValue(@"ui.settings.itermcursorblinkfadepreset.fast.6c582b62", nil, NSBundle.mainBundle, @"Fast", @"Cursor blink fade preset name.")
                                              fadeInDuration:0.2
                                             fadeOutDuration:0.2
                                                 fadeInCurve:iTermCursorBlinkFadeCurveEaseInOut
                                                fadeOutCurve:iTermCursorBlinkFadeCurveEaseInOut
                                                visibleDwell:0.7
                                                 hiddenDwell:0.2],
            // Slow, with a longer fade-out than fade-in.
            [[iTermCursorBlinkFadePreset alloc] initWithName:NSLocalizedStringWithDefaultValue(@"ui.settings.itermcursorblinkfadepreset.slow.4b2bebbf", nil, NSBundle.mainBundle, @"Slow", @"Cursor blink fade preset name.")
                                              fadeInDuration:0.5
                                             fadeOutDuration:0.75
                                                 fadeInCurve:iTermCursorBlinkFadeCurveEaseInOut
                                                fadeOutCurve:iTermCursorBlinkFadeCurveEaseInOut
                                                visibleDwell:1.0
                                                 hiddenDwell:0.2],
            // Mostly solid with a brief, soft dip.
            [[iTermCursorBlinkFadePreset alloc] initWithName:NSLocalizedStringWithDefaultValue(@"ui.settings.itermcursorblinkfadepreset.subtle.3eadecfb", nil, NSBundle.mainBundle, @"Subtle", @"Cursor blink fade preset name.")
                                              fadeInDuration:0.15
                                             fadeOutDuration:0.15
                                                 fadeInCurve:iTermCursorBlinkFadeCurveEaseInOut
                                                fadeOutCurve:iTermCursorBlinkFadeCurveEaseInOut
                                                visibleDwell:0.9
                                                 hiddenDwell:0.2],
        ];
    });
    return presets;
}

+ (iTermCursorBlinkFadePreset *)presetWithTag:(NSInteger)tag {
    NSArray<iTermCursorBlinkFadePreset *> *presets = [self presets];
    if (tag < 0 || tag >= (NSInteger)presets.count) {
        return nil;
    }
    return presets[tag];
}

- (BOOL)matchesFadeInDuration:(NSTimeInterval)fadeInDuration
             fadeOutDuration:(NSTimeInterval)fadeOutDuration
                 fadeInCurve:(iTermCursorBlinkFadeCurve)fadeInCurve
                fadeOutCurve:(iTermCursorBlinkFadeCurve)fadeOutCurve
                visibleDwell:(NSTimeInterval)visibleDwell
                 hiddenDwell:(NSTimeInterval)hiddenDwell {
    const NSTimeInterval tolerance = 0.001;
    return (fabs(_fadeInDuration - fadeInDuration) < tolerance &&
            fabs(_fadeOutDuration - fadeOutDuration) < tolerance &&
            _fadeInCurve == fadeInCurve &&
            _fadeOutCurve == fadeOutCurve &&
            fabs(_visibleDwell - visibleDwell) < tolerance &&
            fabs(_hiddenDwell - hiddenDwell) < tolerance);
}

@end
