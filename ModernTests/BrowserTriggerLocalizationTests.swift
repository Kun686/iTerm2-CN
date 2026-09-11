import XCTest
@testable import iTerm2SharedARC

final class BrowserTriggerLocalizationTests: XCTestCase {
    private func isChinese() throws -> Bool {
        let language = try XCTUnwrap(Bundle.main.preferredLocalizations.first)
        XCTAssertTrue(["en", "zh-Hans"].contains(language))
        return language == "zh-Hans"
    }

    func testBrowserPresentationDoesNotRewriteStoredData() throws {
        let chinese = try isChinese()
        let fixtures: [(Trigger, String, String, iTermTriggerMatchType)] = [
            (HighlightBrowserTrigger(), "Highlight Text", "高亮文本", .pageContentRegex),
            (ReaderModeBrowserTrigger(), "Enter Reader Mode", "进入阅读模式", .urlRegex),
            (ReloadBrowserTrigger(), "Reload After Delay", "延迟后重新加载", .urlRegex),
            (ExitWorkgroupBrowserTrigger(), "Exit Workgroup", "退出工作组", .urlRegex),
            (InjectJavascriptURLTrigger(), "Inject Javascript (URL Regex)",
             "注入 JavaScript（URL 正则表达式）", .urlRegex),
            (InjectJavascriptContentTrigger(), "Inject Javascript (Content Regex)",
             "注入 JavaScript（内容正则表达式）", .pageContentRegex),
            (HyperlinkBrowserTrigger(), "Make Hyperlink…", "创建超链接…", .pageContentRegex)
        ]
        for (seed, english, translation, matchType) in fixtures {
            for parameter: Any? in [nil, "", NSNumber(value: 17), "synthetic-值\\1"] {
                var input = seed.dictionaryValue()
                input[kTriggerContentRegexKey] = "synthetic-(content)"
                let trigger = try XCTUnwrap(Trigger(fromUntrustedDict: input))
                trigger.param = parameter
                trigger.regex = "^synthetic-url$"
                let dictionary = trigger.dictionaryValue()
                let digest = trigger.digest
                XCTAssertTrue(trigger.isBrowserTrigger)
                XCTAssertEqual(trigger.matchType, matchType)
                XCTAssertEqual(trigger.allowedMatchTypes, [NSNumber(value: matchType.rawValue)])
                XCTAssertEqual(type(of: trigger).title, chinese ? translation : english)
                let expected: String
                if trigger is HyperlinkBrowserTrigger {
                    let label = parameter as? String ?? (chinese ? "（无）" : "(nil)")
                    expected = chinese ? "创建 URL 为“\(label)”的超链接" : "Make Hyperlink with URL “\(label)”"
                } else {
                    // Preserve the upstream English description's extra closing
                    // parenthesis; its independent action title has none.
                    expected = chinese ? translation : english + (trigger is ReloadBrowserTrigger ? ")" : "")
                }
                XCTAssertEqual(trigger.description, expected)
                XCTAssertEqual(trigger.dictionaryValue() as NSDictionary, dictionary as NSDictionary)
                XCTAssertEqual(trigger.digest, digest)
                let decoded = try XCTUnwrap(Trigger(fromUntrustedDict: dictionary))
                XCTAssertEqual(decoded.dictionaryValue() as NSDictionary, dictionary as NSDictionary)
                XCTAssertEqual(decoded.digest, digest)
            }
        }
    }

    func testBrowserDefaultsRemainRawParameters() {
        let hyperlink = HyperlinkBrowserTrigger()
        for interpolation in [false, true] {
            let expected = interpolation ? "https://\\(match0)" : "https://\\0"
            XCTAssertEqual(hyperlink.triggerOptionalDefaultParameterValue(withInterpolation: interpolation), expected)
            XCTAssertEqual(hyperlink.triggerOptionalParameterPlaceholder(withInterpolation: interpolation), expected)
            XCTAssertEqual(ReloadBrowserTrigger().triggerOptionalDefaultParameterValue(withInterpolation: interpolation), "60")
            for trigger in [InjectJavascriptURLTrigger(), InjectJavascriptContentTrigger()] as [Trigger] {
                XCTAssertEqual(trigger.triggerOptionalDefaultParameterValue(withInterpolation: interpolation),
                               "console.log('Testing');")
            }
        }
    }

