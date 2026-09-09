// Actual installer display assembly with synthetic controls; no App or shell.
#import <Foundation/Foundation.h>
#import "iTermShellIntegrationInstaller.h"
#include <stdio.h>

static NSBundle *probeBundle;
#undef NSLocalizedStringWithDefaultValue
#define NSLocalizedStringWithDefaultValue(key, tableName, bundle, fallback, comment) \
    [probeBundle localizedStringForKey:(key) value:(fallback) table:(tableName)]
#define NSFontAttributeName @"font"
#define NSForegroundColorAttributeName @"color"
#define NSParagraphStyleAttributeName @"paragraph"

// These values exercise attributed-string assembly, not AppKit font/layout.
@interface NSFont : NSObject
+ (double)systemFontSize;
+ (id)systemFontOfSize:(double)size;
+ (id)boldSystemFontOfSize:(double)size;
@end
@implementation NSFont
+ (double)systemFontSize { return 12; }
+ (id)systemFontOfSize:(double)size { return @"regular"; }
+ (id)boldSystemFontOfSize:(double)size { return @"bold"; }
@end
@interface NSColor : NSObject
+ (id)textColor;
@end
@implementation NSColor
+ (id)textColor { return @"text"; }
@end
@interface NSMutableParagraphStyle : NSObject
@property(nonatomic) double lineSpacing;
@end
@implementation NSMutableParagraphStyle
@end
@interface NSButton : NSObject
@property(nonatomic) BOOL enabled;
@property(nonatomic) BOOL hidden;
@property(nonatomic, copy) NSString *title;
@end
@implementation NSButton
@end
@interface DisplayValue : NSObject
@property(nonatomic, copy) NSString *string;
@property(nonatomic, copy) NSAttributedString *attributedStringValue;
@end
@implementation DisplayValue
@end
@interface PreviewProvider : NSObject
@property(nonatomic, copy) NSString *preview;
@property(nonatomic) NSInteger requests;
- (NSString *)shellIntegrationInstallerNextCommandForSendShellCommands;
@end
@implementation PreviewProvider
- (NSString *)shellIntegrationInstallerNextCommandForSendShellCommands {
    self.requests++;
    return self.preview;
}
@end

#include "shell-name.inc"

@interface StepsProbe : NSObject {
    int _stage;
    BOOL _busy;
}
@property(nonatomic) iTermShellIntegrationShell shell;
@property(nonatomic) BOOL installUtilities;
@property(nonatomic, strong) DisplayValue *textField;
@property(nonatomic, strong) DisplayValue *previewTextView;
@property(nonatomic, strong) NSButton *continueButton;
@property(nonatomic, strong) NSButton *skipButton;
@property(nonatomic, strong) NSArray<NSButton *> *previewCommandButtons;
@property(nonatomic, strong) PreviewProvider *shellInstallerDelegate;
- (NSString *)waitingText;
- (void)update;
- (NSDictionary *)snapshot:(NSDictionary *)item;
@end
@implementation StepsProbe
@synthesize shell = _shell;
#include "steps-methods.inc"
- (NSDictionary *)snapshot:(NSDictionary *)item {
    _stage = [item[@"stage"] intValue];
    _busy = [item[@"busy"] boolValue];
    _shell = [item[@"shell"] unsignedIntegerValue];
    self.installUtilities = [item[@"utilities"] boolValue];
    self.textField = [[DisplayValue alloc] init];
    self.previewTextView = [[DisplayValue alloc] init];
    self.continueButton = [[NSButton alloc] init];
    self.skipButton = [[NSButton alloc] init];
    self.skipButton.enabled = YES;
    self.previewCommandButtons = @[[[NSButton alloc] init], [[NSButton alloc] init],
                                   [[NSButton alloc] init], [[NSButton alloc] init]];
    self.shellInstallerDelegate = [[PreviewProvider alloc] init];
    self.shellInstallerDelegate.preview = item[@"preview"] == NSNull.null ? nil : item[@"preview"];
    [self update];
    NSMutableArray *bold = [NSMutableArray array];
    NSAttributedString *text = self.textField.attributedStringValue;
    [text enumerateAttribute:NSFontAttributeName inRange:NSMakeRange(0, text.length) options:0
                  usingBlock:^(id value, NSRange range, BOOL *stop) {
        if ([value isEqual:@"bold"]) { [bold addObject:[text.string substringWithRange:range]]; }
    }];
    NSMutableArray *buttons = [NSMutableArray array];
    for (NSButton *button in self.previewCommandButtons) {
        [buttons addObject:@{ @"hidden": @(button.hidden), @"title": button.title }];
    }
    return @{ @"text": text.string, @"bold": bold, @"buttons": buttons,
              @"preview": self.previewTextView.string,
              @"requests": @(self.shellInstallerDelegate.requests), @"shell": @(self.shell),
              @"continue": @(self.continueButton.enabled), @"skip": @(self.skipButton.enabled) };
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3 || !(probeBundle = [NSBundle bundleWithPath:@(argv[1])])) { return 2; }
        NSData *input = [NSData dataWithContentsOfFile:@(argv[2])];
        if (!input) { return 3; }
        NSArray *cases = [NSJSONSerialization JSONObjectWithData:input options:0 error:nil];
        if (![cases isKindOfClass:NSArray.class]) { return 4; }
        NSMutableArray *rows = [NSMutableArray array];
        for (NSDictionary *item in cases) { [rows addObject:[[[StepsProbe alloc] init] snapshot:item]]; }
        NSData *data = [NSJSONSerialization dataWithJSONObject:rows options:0 error:nil];
        return data && fwrite(data.bytes, 1, data.length, stdout) == data.length ? 0 : 5;
    }
}
