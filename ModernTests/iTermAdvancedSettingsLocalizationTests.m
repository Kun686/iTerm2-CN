// Advanced settings localization changes display text, never stored setting data.
#import <XCTest/XCTest.h>
#import "iTermAdvancedSettingsModel.h"
#import "iTermAdvancedSettingsViewController.h"
#import "iTermApplicationLanguageController.h"

@interface iTermAdvancedSettingsViewController (LocalizationTesting)
+ (NSArray *)groupedSettingsArrayFromSortedArray:(NSArray *)sorted;
- (NSAttributedString *)attributedStringForGroupNamed:(NSString *)groupName;
- (NSView *)enumViewWithValue:(int)value options:(NSArray<NSString *> *)options row:(int)row;
- (NSArray *)filteredAdvancedSettings;
@end

@interface iTermAdvancedSettingsLocalizationTests : XCTestCase
@end

@implementation iTermAdvancedSettingsLocalizationTests

- (void)testEveryVisibleModelDescriptionHasMatchingEnglishAndChineseResources {
    NSBundle *english = [NSBundle bundleWithPath:[NSBundle.mainBundle pathForResource:@"en" ofType:@"lproj"]];
    NSBundle *chinese = [NSBundle bundleWithPath:[NSBundle.mainBundle pathForResource:@"zh-Hans" ofType:@"lproj"]];
    XCTAssertNotNil(english);
    XCTAssertNotNil(chinese);
    __block NSUInteger count = 0;
    [iTermAdvancedSettingsModel enumerateDictionaries:^(NSDictionary *setting) {
        NSString *description = setting[kAdvancedSettingDescription];
        NSRange separator = [description rangeOfString:@": "];
        XCTAssertNotEqual(separator.location, NSNotFound);
        if (separator.location == NSNotFound) {
            return;
        }
        NSString *group = [description substringToIndex:separator.location];
        NSString *remainder = [description substringFromIndex:NSMaxRange(separator)];
        NSString *key = [NSString stringWithFormat:@"ui.advanced.setting.%@.description", setting[kAdvancedSettingIdentifier]];
        XCTAssertEqualObjects([english localizedStringForKey:key value:@"MISSING" table:nil], remainder, @"%@", key);
        NSString *translation = [chinese localizedStringForKey:key value:@"MISSING" table:nil];
        XCTAssertNotEqualObjects(translation, @"MISSING", @"%@", key);
        XCTAssertNotEqualObjects(translation, remainder, @"%@", key);
        XCTAssertEqual([translation componentsSeparatedByString:@"\n"].count,
                       [remainder componentsSeparatedByString:@"\n"].count, @"%@", key);
        NSString *groupKey = [@"ui.advanced.group." stringByAppendingString:group];
        XCTAssertEqualObjects([english localizedStringForKey:groupKey value:@"MISSING" table:nil], group);
        XCTAssertNotEqualObjects([chinese localizedStringForKey:groupKey value:@"MISSING" table:nil], @"MISSING");
        NSArray *options = setting[kAdvancedSettingOptions];
        for (NSUInteger index = 0; index < options.count; index++) {
            NSString *optionKey = [NSString stringWithFormat:@"ui.advanced.setting.%@.option.%lu",
                                   setting[kAdvancedSettingIdentifier], (unsigned long)index];
            XCTAssertEqualObjects([english localizedStringForKey:optionKey value:@"MISSING" table:nil], options[index]);
            NSString *translatedOption = [chinese localizedStringForKey:optionKey value:@"MISSING" table:nil];
            XCTAssertNotEqualObjects(translatedOption, @"MISSING");
            XCTAssertNotEqualObjects(translatedOption, options[index]);
        }
        NSDictionary *original = [setting copy];
        NSArray *rows = [iTermAdvancedSettingsViewController groupedSettingsArrayFromSortedArray:@[ setting ]];
        XCTAssertEqualObjects(rows[0], group);
        NSMutableDictionary *expected = [setting mutableCopy];
        expected[kAdvancedSettingDescription] = [NSBundle.mainBundle localizedStringForKey:key value:remainder table:nil];
        XCTAssertEqualObjects(rows[1], expected);
        XCTAssertEqualObjects(setting, original);
        count++;
    }];
    XCTAssertGreaterThan(count, 400u);
}

