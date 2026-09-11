import XCTest
@testable import iTerm2SharedARC

final class KeyBindingLocalizationTests: XCTestCase {
    private func isChinese() throws -> Bool {
        let language = try XCTUnwrap(Bundle.main.preferredLocalizations.first)
        XCTAssertTrue(["en", "zh-Hans"].contains(language))
        return language == "zh-Hans"
    }

    private func checkRoundTrip(_ action: iTermKeyBindingAction,
                               expected: [AnyHashable: Any]) throws {
        XCTAssertEqual(action.dictionaryValue as NSDictionary, expected as NSDictionary)
        let encoded = try XCTUnwrap(action.stringValue)
        let data = try XCTUnwrap(Data(base64Encoded: encoded))
        XCTAssertEqual(try JSONSerialization.jsonObject(with: data) as? NSDictionary,
                       expected as NSDictionary)
        let restored = try XCTUnwrap(iTermKeyBindingAction.fromString(encoded))
        XCTAssertEqual(restored.dictionaryValue as NSDictionary, expected as NSDictionary)
        XCTAssertEqual(restored.keyAction, action.keyAction)
        XCTAssertEqual(restored.parameter, action.parameter)
        XCTAssertEqual(restored.label, action.label)
        XCTAssertEqual(restored.escaping, action.escaping)
        XCTAssertEqual(restored.applyMode, action.applyMode)
        XCTAssertEqual(restored.sendsText, action.sendsText)
        XCTAssertEqual(restored.isActionable, action.isActionable)
    }

    func testLocalizedActionNamesPreserveRawParametersAndLabels() throws {
        let chinese = try isChinese()
        let fixtures: [(KEY_ACTION, String, String, Bool)] = [
            (.ACTION_ESCAPE_SEQUENCE, "Send ^[ %@", "发送 ^[ %@", true),
            (.ACTION_HEX_CODE, "Send Hex Codes: %@", "发送十六进制代码：%@", true),
            (.ACTION_TEXT, "Send: \"%@\"", "发送：“%@”", true),
            (.ACTION_VIM_TEXT, "Send: \"%@\"", "发送：“%@”", true),
            (.ACTION_VIM_TEXT_NO_BROADCAST, "Send (no broadcast): \"%@\"", "发送（不广播）：“%@”", true),
            (.ACTION_SELECT_MENU_ITEM, "Select Menu Item “%@”", "选择菜单项“%@”", false)
        ]
        // Only in-memory objects: never resolve a real profile/snippet or execute
        // a terminal, browser, menu, or coprocess action.
        for (keyAction, english, translation, sendsText) in fixtures {
            for parameter in ["", "0x1b 0x5b 0x41", #"synthetic-值\n\e\1"#] {
                let action = try XCTUnwrap(iTermKeyBindingAction.withAction(
                    keyAction, parameter: parameter, label: "user-标签",
                    escaping: .none, applyMode: .currentSession))
                let expected: [AnyHashable: Any] = [
                    "Action": keyAction.rawValue, "Text": parameter, "Label": "user-标签",
                    "Version": 2, "Escaping": 0, "Apply Mode": 0
                ]
                XCTAssertEqual(action.displayName, String(format: chinese ? translation : english, parameter))
                XCTAssertEqual(action.parameter, parameter)
                XCTAssertEqual(action.label, "user-标签")
                XCTAssertEqual(action.sendsText, sendsText)
                XCTAssertTrue(action.isActionable)
                try checkRoundTrip(action, expected: expected)
            }
        }
        let parameter = "Show Tabs in Fullscreen\nShow Tabs in Fullscreen"
        let menu = try XCTUnwrap(iTermKeyBindingAction.withAction(
            .ACTION_SELECT_MENU_ITEM, parameter: parameter, escaping: .none, applyMode: .currentSession))
        let original = menu.dictionaryValue
        XCTAssertEqual(menu.displayName, chinese ? "选择菜单项“Show Tabs in Fullscreen”" :
                       "Select Menu Item “Show Tabs in Fullscreen”")
        try checkRoundTrip(menu, expected: original)
    }

