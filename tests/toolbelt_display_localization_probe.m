// Native menu/state and KVO display-boundary probe with isolated fake storage.
#import <AppKit/AppKit.h>
#include <stdio.h>

static NSBundle *probeBundle;
#undef NSLocalizedStringWithDefaultValue
#define NSLocalizedStringWithDefaultValue(key, tableName, bundle, defaultValue, comment) \
    [probeBundle localizedStringForKey:(key) value:(defaultValue) table:(tableName)]

typedef NSInteger ProfileType;
@interface SyntheticTool : NSObject
+ (ProfileType)supportedProfileTypes;
@end
@implementation SyntheticTool
+ (ProfileType)supportedProfileTypes { return 3; }
@end
@interface ToolWebView : SyntheticTool
@end
@implementation ToolWebView
+ (ProfileType)supportedProfileTypes { return 1; }
@end

@interface iTermUserDefaults : NSObject
+ (NSMutableDictionary *)userDefaults;
@end
@implementation iTermUserDefaults
+ (NSMutableDictionary *)userDefaults {
    static NSMutableDictionary *storage;
    if (!storage) { storage = [NSMutableDictionary dictionary]; }
    return storage;
}
@end

#include "toolbelt-constants.inc"
static NSMutableDictionary<NSString *, Class> *gRegisteredTools;
static NSString *kToolbeltPrefKey = @"ToolbeltTools";

@interface iTermToolbeltView : NSObject
+ (NSArray<NSString *> *)allTools;
+ (NSArray *)configuredTools;
+ (NSArray *)defaultTools;
+ (void)populateMenu:(NSMenu *)menu;
+ (void)addToolsToMenu:(NSMenu *)menu;
+ (void)toggleShouldShowTool:(NSString *)theName;
#include "toolbelt-display-declaration.inc"
@end
@implementation iTermToolbeltView
#include "toolbelt-methods.inc"
@end

@interface MenuDelegate : NSObject {
@public
    NSMenu *toolbeltMenu;
    NSString *lastNotification;
}
- (IBAction)toggleToolbeltTool:(NSMenuItem *)menuItem;
- (void)observeToggle:(NSNotification *)notification;
@end
@implementation MenuDelegate
#include "toolbelt-action.inc"
- (void)observeToggle:(NSNotification *)notification {
    NSString *theName = notification.object;
    lastNotification = theName;
#include "toolbelt-notification.inc"
}
@end

static const CGFloat kCloseButtonLeftMargin = 2, kButtonSize = 17, kRightMargin = 4, kTitleHeight = 19;
@interface WrapperProbe : NSView {
    NSString *_name;
    NSTextField *_title;
    BOOL _updated;
}
@property(nonatomic, copy) NSString *name;
- (void)setTitleEditable;
- (NSDictionary *)snapshotForName:(NSString *)name;
@end
@implementation WrapperProbe
@synthesize name = _name;
- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
#include "toolbelt-wrapper-init.inc"
    }
    return self;
}
#include "toolbelt-wrapper-methods.inc"
- (NSDictionary *)snapshotForName:(NSString *)name {
    _updated = NO;
    self.name = name;
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2];
    while (!_updated && deadline.timeIntervalSinceNow > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:deadline];
    }
    return @{@"raw": name, @"stored": self.name, @"displayed": _title.stringValue,
             @"updated": @(_updated), @"editable": @(_title.editable)};
}
- (void)dealloc {
    [_title unbind:@"value"];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}
@end

static NSArray *builtInNames(void) {
#include "toolbelt-names.inc"
}
static NSString *displayed(NSMenuItem *item) {
    return item.attributedTitle.string ?: item.title;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2 || !(probeBundle = [NSBundle bundleWithPath:@(argv[1])])) { return 2; }
        gRegisteredTools = [NSMutableDictionary dictionary];
        for (NSString *name in builtInNames()) { gRegisteredTools[name] = [SyntheticTool class]; }
        gRegisteredTools[@"User 工具 %@"] = [ToolWebView class];
        MenuDelegate *delegate = [[MenuDelegate alloc] init];
        delegate->toolbeltMenu = [[NSMenu alloc] initWithTitle:@"Synthetic"];
        [delegate->toolbeltMenu addItemWithTitle:@"Synthetic header" action:nil keyEquivalent:@""];
        [[NSNotificationCenter defaultCenter] addObserver:delegate selector:@selector(observeToggle:)
                                                     name:@"iTermToolToggled" object:nil];
        [iTermToolbeltView populateMenu:delegate->toolbeltMenu];
        [iTermToolbeltView populateMenu:delegate->toolbeltMenu];
        NSMutableArray *rows = [NSMutableArray array];
        for (NSMenuItem *item in delegate->toolbeltMenu.itemArray) {
            if (item.action != @selector(toggleToolbeltTool:)) { continue; }
            NSString *raw = item.title;
            const BOOL initiallyConfigured = [[iTermToolbeltView configuredTools] containsObject:raw];
            [delegate toggleToolbeltTool:item];
            NSMutableDictionary *row = [@{@"raw": raw, @"displayed": displayed(item),
                @"axTitle": item.accessibilityTitle ?: item.title, @"identifier": item.identifier,
                @"tag": @(item.tag), @"action": NSStringFromSelector(item.action),
                @"keyEquivalent": item.keyEquivalent, @"notification": delegate->lastNotification,
                @"configuredAfter": @([[iTermToolbeltView configuredTools] containsObject:raw] != initiallyConfigured),
                @"stateAfter": @((item.state == NSControlStateValueOn) != initiallyConfigured)} mutableCopy];
            [delegate toggleToolbeltTool:item];
            row[@"restored"] = @([[iTermToolbeltView configuredTools] containsObject:raw] == initiallyConfigured &&
                                  (item.state == NSControlStateValueOn) == initiallyConfigured);
            [rows addObject:row];
        }
        WrapperProbe *wrapper = [[WrapperProbe alloc] initWithFrame:NSMakeRect(0, 0, 250, 100)];
        NSMutableArray *wrappers = [NSMutableArray array];
        for (NSString *name in [[iTermToolbeltView allTools] sortedArrayUsingSelector:@selector(compare:)]) {
            [wrappers addObject:[wrapper snapshotForName:name]];
        }
        [wrappers addObject:[wrapper snapshotForName:@"Unregistered 用户"]];
        gRegisteredTools[kNotesToolName] = [ToolWebView class];
        [iTermToolbeltView populateMenu:delegate->toolbeltMenu];
        NSDictionary *result = @{@"rows": rows, @"wrappers": wrappers,
            @"menuCount": @(delegate->toolbeltMenu.numberOfItems),
            @"header": [delegate->toolbeltMenu itemAtIndex:0].title,
            @"registryNames": [[iTermToolbeltView allTools] sortedArrayUsingSelector:@selector(compare:)],
            @"dynamicNotes": displayed([delegate->toolbeltMenu itemWithTitle:kNotesToolName]),
            @"dynamicWrapper": [wrapper snapshotForName:kNotesToolName][@"displayed"]};
        [[NSNotificationCenter defaultCenter] removeObserver:delegate];
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:result options:0 error:&error];
        NSString *json = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        return json && !error && puts(json.UTF8String) >= 0 ? 0 : 3;
    }
}
