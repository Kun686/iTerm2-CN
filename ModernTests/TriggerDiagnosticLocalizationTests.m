#import <XCTest/XCTest.h>
#import "Trigger.h"
#import "HighlightTrigger.h"
#import "NSColor+iTerm.h"
#import "PasswordTrigger.h"

// Keep PasswordTrigger's real initialization/description/parameter code, but
// never read the password manager's account cache, including during init.
@interface iTermSyntheticPasswordTrigger : PasswordTrigger
@property(nonatomic) NSInteger reloadCount;
@end

@implementation iTermSyntheticPasswordTrigger
- (void)reloadData {
    self.reloadCount++;
}
@end

@interface TriggerDiagnosticLocalizationTests : XCTestCase
@end

@implementation TriggerDiagnosticLocalizationTests

// Only construct triggers and inspect their values. Never run their actions:
// no shell, RPC, alert, bell, clipboard, network, file, or Keychain operation.
- (NSArray<NSArray<NSString *> *> *)fixtures {
    return @[
        @[ @"AlertTrigger", @"Show alert “{param}”", @"Show Alert…", @"显示提醒…" ],
        @[ @"AnnotateTrigger", @"Annotate as as “{param}”", @"Annotate…", @"添加注释…" ],
        @[ @"BellTrigger", @"Ring Bell", @"Ring Bell", @"响铃" ],
        @[ @"CaptureTrigger", @"Capture output, running “{param}” on double-click", @"Capture Output", @"捕获输出" ],
        @[ @"CoprocessTrigger", @"Run Coprocess “{param}”", @"Run Coprocess…", @"运行协进程…" ],
        @[ @"ScriptTrigger", @"Run Command “{param}”", @"Run Command…", @"运行命令…" ],
        @[ @"SendTextTrigger", @"Send text “{param}”", @"Send Text…", @"发送文本…" ],
        @[ @"SetDirectoryTrigger", @"Report Directory as “{param}”", @"Report Directory", @"报告目录" ],
        @[ @"SetHostnameTrigger", @"Report User & Host as “{param}”", @"Report User & Host", @"报告用户和主机" ],
        @[ @"iTermHyperlinkTrigger", @"Make Hyperlink with URL “{param}”", @"Make Hyperlink…", @"创建超链接…" ],
        @[ @"iTermRPCTrigger", @"Invoke Script Function “{param}”", @"Invoke Script Function", @"调用脚本函数" ],
        @[ @"iTermSetTitleTrigger", @"Set Title to “{param}”", @"Set Title…", @"设置标题…" ],
        @[ @"BounceTrigger", @"Bounce dock icon until focused", @"Bounce Dock Icon", @"弹跳 Dock 图标" ],
        @[ @"MarkTrigger", @"Set Mark and continue scrolling", @"Set Mark", @"设置标记" ],
        @[ @"HighlightTrigger", @"Highlight text (no color) over (no color))", @"Highlight Text…", @"高亮文本…" ],
        @[ @"iTermHighlightLineTrigger", @"Highlight Line with (no color) over (no color)", @"Highlight Line…", @"高亮整行…" ],
        @[ @"iTermSyntheticPasswordTrigger", @"Open Password Manager to “{param}”", @"Open Password Manager…", @"打开密码管理器…" ],
        @[ @"iTermUserNotificationTrigger", @"Post Notification “{param}”", @"Post Notification…", @"发送通知…" ],
        @[ @"GrowlTrigger", @"Post Notification “{param}”", @"Post Notification…", @"发送通知…" ],
    ];
}

- (Trigger *)triggerForClassName:(NSString *)className parameter:(id)parameter {
    NSMutableDictionary *dictionary = [@{
        kTriggerActionKey: className,
        kTriggerRegexKey: @"^(synthetic)$",
        kTriggerNameKey: @"合成名称",
        kTriggerPartialLineKey: @NO,
        kTriggerDisabledKey: @YES
    } mutableCopy];
    if (parameter) {
        dictionary[kTriggerParameterKey] = parameter;
    }
    Trigger *trigger = [Trigger triggerFromUntrustedDict:dictionary];
    XCTAssertNotNil(trigger, @"%@", className);
    return trigger;
}

