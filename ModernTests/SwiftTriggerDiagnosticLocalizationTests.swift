import XCTest
@testable import iTerm2SharedARC

final class SwiftTriggerDiagnosticLocalizationTests: XCTestCase {
    private func check(_ trigger: Trigger, description: String,
                       file: StaticString = #filePath, line: UInt = #line) {
        let dictionary = trigger.dictionaryValue()
        let digest = trigger.digest
        XCTAssertFalse(trigger.isBrowserTrigger, file: file, line: line)
        XCTAssertTrue(trigger.allowedMatchTypes.contains(
            NSNumber(value: iTermTriggerMatchType.regex.rawValue)), file: file, line: line)
        XCTAssertEqual(trigger.description, description, file: file, line: line)
        // Foundation uses the real Swift override for PTYTriggerEvaluator's
        // %@ operand. No matcher, action, terminal IO, or emitted-log capture.
        XCTAssertEqual(String(format: "Consider %@", trigger), "Consider " + description,
                       file: file, line: line)
        XCTAssertEqual(String(format: "Trigger %@ matched string %@", trigger, "fixture"),
                       "Trigger " + description + " matched string fixture", file: file, line: line)
        XCTAssertEqual(trigger.dictionaryValue() as NSDictionary, dictionary as NSDictionary,
                       file: file, line: line)
        XCTAssertEqual(trigger.digest, digest, file: file, line: line)
    }

    func testSimpleParameterDescriptionsRetainRawDiagnostics() {
        let cases: [(Trigger, String, String)] = [
            (SGRTrigger(), "Change Style “", "”"),
            (SetNamedMarkTrigger(), "Set Named Mark to ", ""),
            (FoldTrigger(), "Fold to ", ""),
            (InjectTrigger(), "Inject Data “", "”")
        ]
        for (trigger, prefix, suffix) in cases {
            for parameter: Any? in [nil, "", NSNumber(value: 17), "synthetic-值\\1\n\\e[31m"] {
                trigger.param = parameter
                check(trigger, description: prefix + String(describing: parameter ?? "") + suffix)
            }
        }
    }

    func testUserVariableCodecAndFallbackDescriptionsStayUnchanged() {
        let trigger = SetUserVariableTrigger()
        let cases: [(Any?, String)] = [
            (nil, "Set User Variable “”"),
            (NSNumber(value: 17), "Set User Variable “17”"),
            ("", "Set User Variable “” to “”"),
            ("unseparated", "Set User Variable “” to “”"),
            (TwoParameterTriggerCodec.convert(tuple: ("synthetic", "value-值\\1")),
             "Set User Variable “synthetic” to “value-值\\1”"),
            (TwoParameterTriggerCodec.convert(tuple: ("user.invalid", "value")),
             "Set User Variable “user.invalid\u{1}value”")
        ]
        for (parameter, expected) in cases {
            trigger.param = parameter
            check(trigger, description: expected)
        }
        let encoded = TwoParameterTriggerCodec.convert(tuple: ("synthetic", "value-值\\1"))
        trigger.param = encoded
        XCTAssertEqual(trigger.paramAttributedString()?.string, "synthetic = value-值\\1")
        XCTAssertEqual(trigger.param as? String, encoded)
        XCTAssertTrue(trigger.paramIsTwoStrings())
    }

    func testBufferOptionsKeepNumericMeaningAndLocalizedMenu() throws {
        let language = try XCTUnwrap(Bundle.main.preferredLocalizations.first)
        XCTAssertTrue(["en", "zh-Hans"].contains(language))
        let chinese = language == "zh-Hans"
        let trigger = BufferInputTrigger()
        let menu = try XCTUnwrap(trigger.menuItemsForPoupupButton())
        XCTAssertEqual(menu[NSNumber(value: 0)] as? String,
                       chinese ? "开始缓冲输入" : "Start Buffering Input")
        XCTAssertEqual(menu[NSNumber(value: 1)] as? String,
                       chinese ? "停止缓冲输入" : "Stop Buffering Input")
        for parameter: Any? in [nil, NSNumber(value: 0), NSNumber(value: 1), NSNumber(value: 99), "1"] {
            trigger.param = parameter
            let shouldBuffer = (parameter as? NSNumber)?.intValue != 1
            XCTAssertEqual(trigger.shouldBuffer, shouldBuffer)
            check(trigger, description: shouldBuffer ? "Buffer Input" : "Stop Buffering Input")
            let label = chinese
                ? (shouldBuffer ? "开始缓冲" : "停止缓冲")
                : (shouldBuffer ? "Start buffering" : "Stop buffering")
            XCTAssertEqual(trigger.paramAttributedString()?.string, label)
        }
        for value in [NSNumber(value: 0), NSNumber(value: 1)] {
            let index = trigger.index(for: value)
            XCTAssertGreaterThanOrEqual(index, 0)
            if index >= 0 {
                XCTAssertEqual(trigger.object(at: index) as? NSNumber, value)
            }
        }
    }

    func testExitWorkgroupDescriptionDoesNotChangeLeaderOnlyFlag() throws {
        let trigger = ExitWorkgroupTrigger()
        XCTAssertTrue(trigger.hasLeaderOnlyOption)
        XCTAssertFalse(trigger.leaderOnly)
        for value in [true, false] {
            let configured = try XCTUnwrap(Trigger(fromUntrustedDict: [
                "action": "iTermExitWorkgroupTrigger", "regex": "synthetic",
                "eventParams": [ExitWorkgroupTrigger.leaderOnlyParamKey: NSNumber(value: value)]
            ]) as? ExitWorkgroupTrigger)
            check(configured, description: "Exit Workgroup")
            XCTAssertEqual(configured.leaderOnly, value)
        }
    }

    func testIndependentActionTitlesRemainLocalized() throws {
        let language = try XCTUnwrap(Bundle.main.preferredLocalizations.first)
        XCTAssertTrue(["en", "zh-Hans"].contains(language))
        let cases: [(Trigger.Type, String, String)] = [
            (SGRTrigger.self, "Change Style…", "更改样式…"),
            (SetNamedMarkTrigger.self, "Set Named Mark", "设置命名标记"),
            (FoldTrigger.self, "Fold to Named Mark", "折叠到命名标记"),
            (InjectTrigger.self, "Inject Data…", "注入数据…"),
            (SetUserVariableTrigger.self, "Set User Variable…", "设置用户变量…"),
            (BufferInputTrigger.self, "Buffer Input…", "缓冲输入…"),
            (ExitWorkgroupTrigger.self, "Exit Workgroup", "退出工作组")
        ]
        for (type, english, chinese) in cases {
            XCTAssertEqual(type.title, language == "zh-Hans" ? chinese : english)
        }
    }
}
