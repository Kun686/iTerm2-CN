#import <XCTest/XCTest.h>
#import "iTermKeyBindingAction.h"
#import "iTermKeyMappings.h"
#import "iTermKeystroke.h"
#import "iTermUserDefaults.h"
#import "iTermWarning.h"
#import "NSMenu+iTerm.h"

// The static library's generated Swift header is not exported to this ObjC
// target. Declare its existing public @objc entry point, not a test-only hook.
@interface iTermUndoCloseShortcutChangeWarning : NSObject
+ (void)maybeShowForTriggeringEvent:(NSEvent * _Nullable)event wasFullScreen:(BOOL)wasFullScreen;
@end

@interface iTermSyntheticShortcutWarningHandler : NSObject<iTermWarningHandler>
@property(nonatomic) NSModalResponse response;
@property(nonatomic) NSUInteger calls;
@property(nonatomic, strong) NSAlert *alert;
@property(nonatomic, copy) void (^completion)(void);
@end

@implementation iTermSyntheticShortcutWarningHandler
- (NSModalResponse)warningWouldShowAlert:(NSAlert *)alert identifier:(NSString *)identifier {
    self.alert = alert;
    self.calls++;
    // Complete on the next main-queue turn, after runModal has invoked the
    // selected real action block and its synchronous key-map write has finished.
    dispatch_async(dispatch_get_main_queue(), self.completion);
    return self.response;
}
@end

@interface UndoCloseShortcutLocalizationTests : XCTestCase
@property(nonatomic) NSUInteger syntheticMenuSelections;
@end

@implementation UndoCloseShortcutLocalizationTests

- (void)drainQueuedPreferenceObservers {
    XCTestExpectation *done = [self expectationWithDescription:@"queued preference observers"];
    dispatch_async(dispatch_get_main_queue(), ^{ [done fulfill]; });
    [self waitForExpectations:@[done] timeout:5];
}

- (void)selectSyntheticMenuItem:(id)sender {
    self.syntheticMenuSelections++;
}