- (void)testSharedDescriptionsKeepOriginalLogFormattingAndConfiguration {
    NSString *parameter = @"合成\\1 %@\nvalue";
    for (NSArray<NSString *> *fixture in self.fixtures) {
        Trigger *trigger = [self triggerForClassName:fixture[0] parameter:parameter];
        NSDictionary *dictionary = trigger.dictionaryValue;
        NSData *digest = trigger.digest;
        NSString *expected = [fixture[1] stringByReplacingOccurrencesOfString:@"{param}" withString:parameter];
        XCTAssertEqualObjects(trigger.description, expected, @"%@", fixture[0]);
        // Same Foundation %@ dispatch used by BOTH Trigger.reallyTryString
        // matched-trigger DLog sites. This is an operand/formatting regression,
        // not a live matcher or an emitted-log capture.
        NSString *actualLog = [NSString stringWithFormat:@"Trigger %@ matched string %@", trigger, @"synthetic"];
        NSString *expectedLog = [NSString stringWithFormat:@"Trigger %@ matched string %@", expected, @"synthetic"];
        XCTAssertEqualObjects(actualLog, expectedLog);
        XCTAssertEqualObjects(trigger.action, fixture[0]);
        XCTAssertEqualObjects(trigger.param, parameter);
        XCTAssertEqualObjects(trigger.dictionaryValue, dictionary);
        XCTAssertEqualObjects(trigger.digest, digest);
    }
}

- (void)testIndependentActionTitlesRemainLocalized {
    NSString *language = NSBundle.mainBundle.preferredLocalizations.firstObject;
    NSArray<NSString *> *languages = @[ @"en", @"zh-Hans" ];
    XCTAssertTrue([languages containsObject:language]);
    for (NSArray<NSString *> *fixture in self.fixtures) {
        Trigger *trigger = [self triggerForClassName:fixture[0] parameter:@"synthetic"];
        NSDictionary *dictionary = trigger.dictionaryValue;
        NSString *expected = fixture[[language isEqual:@"zh-Hans"] ? 3 : 2];
        XCTAssertEqualObjects([trigger.class title], expected);
        NSString *rowTitle = [expected hasSuffix:@"…"] ? [expected substringToIndex:expected.length - 1] : expected;
        XCTAssertEqualObjects(trigger.titleAttributedString.string, rowTitle);
        XCTAssertEqualObjects(trigger.dictionaryValue, dictionary);
    }
}

- (void)testSharedDescriptionKeepsNilNumericAndEmptyParameterBehavior {
    Trigger *trigger = [self triggerForClassName:@"SendTextTrigger" parameter:nil];
    XCTAssertEqualObjects(trigger.description, @"Send text “(null)”");
    trigger.param = @42;
    XCTAssertEqualObjects(trigger.description, @"Send text “42”");
    trigger.param = @"";
    XCTAssertEqualObjects(trigger.description, @"Send text “”");
    Trigger *capture = [self triggerForClassName:@"CaptureTrigger" parameter:@""];
    XCTAssertEqualObjects(capture.description, @"Capture Output");
}

- (void)assertOriginalDescription:(NSString *)expected forTrigger:(Trigger *)trigger {
    NSDictionary *configuration = trigger.dictionaryValue;
    NSData *digest = trigger.digest;
    XCTAssertEqualObjects(trigger.description, expected);
    NSString *actualLog = [NSString stringWithFormat:@"Trigger %@ matched string %@", trigger, @"synthetic"];
    NSString *expectedLog = [NSString stringWithFormat:@"Trigger %@ matched string %@", expected, @"synthetic"];
    XCTAssertEqualObjects(actualLog, expectedLog);
    XCTAssertEqualObjects(trigger.dictionaryValue, configuration);
    XCTAssertEqualObjects(trigger.digest, digest);
}