    @MainActor
    func testColorParameterRowPreservesEncoding() throws {
        let chinese = try isChinese()
        let trigger = HighlightBrowserTrigger()
        for parameter in ["", ";", "#ff0000;", ";#0000ff", "#ff0000;#0000ff"] {
            trigger.param = parameter
            let dictionary = trigger.dictionaryValue()
            let digest = trigger.digest
            let components = parameter.components(separatedBy: ";")
            XCTAssertEqual(trigger.colors.0, components.count >= 2 ? components[0] : "")
            XCTAssertEqual(trigger.colors.1, components.count >= 2 ? components[1] : "")
            let expected = chinese ? "文本：\u{fffc} 背景：\u{fffc}" : "Text: \u{fffc} Background: \u{fffc}"
            XCTAssertEqual(trigger.paramAttributedString().string, expected)
            XCTAssertEqual(trigger.param as? String, parameter)
            XCTAssertEqual(trigger.dictionaryValue() as NSDictionary, dictionary as NSDictionary)
            XCTAssertEqual(trigger.digest, digest)
        }
    }

    func testTerminalEvaluatorExcludesBrowserTriggersAcrossReloads() throws {
        // Instantiate only: no browser client, workgroup-model access, matcher,
        // callback, terminal session, or action execution. In particular, do not
        // request the workgroup-entry description, which reads its model.
        let browsers: [Trigger] = [HyperlinkBrowserTrigger(), HighlightBrowserTrigger(),
                                   ReaderModeBrowserTrigger(), ReloadBrowserTrigger(),
                                   ExitWorkgroupBrowserTrigger(), EnterWorkgroupBrowserTrigger(),
                                   InjectJavascriptURLTrigger(), InjectJavascriptContentTrigger()]
        let browserDictionaries = browsers.map { trigger in
            trigger.regex = "synthetic-url"
            trigger.param = "synthetic-parameter"
            return trigger.dictionaryValue()
        }
        let terminal = SGRTrigger()
        terminal.regex = "synthetic-terminal"
        terminal.param = "31"
        let terminalDictionary = terminal.dictionaryValue()
        let evaluator = PTYTriggerEvaluator(queue: DispatchQueue(label: "browser-localization-test"))
        evaluator.disableExecution = true
        evaluator.load(fromProfileArray: browserDictionaries)
        XCTAssertTrue(evaluator.triggers.isEmpty)
        let mixed = browserDictionaries + [terminalDictionary] + browserDictionaries
        evaluator.load(fromProfileArray: mixed)
        XCTAssertEqual(evaluator.triggers.count, 1)
        let retained = try XCTUnwrap(evaluator.triggers.first)
        XCTAssertTrue(retained is SGRTrigger)
        XCTAssertEqual(retained.dictionaryValue() as NSDictionary, terminalDictionary as NSDictionary)
        evaluator.load(fromProfileArray: Array(mixed.reversed()))
        XCTAssertEqual(evaluator.triggers.count, 1)
        XCTAssertTrue(evaluator.triggers.first === retained)
        XCTAssertFalse(retained.isBrowserTrigger)
        XCTAssertEqual(retained.dictionaryValue() as NSDictionary, terminalDictionary as NSDictionary)
        XCTAssertEqual(browsers.map { $0.dictionaryValue() } as NSArray, browserDictionaries as NSArray)
        XCTAssertNil(evaluator.delegate)
        XCTAssertNil(evaluator.dataSource)
        evaluator.load(fromProfileArray: [])
        XCTAssertTrue(evaluator.triggers.isEmpty)
    }
}
