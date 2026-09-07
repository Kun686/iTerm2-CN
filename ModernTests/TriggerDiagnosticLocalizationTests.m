#import <XCTest/XCTest.h>
#import "Trigger.h"

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

@end
