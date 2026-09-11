// Exercise the real key-action editor save path with an isolated menu/picker.
#import <XCTest/XCTest.h>
#import "iTermEditKeyActionWindowController.h"
#import "iTermUserDefaults.h"
#import "NSMenu+iTerm.h"

// SharedARC's generated Swift header is private to its build target. These
// selectors mirror its exported ObjC interface and invoke the real runtime class.
@protocol MenuParameterPopupTesting <NSObject>
- (void)reloadData;
- (BOOL)restoreParameter:(NSString *)parameter;
- (BOOL)selectItemWithIdentifier:(NSString *)identifier;
@end

@interface iTermEditKeyActionWindowController (MenuParameterTesting)
- (NSString *)parameterValueForAction:(KEY_ACTION)action;
@end

@interface MenuItemParameterSaveTests : XCTestCase
@property(nonatomic, strong) NSMutableArray<NSString *> *dispatchedItems;
- (void)metadataOnly:(id)sender;
- (void)recordDispatch:(NSMenuItem *)sender;
@end

@implementation MenuItemParameterSaveTests

- (void)testEditorSavePreservesRestoredParameterAndUsesExplicitNewSelection {
    if (!NSThread.isMainThread || ![[iTermUserDefaults customSuiteName] isEqualToString:@"iterm2-tests"]) {
        XCTFail(@"Editor tests require main and the isolated ModernTests suite");
        return;
    }
    NSMenu *original = NSApp.mainMenu;
    NSMenu *windows = NSApp.windowsMenu;
    NSMenu *services = NSApp.servicesMenu;
    NSMenu *main = [[NSMenu alloc] initWithTitle:@"Synthetic main"];
    main.autoenablesItems = NO;
    NSMenuItem *root = [[NSMenuItem alloc] initWithTitle:@"Synthetic view" action:nil keyEquivalent:@""];
    root.submenu = [[NSMenu alloc] initWithTitle:root.title];
    root.submenu.autoenablesItems = NO;
    [main addItem:root];
    NSString *identifier = @"Show Tabs in Fullscreen";
    NSString *displayed = [NSBundle.mainBundle localizedStringForKey:@"1257.title"
                                                             value:identifier table:@"MainMenu"];
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:displayed
                                               action:@selector(metadataOnly:) keyEquivalent:@""];
    item.target = self;
    item.identifier = identifier;
    [root.submenu addItem:item];
    NSApp.mainMenu = main;
    @try {
        Class popupClass = NSClassFromString(@"iTermMenuItemPopupView");
        XCTAssertNotNil(popupClass);
        NSView<MenuParameterPopupTesting> *popup = (id)[[popupClass alloc] initWithFrame:NSZeroRect];
        iTermEditKeyActionWindowController *editor = [[iTermEditKeyActionWindowController alloc]
            initWithContext:iTermVariablesSuggestionContextNone
            mode:iTermEditKeyActionWindowControllerModeKeyboardShortcut profileType:ProfileTypeTerminal];
        // Inject only the existing outlet; do not create unrelated windows or sessions.
        [editor setValue:popup forKey:@"menuToSelectPopup"];
        NSArray<NSString *> *parameters = @[
            identifier, @"在全屏幕中显示标签页",
            [@"Old display\n" stringByAppendingString:identifier],
            [NSString stringWithFormat:@"Old display\n%@\nopaque 用户\n", identifier],
            @"Unavailable action\nunknown.id\nopaque\n"
        ];
        for (NSString *parameter in parameters) {
            [popup restoreParameter:parameter];
            [popup reloadData];
            NSString *saved = [editor parameterValueForAction:KEY_ACTION_SELECT_MENU_ITEM];
            XCTAssertEqualObjects(saved, parameter);
            XCTAssertEqualObjects([saved dataUsingEncoding:NSUTF8StringEncoding],
                                  [parameter dataUsingEncoding:NSUTF8StringEncoding]);
        }
        XCTAssertTrue([popup selectItemWithIdentifier:identifier]);
        NSString *expected = [NSString stringWithFormat:@"%@\n%@", displayed, identifier];
        XCTAssertEqualObjects([editor parameterValueForAction:KEY_ACTION_SELECT_MENU_ITEM],
                              expected);
        XCTAssertFalse(editor.isWindowLoaded);
    } @finally {
        NSApp.mainMenu = original;
        NSApp.windowsMenu = windows;
        NSApp.servicesMenu = services;
    }
}

- (void)metadataOnly:(id)sender {
    XCTFail(@"Editor save tests must not execute menu actions");
}

- (void)recordDispatch:(NSMenuItem *)sender {
    [self.dispatchedItems addObject:sender.identifier ?: sender.title];
}

- (void)testDispatchPrefersExactTitlesAndRetainsEligibilityRules {
    if (!NSThread.isMainThread || ![[iTermUserDefaults customSuiteName] isEqualToString:@"iterm2-tests"]) {
        XCTFail(@"Dispatch tests require main and the isolated ModernTests suite");
        return;
    }
    self.dispatchedItems = [NSMutableArray array];
    NSString *identifier = @"Show Tabs in Fullscreen";
    NSString *displayed = [NSBundle.mainBundle localizedStringForKey:@"1257.title"
                                                             value:identifier table:@"MainMenu"];
    NSString *legacy = [displayed isEqualToString:identifier] ? @"在全屏幕中显示标签页" : identifier;
    NSMenu *main = [[NSMenu alloc] initWithTitle:@"Synthetic main"];
    main.autoenablesItems = NO;
    NSMenu *first = nil;
    NSMenu *second = nil;
    for (NSString *title in @[@"Synthetic first", @"Synthetic second"]) {
        NSMenuItem *root = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
        root.submenu = [[NSMenu alloc] initWithTitle:title];
        root.submenu.autoenablesItems = NO;
        [main addItem:root];
        if (!first) { first = root.submenu; } else { second = root.submenu; }
    }
    NSMenuItem *alias = [[NSMenuItem alloc] initWithTitle:displayed action:@selector(recordDispatch:) keyEquivalent:@""];
    alias.identifier = identifier;
    alias.target = self;
    [first addItem:alias];
    NSMenuItem *exact = [[NSMenuItem alloc] initWithTitle:legacy action:@selector(recordDispatch:) keyEquivalent:@""];
    exact.identifier = @"synthetic.exact";
    exact.target = self;
    [second addItem:exact];
    XCTAssertTrue([main it_selectMenuItemWithTitle:legacy identifier:nil]);
    XCTAssertEqualObjects(self.dispatchedItems, (@[@"synthetic.exact"]));
    [second removeItem:exact];
    XCTAssertTrue([main it_selectMenuItemWithTitle:legacy identifier:nil]);
    XCTAssertEqualObjects(self.dispatchedItems, (@[@"synthetic.exact", identifier]));
    XCTAssertFalse([main it_selectMenuItemWithTitle:displayed identifier:@"unknown.id"]);
    alias.enabled = NO;
    XCTAssertFalse([main it_selectMenuItemWithTitle:legacy identifier:nil]);
    alias.enabled = YES;
    alias.hidden = YES;
    XCTAssertFalse([main it_selectMenuItemWithTitle:legacy identifier:nil]);
    XCTAssertEqual(self.dispatchedItems.count, 2u);
}
@end
