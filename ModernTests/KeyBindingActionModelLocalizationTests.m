#import <XCTest/XCTest.h>
#import "iTermActionsModel.h"

// iTermAction's existing ObjC API is not exported by the Swift module. Test it
// directly without adding a production bridge or changing target settings.
@interface KeyBindingActionModelLocalizationTests : XCTestCase
@end

@implementation KeyBindingActionModelLocalizationTests
- (void)testUnboundActionDisplayDoesNotBecomeStoredTitle {
    NSString *language = NSBundle.mainBundle.preferredLocalizations.firstObject;
    NSArray<NSString *> *supportedLanguages = @[@"en", @"zh-Hans"];
    XCTAssertTrue([supportedLanguages containsObject:language]);
    BOOL chinese = [language isEqualToString:@"zh-Hans"];
    for (NSString *title in @[@"", @"user-标题"]) {
        NSDictionary *input = @{
            @"action": @13, @"title": title, @"parameter": @"synthetic-值",
            @"version": @2, @"escaping": @0, @"applyMode": @0
        };
        // Construct the value only, not iTermActionsModel/shared preferences.
        iTermAction *action = [[iTermAction alloc] initWithDictionary:input];
        XCTAssertEqualObjects(action.displayString, chinese ? @"忽略" : @"Ignore");
        XCTAssertEqualObjects(action.title, title);
        XCTAssertEqualObjects(action.parameter, @"synthetic-值");
        XCTAssertEqualObjects(action.dictionaryValue, input);
    }
}
@end