    func testLegacyVersionsAndEscapedBytesDoNotDependOnDisplayLanguage() throws {
        let raw = #"synthetic-值\n\t\e"#
        let expanded = "synthetic-值\n\t\u{1b}"
        let cases: [(Int?, iTermSendTextEscaping)] = [
            (nil, .compatibility), (0, .compatibility), (1, .common),
            (2, .none), (2, .compatibility), (2, .common),
            (2, .vim), (2, .vimAndCompatibility)
        ]
        for (version, escaping) in cases {
            var input: [AnyHashable: Any] = ["Action": 12, "Text": raw, "synthetic-extra": "keep"]
            if let version = version {
                input["Version"] = version
                input["Escaping"] = escaping.rawValue
            }
            let action = try XCTUnwrap(iTermKeyBindingAction.withDictionary(input))
            XCTAssertEqual(action.escaping, escaping)
            let expected = escaping == .none ? raw : expanded
            XCTAssertEqual(Array(iTermKeyBindingAction.escapedText(action.parameter, mode: action.escaping).utf8),
                           Array(expected.utf8))
            _ = action.displayName
            try checkRoundTrip(action, expected: input)
            XCTAssertEqual(Array(iTermKeyBindingAction.escapedText(action.parameter, mode: action.escaping).utf8),
                           Array(expected.utf8))
        }
    }

    func testApplyModeNamesDoNotChangeSerializedEnums() throws {
        let chinese = try isChinese()
        let fixtures: [(iTermActionApplyMode, String, String)] = [
            (.currentSession, "Ignore", "忽略"),
            (.allSessions, "In all sessions, Ignore", "在所有会话中，忽略"),
            (.unfocusedSessions, "In unfocused sessions, Ignore", "在未聚焦的会话中，忽略"),
            (.allInWindow, "In all sessions in the window, Ignore", "在窗口的所有会话中，忽略"),
            (.allInTab, "In all sessions in the tab, Ignore", "在标签页的所有会话中，忽略"),
            (.broadcasting, "In all broadcasted-to sessions, Ignore", "在所有广播目标会话中，忽略")
        ]
        for (mode, english, translation) in fixtures {
            let action = try XCTUnwrap(iTermKeyBindingAction.withAction(
                .ACTION_IGNORE, parameter: "synthetic", escaping: .none, applyMode: mode))
            let expected: [AnyHashable: Any] = [
                "Action": 13, "Text": "synthetic", "Version": 2, "Escaping": 0, "Apply Mode": mode.rawValue
            ]
            XCTAssertEqual(action.displayName, chinese ? translation : english)
            XCTAssertFalse(action.sendsText)
            try checkRoundTrip(action, expected: expected)
        }
    }

