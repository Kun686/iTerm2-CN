// Native display and identifier lookup excerpts; synthetic geometry, no NSApp.
#import <Foundation/Foundation.h>
#include <stdio.h>

static NSBundle *probeBundle;
#undef NSLocalizedStringWithDefaultValue
#define NSLocalizedStringWithDefaultValue(key, tableName, bundle, fallback, comment) \
    [probeBundle localizedStringForKey:(key) value:(fallback) table:(tableName)]
#define NSParagraphStyleAttributeName @"paragraph"
enum { NSTextAlignmentLeft, NSTextAlignmentRight };

@interface NSTextTab : NSObject
- (instancetype)initWithTextAlignment:(NSInteger)alignment location:(CGFloat)location options:(NSDictionary *)options;
@end
@implementation NSTextTab
- (instancetype)initWithTextAlignment:(NSInteger)alignment location:(CGFloat)location options:(NSDictionary *)options {
    return [super init];
}
@end
@interface NSMutableParagraphStyle : NSObject
@property(nonatomic) NSInteger alignment;
@property(nonatomic, copy) NSArray *tabStops;
@end
@implementation NSMutableParagraphStyle
@end
@interface FakeTextField : NSObject
@property(nonatomic) NSRect frame;
@property(nonatomic, copy) NSAttributedString *attributedStringValue;
@property(nonatomic, readonly) FakeTextField *superview;
- (void)sizeToFit;
@end
@implementation FakeTextField
- (FakeTextField *)superview { return self; }
- (void)sizeToFit {}
@end

@interface iTermTipCardActionButton : NSObject {
    FakeTextField *_textField;
}
@property(nonatomic, copy) NSString *titleValue;
@property(nonatomic, copy) NSString *shortcutValue;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *shortcut;
@property(nonatomic, readonly) NSRect bounds;
- (void)updateTitle;
- (id)accessibilityValue;
- (CGFloat)retinaRound:(CGFloat)value;
- (NSString *)renderedText;
@end
@implementation iTermTipCardActionButton
@synthesize titleValue = _titleValue;
- (instancetype)init {
    self = [super init];
    if (self) {
        _textField = [[FakeTextField alloc] init];
        _textField.frame = NSMakeRect(42, 5, 200, 17);
    }
    return self;
}
- (NSRect)bounds { return NSMakeRect(0, 0, 400, 34); }
- (CGFloat)retinaRound:(CGFloat)value { return value; }
- (NSString *)renderedText { return _textField.attributedStringValue.string; }
#include "button-methods.inc"
@end

@interface ProbeCard : NSObject {
    NSArray<iTermTipCardActionButton *> *_actionButtons;
}
- (instancetype)initWithButton:(iTermTipCardActionButton *)button;
- (iTermTipCardActionButton *)actionWithTitle:(NSString *)title;
@end
@implementation ProbeCard
- (instancetype)initWithButton:(iTermTipCardActionButton *)button {
    self = [super init];
    if (self) { _actionButtons = @[button]; }
    return self;
}
#include "card-lookup.inc"
@end

// The real append method does not enter its base-replacement branch for the
// two fixture attribute dictionaries below; that unrelated operation is not run.
static NSString *const iTermReplacementBaseCharacterAttributeName = @"replacement";
@interface NSString (UnusedBaseReplacement)
- (NSString *)stringByReplacingBaseCharacterWith:(unsigned int)value;
@end
@interface NSMutableAttributedString (ProbeAppend)
- (void)iterm_appendString:(NSString *)string withAttributes:(NSDictionary *)attributes;
@end
@implementation NSMutableAttributedString (ProbeAppend)
#include "append-method.inc"
@end

static NSDictionary *footerSnapshot(NSString *body) {
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] init];
    NSDictionary *bigTextAttributes = @{ @"kind": @"body" };
    NSDictionary *signatureAttributes = @{ @"kind": @"signature" };
#include "footer-append.inc"
    return @{ @"text": attributedString.string,
              @"bodyStyle": [attributedString attribute:@"kind" atIndex:0 effectiveRange:NULL],
              @"signatureStyle": [attributedString attribute:@"kind" atIndex:attributedString.length - 1 effectiveRange:NULL] };
}
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 5 || !(probeBundle = [NSBundle bundleWithPath:@(argv[1])])) { return 2; }
        NSData *input = [NSData dataWithContentsOfFile:@(argv[2])];
        if (!input) { return 3; }
        NSArray *cases = [NSJSONSerialization JSONObjectWithData:input options:0 error:nil];
        if (![cases isKindOfClass:NSArray.class]) { return 4; }
        NSMutableArray *rows = [NSMutableArray array];
        for (id item in cases) {
            NSString *raw = item == NSNull.null ? nil : item;
            iTermTipCardActionButton *button = [[iTermTipCardActionButton alloc] init];
            button.title = raw;
            button.shortcut = @(argv[4]);
            ProbeCard *card = [[ProbeCard alloc] initWithButton:button];
            id displayed = button.accessibilityValue;
            [rows addObject:@{ @"stored": button.title ?: NSNull.null,
                               @"shortcut": button.shortcut, @"ax": displayed ?: NSNull.null,
                               @"text": button.renderedText,
                               @"rawLookup": @([card actionWithTitle:raw] == button),
                               @"displayLookup": @([card actionWithTitle:displayed] == button) }];
        }
        NSDictionary *result = @{ @"buttons": rows, @"footer": footerSnapshot(@(argv[3])) };
        NSData *data = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
        return data && fwrite(data.bytes, 1, data.length, stdout) == data.length ? 0 : 5;
    }
}