- (void)testUnknownSettingFallsBackWithoutSplittingColonsInItsDescription {
    NSDictionary *setting = @{ kAdvancedSettingIdentifier: @"UntranslatedFutureSetting",
                               kAdvancedSettingDescription: @"Future group: Title: keep this colon\nDetail: keep this too",
                               kAdvancedSettingDefaultValue: @"Do not translate this value" };
    NSArray *rows = [iTermAdvancedSettingsViewController groupedSettingsArrayFromSortedArray:@[ setting ]];
    XCTAssertEqualObjects(rows[0], @"Future group");
    XCTAssertEqualObjects(rows[1][kAdvancedSettingDescription], @"Title: keep this colon\nDetail: keep this too");
    XCTAssertEqualObjects(rows[1][kAdvancedSettingDefaultValue], setting[kAdvancedSettingDefaultValue]);
}

- (void)testGroupHeadingUsesLocalizedDisplayText {
    iTermAdvancedSettingsViewController *controller = [[iTermAdvancedSettingsViewController alloc] initWithNibName:nil bundle:nil];
    NSString *localized = [NSBundle.mainBundle localizedStringForKey:@"ui.advanced.group.Badge" value:@"Badge" table:nil];
    NSString *selection = iTermApplicationLanguageController.selectedLanguageIdentifier;
    if ([selection isEqual:@"en"] || [selection isEqual:@"zh-Hans"]) {
        NSBundle *selectedBundle = [NSBundle bundleWithPath:[NSBundle.mainBundle pathForResource:selection ofType:@"lproj"]];
        XCTAssertEqualObjects(localized, [selectedBundle localizedStringForKey:@"ui.advanced.group.Badge" value:@"MISSING" table:nil],
                              @"The host must actually use the saved UI language, not the test plan's English default.");
    }
    XCTAssertEqualObjects([controller attributedStringForGroupNamed:@"Badge"].string,
                          [@"\n" stringByAppendingString:localized]);
}

- (void)testEnumTitlesAreLocalizedWithoutChangingTheirIndicesOrSourceOptions {
    iTermAdvancedSettingsViewController *controller = [[iTermAdvancedSettingsViewController alloc] initWithNibName:nil bundle:nil];
    NSArray *options = @[ @"Never", @"When a custom name is set", @"Always" ];
    NSDictionary *setting = @{ kAdvancedSettingIdentifier: @"ShowWindowNameBesideTabs", kAdvancedSettingOptions: options };
    [controller setValue:@[ setting ] forKey:@"filteredAdvancedSettings"];
    for (int selected = 0; selected < (int)options.count; selected++) {
        NSPopUpButton *button = (NSPopUpButton *)[controller enumViewWithValue:selected options:options row:0];
        XCTAssertEqual(button.indexOfSelectedItem, selected);
        XCTAssertEqual(button.numberOfItems, options.count);
        for (NSUInteger index = 0; index < options.count; index++) {
            NSString *key = [NSString stringWithFormat:@"ui.advanced.setting.ShowWindowNameBesideTabs.option.%lu", (unsigned long)index];
            XCTAssertEqualObjects([button itemTitleAtIndex:index],
                                  [NSBundle.mainBundle localizedStringForKey:key value:options[index] table:nil]);
        }
    }
    XCTAssertEqualObjects(setting[kAdvancedSettingOptions], options);
}

- (void)testSearchAcceptsLocalizedDescriptionsAndStableIdentifiers {
    NSString *localized = [NSBundle.mainBundle localizedStringForKey:@"ui.advanced.setting.BadgeFont.description"
                                                              value:@"Font to use for the badge." table:nil];
    for (NSString *query in @[ localized, @"BadgeFont", @"Font to use for the badge." ]) {
        iTermAdvancedSettingsViewController *controller = [[iTermAdvancedSettingsViewController alloc] initWithNibName:nil bundle:nil];
        NSSearchField *field = [[NSSearchField alloc] init];
        field.stringValue = query;
        [controller setValue:field forKey:@"searchField"];
        NSArray *rows = [controller filteredAdvancedSettings];
        BOOL found = NO;
        for (id row in rows) {
            if ([row isKindOfClass:[NSDictionary class]] && [row[kAdvancedSettingIdentifier] isEqual:@"BadgeFont"]) {
                found = YES;
            }
        }
        XCTAssertTrue(found, @"%@", query);
    }
}
@end