- (void)testAttentionAndMarkDescriptionsPreserveParametersAndPopupMapping {
    BOOL chinese = [NSBundle.mainBundle.preferredLocalizations.firstObject isEqual:@"zh-Hans"];
    NSArray<NSString *> *classes = @[ @"BounceTrigger", @"MarkTrigger" ];
    NSArray<NSNumber *> *parameters = @[ @0, @1, @99 ];
    for (NSString *className in classes) {
        BOOL bounce = [className isEqual:@"BounceTrigger"];
        Trigger *trigger = [self triggerForClassName:className parameter:nil];
        for (NSNumber *parameter in parameters) {
            trigger.param = parameter;
            NSString *expected = bounce
                ? (parameter.intValue == 1 ? @"Bounce dock icon once" : @"Bounce dock icon until focused")
                : (parameter.intValue == 1 ? @"Set Mark and stop scrolling" : @"Set Mark and continue scrolling");
            [self assertOriginalDescription:expected forTrigger:trigger];
            XCTAssertEqualObjects(trigger.param, parameter);
        }
        NSDictionary *menu = trigger.menuItemsForPoupupButton;
        XCTAssertEqual(menu.count, 2U);
        for (NSNumber *parameter in @[ @0, @1 ]) {
            NSInteger index = [trigger indexForObject:parameter];
            XCTAssertGreaterThanOrEqual(index, 0);
            XCTAssertEqualObjects([trigger objectAtIndex:index], parameter);
            NSString *expected = bounce
                ? (chinese ? (parameter.intValue ? @"弹跳一次" : @"持续弹跳直至激活")
                           : (parameter.intValue ? @"Bounce Once" : @"Bounce Until Activated"))
                : (chinese ? (parameter.intValue ? @"停止滚动" : @"继续滚动")
                           : (parameter.intValue ? @"Stop Scrolling" : @"Keep Scrolling"));
            XCTAssertEqualObjects(menu[parameter], expected);
        }
    }
}

- (void)testColorDescriptionsPreserveColorDataAndDisplayLabels {
    BOOL chinese = [NSBundle.mainBundle.preferredLocalizations.firstObject isEqual:@"zh-Hans"];
    NSArray<NSString *> *classes = @[ @"HighlightTrigger", @"iTermHighlightLineTrigger" ];
    NSArray<NSString *> *parameters = @[ @"{,}", @"{#ff0000,#000000}", @"{#ff0000,}", @"{,#000000}", @"{p3#ffff00000000,#000000}" ];
    for (NSString *className in classes) {
        BOOL line = [className isEqual:@"iTermHighlightLineTrigger"];
        for (NSString *parameter in parameters) {
            Trigger<iTermColorSettable> *trigger = (id)[self triggerForClassName:className parameter:parameter];
            // NSColor's unmodified diagnostic formatter preserves the active
            // color-space policy; don't force global P3 preferences in a test.
            NSString *foreground = trigger.textColor.humanReadableDescription;
            NSString *background = trigger.backgroundColor.humanReadableDescription;
            if (foreground) {
                XCTAssertTrue([foreground containsString:@"in color space"]);
            }
            if (background) {
                XCTAssertTrue([background containsString:@"in color space"]);
            }
            NSString *expected = [NSString stringWithFormat:(line ? @"Highlight Line with %@ over %@" : @"Highlight text %@ over %@"),
                                  foreground ?: @"(no color)", background ?: (line ? @"(no color)" : @"(no color))")];
            [self assertOriginalDescription:expected forTrigger:trigger];
            NSString *row = trigger.paramAttributedString.string;
            XCTAssertTrue([row hasPrefix:chinese ? @"文本：" : @"Text: "]);
            XCTAssertTrue([row containsString:chinese ? @" 背景色：" : @" Background: "]);
            XCTAssertEqualObjects(trigger.param, parameter);
        }
    }
}

- (void)testPasswordDescriptionAndSentinelWithoutReadingAccounts {
    iTermSyntheticPasswordTrigger *trigger = (id)[self triggerForClassName:@"iTermSyntheticPasswordTrigger" parameter:nil];
    XCTAssertEqual(trigger.reloadCount, 1);
    [self assertOriginalDescription:@"Open Password Manager" forTrigger:trigger];
    trigger.param = @"synthetic-account";
    [self assertOriginalDescription:@"Open Password Manager to “synthetic-account”" forTrigger:trigger];
    NSDictionary *menu = trigger.menuItemsForPoupupButton;
    NSString *sentinel = @"Open Password Manager to Unlock";
    BOOL chinese = [NSBundle.mainBundle.preferredLocalizations.firstObject isEqual:@"zh-Hans"];
    XCTAssertEqualObjects(menu[@"synthetic-account"], @"synthetic-account");
    XCTAssertEqualObjects(menu[sentinel], chinese ? @"打开密码管理器以解锁" : sentinel);
    NSInteger index = [trigger indexForObject:sentinel];
    XCTAssertGreaterThanOrEqual(index, 0);
    XCTAssertEqualObjects([trigger objectAtIndex:index], sentinel);
    trigger.param = sentinel;
    XCTAssertEqualObjects(trigger.param, @"");
    [self assertOriginalDescription:@"Open Password Manager" forTrigger:trigger];
}

@end