- (void)checkWarningWithResponse:(NSModalResponse)response restoresBinding:(BOOL)restoresBinding {
    // Check before reading defaults or initializing the global-key-map cache.
    if (![NSThread isMainThread] ||
        ![[iTermUserDefaults customSuiteName] isEqualToString:@"iterm2-tests"]) {
        XCTFail(@"Shortcut fixtures require main and the isolated ModernTests suite");
        return;
    }
    NSUserDefaults *defaults = [iTermUserDefaults userDefaults];
    NSArray<NSString *> *keys = @[@"GlobalKeyMap", @"NoSyncHaveWarnedAboutUndoCloseShortcutChange"];
    NSMutableDictionary *saved = [NSMutableDictionary dictionary];
    for (NSString *key in keys) {
        saved[key] = [defaults objectForKey:key];
    }
    NSDictionary *originalMap = [iTermKeyMappings globalKeyMap];
    id<iTermWarningHandler> originalHandler = [iTermWarning warningHandler];
    iTermSyntheticShortcutWarningHandler *handler = [[iTermSyntheticShortcutWarningHandler alloc] init];
    handler.response = response;
    XCTestExpectation *handled = [self expectationWithDescription:@"shortcut warning action completed"];
    handler.completion = ^{ [handled fulfill]; };

    [iTermKeyMappings suppressNotifications:^{
        @try {
            [iTermWarning setWarningHandler:handler];
            [iTermKeyMappings setGlobalKeyMap:@{}];
            iTermUserDefaults.haveWarnedAboutUndoCloseShortcutChange = NO;
            [self drainQueuedPreferenceObservers];
            NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown
                                             location:NSZeroPoint
                                        modifierFlags:NSEventModifierFlagCommand | NSEventModifierFlagShift
                                            timestamp:0
                                         windowNumber:0
                                              context:nil
                                           characters:@"T"
                          charactersIgnoringModifiers:@"T"
                                            isARepeat:NO
                                              keyCode:17];
            XCTAssertNotNil(event);
            // This calls the real notice and private persistence callback. The
            // existing handler prevents presentation; no event is posted and no
            // real full-screen window, session, or keyboard setting is used.
            [iTermUndoCloseShortcutChangeWarning maybeShowForTriggeringEvent:event wasFullScreen:YES];
            [self waitForExpectations:@[handled] timeout:5];
            XCTAssertEqual(handler.calls, 1u);
            XCTAssertTrue(iTermUserDefaults.haveWarnedAboutUndoCloseShortcutChange);
            BOOL chinese = [NSBundle.mainBundle.preferredLocalizations.firstObject isEqualToString:@"zh-Hans"];
            XCTAssertEqualObjects(handler.alert.messageText, chinese ? @"键盘快捷键已更改" : @"Keyboard Shortcut Changed");
            XCTAssertEqualObjects(handler.alert.buttons[0].title, chinese ? @"保留新快捷键" : @"Keep New Shortcut");
            XCTAssertEqualObjects(handler.alert.buttons[1].title, chinese ? @"恢复 ⌘⇧T 以显示标签页" : @"Restore ⌘⇧T to Show Tabs");
            NSDictionary *map = [iTermKeyMappings globalKeyMap];
            if (restoresBinding) {
                NSString *serialized = [iTermKeystroke withEvent:event].serialized;
                XCTAssertEqual(map.count, 1u);
                iTermKeyBindingAction *action = [iTermKeyBindingAction withDictionary:map[serialized]];
                XCTAssertNotNil(action);
                NSString *originalParameter = @"Show Tabs in Fullscreen\nShow Tabs in Fullscreen";
                XCTAssertEqualObjects(action.parameter, originalParameter);
                XCTAssertEqual(action.keyAction, KEY_ACTION_SELECT_MENU_ITEM);
                XCTAssertEqual(action.escaping, iTermSendTextEscapingNone);
                XCTAssertEqual(action.applyMode, iTermActionApplyModeCurrentSession);
                XCTAssertTrue([[defaults objectForKey:@"GlobalKeyMap"] isEqual:map]);

                // The existing resolver can find a localized menu by stable ID
                // with the ORIGINAL stored parameter; only a synthetic target runs.
                NSMenu *menu = [[NSMenu alloc] initWithTitle:@"synthetic-menu"];
                menu.autoenablesItems = NO;
                NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"全屏时显示标签页"
                                                                           action:@selector(selectSyntheticMenuItem:)
                                                                    keyEquivalent:@""];
                item.identifier = @"Show Tabs in Fullscreen";
                item.target = self;
                [menu addItem:item];
                self.syntheticMenuSelections = 0;
                XCTAssertTrue([menu it_selectMenuItemWithTitle:@"Show Tabs in Fullscreen"
                                                    identifier:@"Show Tabs in Fullscreen"]);
                XCTAssertEqual(self.syntheticMenuSelections, 1u);
            } else {
                XCTAssertEqual(map.count, 0u);
            }
            [iTermUndoCloseShortcutChangeWarning maybeShowForTriggeringEvent:event wasFullScreen:YES];
            [self drainQueuedPreferenceObservers];
            XCTAssertEqual(handler.calls, 1u);
        } @finally {
            [iTermKeyMappings setGlobalKeyMap:originalMap];
            for (NSString *key in keys) {
                [defaults setObject:saved[key] forKey:key];
            }
            [self drainQueuedPreferenceObservers];
            [iTermWarning setWarningHandler:originalHandler];
            for (NSString *key in keys) {
                id actual = [defaults objectForKey:key];
                XCTAssertTrue(actual == saved[key] || [actual isEqual:saved[key]], @"Isolated preference not restored");
            }
            XCTAssertTrue([[iTermKeyMappings globalKeyMap] isEqual:originalMap], @"Key-map cache not restored");
            XCTAssertTrue([iTermWarning warningHandler] == originalHandler);
        }
    }];
}

- (void)testRestoreShortcutKeepsOriginalSerializedParameter {
    [self checkWarningWithResponse:NSAlertSecondButtonReturn restoresBinding:YES];
}

- (void)testKeepShortcutDoesNotCreateBinding {
    [self checkWarningWithResponse:NSAlertFirstButtonReturn restoresBinding:NO];
}
@end
