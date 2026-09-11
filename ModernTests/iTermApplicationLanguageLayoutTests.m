// The preference window sizes each page from its first content container.
#import <XCTest/XCTest.h>
#import "GeneralPreferencesViewController.h"
#import "NSBundle+iTerm.h"

@interface GeneralPreferencesViewController (LanguageLayoutTesting)
- (void)updateApplicationLanguagePopup;
@end

@interface iTermApplicationLanguageLayoutTests : XCTestCase
@end

@implementation iTermApplicationLanguageLayoutTests

- (void)testLanguageRowParticipatesInPageSizingWithoutMovingExistingControls {
    GeneralPreferencesViewController *controller =
        [[GeneralPreferencesViewController alloc] initWithNibName:nil bundle:nil];
    NSTabView *tabs = [[NSTabView alloc] initWithFrame:NSMakeRect(0, 0, 775, 559)];
    NSTabViewItem *item = [[NSTabViewItem alloc] initWithIdentifier:@"settings"];
    NSView *page = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 755, 513)];
    item.view = page;
    [tabs addTabViewItem:item];
    // These frames and autoresizing masks reproduce PreferencePanel.xib's
    // Settings page: the new language row is below the original content.
    NSView *content = [[NSView alloc] initWithFrame:NSMakeRect(27, 304, 701, 216)];
    content.autoresizingMask = NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin;
    NSButton *existing = [[NSButton alloc] initWithFrame:NSMakeRect(157, 12, 215, 32)];
    existing.autoresizingMask = NSViewMaxXMargin | NSViewMinYMargin;
    [content addSubview:existing];
    [page addSubview:content];
    NSView *languageRow = [[NSView alloc] initWithFrame:NSMakeRect(27, 218, 701, 62)];
    languageRow.autoresizingMask = NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin;
    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(160, 17, 300, 25)];
    popup.autoresizingMask = NSViewMaxXMargin | NSViewMinYMargin;
    [languageRow addSubview:popup];
    [page addSubview:languageRow];
    [controller setValue:tabs forKey:@"tabView"];
    [controller setValue:popup forKey:@"applicationLanguage"];
    NSRect existingBefore = [existing convertRect:existing.bounds toView:page];
    NSRect languageBefore = [languageRow convertRect:languageRow.bounds toView:page];
    NSRect contentBefore = content.frame;

    [controller updateApplicationLanguagePopup];

    if ([NSBundle it_isCNCommunityBuild]) {
        XCTAssertEqual(page.subviews.firstObject, content);
        XCTAssertEqual(languageRow.superview, content,
                       @"Window sizing uses the first content view, so a sibling row is clipped.");
        XCTAssertTrue(NSContainsRect(content.bounds,
                                     [popup convertRect:popup.bounds toView:content]));
        XCTAssertEqualWithAccuracy(NSHeight(content.frame), 302, 0.01);
        XCTAssertEqualObjects(popup.itemArray[0].representedObject, @"zh-Hans");
        XCTAssertEqualObjects(popup.itemArray[1].representedObject, @"en");
        XCTAssertEqualObjects(popup.itemArray[2].representedObject, @"system");
    } else {
        XCTAssertEqual(languageRow.superview, page);
        XCTAssertTrue(NSEqualRects(content.frame, contentBefore));
    }
    XCTAssertTrue(NSEqualRects(existingBefore, [existing convertRect:existing.bounds toView:page]));
    XCTAssertTrue(NSEqualRects(languageBefore, [languageRow convertRect:languageRow.bounds toView:page]));

    NSRect contentAfter = content.frame;
    NSRect rowAfter = languageRow.frame;
    [controller updateApplicationLanguagePopup];
    XCTAssertTrue(NSEqualRects(content.frame, contentAfter), @"Refreshing selection must not grow the page again.");
    XCTAssertTrue(NSEqualRects(languageRow.frame, rowAfter));
}

@end