    func testNestedSequenceDisplayLeavesRealSequenceCodecUnchanged() throws {
        let chinese = try isChinese()
        let ignore = try XCTUnwrap(iTermKeyBindingAction.withAction(
            .ACTION_IGNORE, parameter: "", escaping: .none, applyMode: .currentSession))
        let send = try XCTUnwrap(iTermKeyBindingAction.withAction(
            .ACTION_TEXT, parameter: #"synthetic-值\n"#, escaping: .common, applyMode: .currentSession))
        let innerParameter = NSString.parameter(forKeyBindingActionSequence: [ignore, send])
        let inner = try XCTUnwrap(iTermKeyBindingAction.withAction(
            .ACTION_SEQUENCE, parameter: innerParameter as String, escaping: .none, applyMode: .currentSession))
        let parameter = NSString.parameter(forKeyBindingActionSequence: [ignore, inner])
        let sequence = try XCTUnwrap(iTermKeyBindingAction.withAction(
            .ACTION_SEQUENCE, parameter: parameter as String, escaping: .none, applyMode: .currentSession))
        let before = sequence.dictionaryValue
        let separator = chinese ? "，然后" : ", then "
        XCTAssertEqual(sequence.displayName, [ignore.displayName, ignore.displayName, send.displayName]
            .joined(separator: separator))
        XCTAssertTrue(sequence.sendsText)
        XCTAssertTrue(sequence.isActionable)
        let decoded = (sequence.parameter as NSString).keyBindingActionsFromSequenceParameter()
        XCTAssertEqual(decoded.map { $0.dictionaryValue } as NSArray,
                       [ignore.dictionaryValue, inner.dictionaryValue] as NSArray)
        XCTAssertEqual(decoded.last?.parameter, innerParameter as String)
        let nested = (try XCTUnwrap(decoded.last).parameter as NSString).keyBindingActionsFromSequenceParameter()
        XCTAssertEqual(nested.map { $0.dictionaryValue } as NSArray,
                       [ignore.dictionaryValue, send.dictionaryValue] as NSArray)
        try checkRoundTrip(sequence, expected: before)
    }

    func testToggleSettingKeepsSyntheticIdentifierAndUserLabel() throws {
        let chinese = try isChinese()
        for isProfile in [false, true] {
            let parameter = iTermKeyBindingAction.toggleSettingParameter(
                forKey: "synthetic.raw.key", isProfile: isProfile, label: "user-设置")
            let action = try XCTUnwrap(iTermKeyBindingAction.withAction(
                .ACTION_TOGGLE_SETTING, parameter: parameter, escaping: .none, applyMode: .currentSession))
            let before = action.dictionaryValue
            XCTAssertEqual(action.displayName, chinese ? "切换user-设置" : "Toggle user-设置")
            XCTAssertEqual(action.toggleSettingKey, "synthetic.raw.key")
            XCTAssertEqual(action.toggleSettingLabel, "user-设置")
            XCTAssertEqual(action.toggleSettingIsProfile, isProfile)
            let data = try XCTUnwrap(parameter.data(using: .utf8))
            XCTAssertEqual(try JSONSerialization.jsonObject(with: data) as? NSDictionary,
                           ["key": "synthetic.raw.key", "isProfile": isProfile, "label": "user-设置"] as NSDictionary)
            try checkRoundTrip(action, expected: before)
        }
    }

    func testKeyNamesAndModifiersDoNotChangeSerializedKeystrokes() throws {
        let chinese = try isChinese()
        let fixtures: [(UInt32, String, String)] = [
            (0x7f, "←Delete", "←Delete"), (0xf728, "Del→", "Del→"),
            (0xf729, "Home", "行首"), (0xf72b, "End", "行尾"), (0xf746, "Help", "帮助"),
            (0xf700, "↑", "↑"), (0xf701, "↓", "↓"), (0xf702, "←", "←"), (0xf703, "→", "→"),
            (0x20, "Space", "Space"), (0x0d, "Return ↩", "Return ↩"), (0x09, "Tab ↦", "Tab ↦"),
            (0x1b, "Esc ⎋", "Esc ⎋"), (0x61, "a", "a"), (0x4e2d, "中", "中")
        ]
        for (character, english, translation) in fixtures {
            for modifiers: NSEvent.ModifierFlags in [[], .command, .numericPad] {
                // Keycode-free formatting does not access or change the host's
                // keyboard input source. No NSEvent is created or posted.
                let key = iTermKeystroke(virtualKeyCode: 0, hasKeyCode: false,
                                        modifierFlags: modifiers, character: character, modifiedCharacter: character)
                let isArrow = (0xf700...0xf703).contains(character)
                let normalizedModifiers = isArrow ? modifiers.union(.numericPad) : modifiers
                let serialized = String(format: "0x%x-0x%llx", character, UInt64(normalizedModifiers.rawValue))
                let prefix = modifiers == .command ? "⌘" : (modifiers == .numericPad && !isArrow ? "num-" : "")
                let expected = prefix + (chinese ? translation : english)
                XCTAssertEqual(iTermKeystrokeFormatter.string(for: key), expected)
                XCTAssertEqual(iTermKeystrokeFormatter.string(forKeystrokeIgnoringKeycode: key), expected)
                XCTAssertEqual(key.serialized, serialized)
                let restored = iTermKeystroke(serialized: serialized)
                XCTAssertEqual(restored.serialized, serialized)
                XCTAssertEqual(restored.character, character)
                XCTAssertEqual(restored.modifierFlags, normalizedModifiers)
                // The upstream legacy format stores the unmodified character
                // only; decoding deliberately resets modifiedCharacter to zero.
                XCTAssertEqual(restored.modifiedCharacter, 0)
                XCTAssertFalse(restored.hasVirtualKeyCode)
            }
        }
    }

}
