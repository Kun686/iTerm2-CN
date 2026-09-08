import XCTest
@testable import iTerm2SharedARC

final class SettingPopupLocalizationTests: XCTestCase {
    private func withIsolatedPopup(_ body: (SettingPopupView, String, String, String) throws -> Void) throws {
        // Check before loading the Settings nib or accessing its registered
        // controls. Never toggle a setting or execute a key-binding action.
        guard Thread.isMainThread,
              iTermUserDefaults.customSuiteName() == "iterm2-tests" else {
            XCTFail("Setting popup fixtures require main and the isolated ModernTests suite")
            return
        }
        let language = try XCTUnwrap(Bundle.main.preferredLocalizations.first)
        XCTAssertTrue(["en", "zh-Hans"].contains(language))
        let english = "Prevent the system from sleeping while a session has this setting on."
        let chinese = "启用此设置的会话存在时，阻止系统睡眠。"
        let entry = try XCTUnwrap(ProfileBoolSettingCatalog.entries().first { $0.key == "Prevent Sleep" })
        XCTAssertEqual(entry.label, language == "zh-Hans" ? chinese : english)
        let current = iTermKeyBindingAction.toggleSettingParameter(
            forKey: entry.key, isProfile: true, label: entry.label)
        let otherLanguage = iTermKeyBindingAction.toggleSettingParameter(
            forKey: entry.key, isProfile: true, label: language == "zh-Hans" ? english : chinese)
        let popup = SettingPopupView(frame: .zero)
        try body(popup, current, otherLanguage, entry.label)
    }

    func testCurrentLanguageIdentifierSelectsSettingAndUnknownKeyIsRejected() throws {
        try withIsolatedPopup { popup, current, _, label in
            XCTAssertTrue(popup.select(identifier: current))
            // The framework's selectedItem getter reports a transient table
            // highlight, not the selectedTag check mark. Read the real button
            // title after programmatic selection without opening its menu.
            XCTAssertEqual(popup.comboView?.title, label)
            let unknown = iTermKeyBindingAction.toggleSettingParameter(
                forKey: "synthetic.unregistered.setting", isProfile: true, label: label)
            XCTAssertFalse(popup.select(identifier: unknown))
            XCTAssertNil(popup.selectedIdentifier)
        }
    }

    func testStoredIdentifierFromOtherLanguageStillSelectsSameSetting() throws {
        try withIsolatedPopup { popup, current, otherLanguage, label in
            // Positive control: the same actual catalog, raw key and isProfile
            // flag select correctly with the current-language display label.
            XCTAssertTrue(popup.select(identifier: current))
            let original = try XCTUnwrap(iTermKeyBindingAction.withAction(
                .ACTION_TOGGLE_SETTING, parameter: otherLanguage, escaping: .none, applyMode: .currentSession))
            let before = original.dictionaryValue
            let selected = popup.select(identifier: original.parameter)
            XCTAssertTrue(selected, "Changing UI language must not lose an existing Toggle Setting selection")
            if selected {
                XCTAssertEqual(popup.comboView?.title, label)
                let selectedParameter = try XCTUnwrap(popup.selectedIdentifier)
                XCTAssertEqual(selectedParameter, otherLanguage,
                               "Restoring the visible selection must not rewrite the stored parameter")
                let restored = try XCTUnwrap(iTermKeyBindingAction.withAction(
                    .ACTION_TOGGLE_SETTING, parameter: selectedParameter, escaping: .none, applyMode: .currentSession))
                XCTAssertEqual(restored.toggleSettingKey, "Prevent Sleep")
                XCTAssertTrue(restored.toggleSettingIsProfile)
                popup.reloadData()
                XCTAssertEqual(popup.comboView?.title, label)
                XCTAssertEqual(popup.selectedIdentifier, otherLanguage)
            }
            XCTAssertEqual(original.parameter, otherLanguage)
            XCTAssertEqual(original.dictionaryValue as NSDictionary, before as NSDictionary)
        }
    }

    func testRestoredSelectionKeepsOpaqueFieldsAndRejectsMalformedIdentity() throws {
        try withIsolatedPopup { popup, _, otherLanguage, label in
            let data = try XCTUnwrap(otherLanguage.data(using: .utf8))
            var dictionary = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            dictionary["synthetic-extra"] = "keep-original"
            let encoded = try JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys, .prettyPrinted])
            let original = try XCTUnwrap(String(data: encoded, encoding: .utf8))
            XCTAssertTrue(popup.select(identifier: original))
            XCTAssertEqual(popup.comboView?.title, label)
            XCTAssertEqual(popup.selectedIdentifier, original)

            let invalid: [[String: Any]] = [
                ["key": "Prevent Sleep", "label": label],
                ["key": "Prevent Sleep", "label": label, "isProfile": "true"],
                ["key": "Prevent Sleep", "label": 17, "isProfile": true],
                ["key": "", "label": label, "isProfile": true],
                ["key": "synthetic.unregistered.setting", "label": label, "isProfile": true]
            ]
            for value in invalid {
                let encoded = try JSONSerialization.data(withJSONObject: value)
                let parameter = try XCTUnwrap(String(data: encoded, encoding: .utf8))
                XCTAssertFalse(popup.select(identifier: parameter))
                XCTAssertNil(popup.selectedIdentifier)
            }
            for parameter in ["", "not-json", "[]"] {
                XCTAssertFalse(popup.select(identifier: parameter))
                XCTAssertNil(popup.selectedIdentifier)
            }
            XCTAssertTrue(popup.select(identifier: original))
            XCTAssertEqual(popup.selectedIdentifier, original)
        }
    }
}
