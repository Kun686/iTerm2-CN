//
//  SetProfileBooleanTriggerTests.swift
//  ModernTests
//
//  Tests that SetProfileBooleanTrigger.description is safe to call off the main thread (it is
//  invoked from a DLog on the trigger mutation queue), i.e. it does not read main-thread-only
//  AppKit via ProfileBoolSettingCatalog/PreferencePanel.allSettings() (F14).
//

import XCTest
@testable import iTerm2SharedARC

final class SetProfileBooleanTriggerTests: XCTestCase {
    private func makeTrigger(key: String, on: Bool) -> Trigger? {
        let param = TwoParameterTriggerCodec.convert(tuple: (key, on ? "1" : "0"))
        let dict: [String: Any] = [
            "action": "iTermSetProfileBooleanTrigger",
            "parameter": param,
            "regex": "",
            "matchType": NSNumber(value: iTermTriggerMatchType.regex.rawValue)
        ]
        return Trigger(fromUntrustedDict: dict)
    }

    // F14: off the main thread, description must fall back to the raw key rather than building the
    // catalog (which reads AppKit). The raw key "Prevent Sleep" is readable enough for a log line.
    func testDescriptionOffMainThreadUsesRawKeyAndDoesNotTouchAppKit() {
        guard let trigger = makeTrigger(key: "Prevent Sleep", on: true) else {
            XCTFail("could not create trigger")
            return
        }
        let exp = expectation(description: "off-main description")
        DispatchQueue.global().async {
            let desc = trigger.description
            XCTAssertTrue(desc.contains("Prevent Sleep"), "expected raw key in \(desc)")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testUncachedBackgroundDescriptionRetainsOriginalDiagnosticText() throws {
        let trigger = try XCTUnwrap(makeTrigger(key: "synthetic-unregistered-setting", on: true))
        let dictionary = trigger.dictionaryValue()
        let digest = trigger.digest
        let expected = "Set “synthetic-unregistered-setting” to On"
        let finished = expectation(description: "uncached diagnostic")
        DispatchQueue.global().async {
            XCTAssertEqual(trigger.description, expected)
            XCTAssertEqual(String(format: "Consider %@", trigger), "Consider " + expected)
            XCTAssertEqual(trigger.dictionaryValue() as NSDictionary, dictionary as NSDictionary)
            XCTAssertEqual(trigger.digest, digest)
            finished.fulfill()
        }
        wait(for: [finished], timeout: 5)
    }

    func testCachedBackgroundDescriptionLocalizesOnlySettingName() throws {
        // Guard before forcing the Preferences nib. This reuses the catalog's
        // existing read-only test seam, never a production suite or session.
        guard Thread.isMainThread,
              iTermUserDefaults.customSuiteName() == "iterm2-tests" else {
            XCTFail("Profile catalog checks require main and the isolated ModernTests suite")
            return
        }
        let language = try XCTUnwrap(Bundle.main.preferredLocalizations.first)
        XCTAssertTrue(["en", "zh-Hans"].contains(language))
        let englishLabel = "Prevent the system from sleeping while a session has this setting on."
        let entry = try XCTUnwrap(ProfileBoolSettingCatalog.entries().first { $0.key == "Prevent Sleep" })
        XCTAssertEqual(entry.label, language == "zh-Hans"
                       ? "启用此设置的会话存在时，阻止系统睡眠。" : englishLabel)
        let trigger = try XCTUnwrap(makeTrigger(key: "Prevent Sleep", on: true))
        let dictionary = trigger.dictionaryValue()
        let digest = trigger.digest
        // The approved diagnostic exception is only the existing UI-derived
        // setting name. The format, On/Off, raw key and stored action stay fixed.
        let expected = "Set “\(entry.label)” to On"
        // Warm the real per-instance cache on main, then use the same object on
        // the background queue as the terminal's Foundation log formatter does.
        XCTAssertEqual(trigger.description, expected)
        let finished = expectation(description: "cached diagnostic")
        DispatchQueue.global().async {
            XCTAssertEqual(trigger.description, expected)
            XCTAssertEqual(String(format: "Consider %@", trigger), "Consider " + expected)
            XCTAssertEqual(trigger.dictionaryValue() as NSDictionary, dictionary as NSDictionary)
            XCTAssertEqual(trigger.digest, digest)
            finished.fulfill()
        }
        wait(for: [finished], timeout: 5)
    }

    func testOffAndMalformedParametersKeepOriginalDiagnosticFormat() throws {
        let trigger = try XCTUnwrap(makeTrigger(key: "synthetic-unregistered-setting", on: false))
        let finished = expectation(description: "off diagnostic")
        DispatchQueue.global().async {
            XCTAssertEqual(trigger.description, "Set “synthetic-unregistered-setting” to Off")
            finished.fulfill()
        }
        wait(for: [finished], timeout: 5)
        let malformed = try XCTUnwrap(makeTrigger(key: "", on: true))
        XCTAssertEqual(malformed.description, "Set Profile Setting")
    }
}
