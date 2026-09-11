import XCTest
@testable import iTerm2SharedARC

final class WorkgroupTriggerLocalizationTests: XCTestCase {
    @MainActor
    private func withSyntheticModel(_ body: (iTermWorkgroupModel) throws -> Void) throws {
        // Check before accessing defaults or initializing the singleton. Never
        // switch suites in a running host or inspect a real user's workgroups.
        let suite = try XCTUnwrap(iTermUserDefaults.customSuiteName())
        guard suite == "iterm2-tests" else {
            XCTFail("Workgroup fixtures require the isolated ModernTests suite")
            return
        }
        let defaults = iTermUserDefaults.userDefaults()
        let keys = ["Workgroups", "NoSyncWorkgroupShortcutsBackfilled",
                    "NoSyncClaudeCodeDiffModeBackfilled",
                    "NoSyncClaudeCodeReviewSystemPromptCommandBackfilled",
                    "NoSyncClaudeCodeAutoSendClippingsBackfilled",
                    "NoSyncClaudeCodeAutoRequestReviewBackfilled"]
        var saved: [String: Any] = [:]
        for key in keys {
            saved[key] = defaults.object(forKey: key)
        }
        let model = iTermWorkgroupModel.instance
        let original = model.workgroups
        defer {
            model.setAll(original)
            // Restore exact serialized data (including absence) and migration
            // latches as well as memory, even when an assertion fails.
            for key in keys {
                defaults.set(saved[key], forKey: key)
                let restored = defaults.object(forKey: key) as? NSObject
                XCTAssertTrue(restored == saved[key] as? NSObject,
                              "Isolated workgroup preference was not restored")
            }
            XCTAssertTrue(model.workgroups == original)
        }
        try body(model)
    }

    private func workgroup(id: String, name: String) -> iTermWorkgroup {
        return iTermWorkgroup(uniqueIdentifier: id, name: name,
                              sessions: [WGFix.makeRoot()])
    }

    private func triggers() -> [Trigger] {
        return [EnterWorkgroupTrigger(), EnterWorkgroupBrowserTrigger()]
    }

    func testIndependentActionTitlesRemainLocalized() throws {
        let language = try XCTUnwrap(Bundle.main.preferredLocalizations.first)
        XCTAssertTrue(["en", "zh-Hans"].contains(language))
        let expected = language == "zh-Hans" ? "进入工作组…" : "Enter Workgroup…"
        XCTAssertEqual(EnterWorkgroupTrigger.title, expected)
        XCTAssertEqual(EnterWorkgroupBrowserTrigger.title, expected)
    }

    @MainActor
    func testPopupOrderingAndImplicitTargetRetainBaselineLabels() throws {
        try withSyntheticModel { model in
            // Compare with the actual existing locale-aware sorter, not an
            // assumed ASCII order. Each pair avoids equal display labels.
            for name in ["T", "V", "Z", "Alpha", "中文", "无名"] {
                let unnamed = workgroup(id: "synthetic-unnamed", name: "")
                let named = workgroup(id: "synthetic-named", name: name)
                let fixtures = [named, unnamed]
                model.setAll(fixtures)
                let persisted = iTermUserDefaults.workgroupsData
                let baseline: [AnyHashable: Any] = [unnamed.uniqueIdentifier: "Untitled",
                                                  named.uniqueIdentifier: name]
                for trigger in triggers() {
                    let context = "\(type(of: trigger)), named=\(name)"
                    let order = trigger.objectsSortedByValue(inDict: baseline)
                    let expectedID = try XCTUnwrap(order.first as? String)
                    let menu = try XCTUnwrap(trigger.menuItemsForPoupupButton())
                    XCTAssertEqual(menu as NSDictionary, baseline as NSDictionary, context)
                    XCTAssertEqual(trigger.object(at: 0) as? String, expectedID, context)
                    for (index, id) in order.enumerated() {
                        XCTAssertEqual(trigger.object(at: index) as? String, id as? String, context)
                        XCTAssertEqual(trigger.index(for: id), index, context)
                    }
                    XCTAssertNil(trigger.object(at: -1), context)
                    XCTAssertNil(trigger.object(at: order.count), context)
                    XCTAssertEqual(trigger.index(for: "synthetic-missing"), -1, context)

                    // Explicit selection and the implicit default must resolve
                    // to the same target. These real presentation methods read
                    // the private effectiveID also consumed by both actions;
                    // do not invoke either action or create a session/browser.
                    trigger.param = expectedID
                    let expectedLabel = trigger.paramAttributedString()?.string
                    let expectedDescription = trigger.description
                    for parameter: Any? in [nil, "", NSNumber(value: 17)] {
                        trigger.param = parameter
                        let dictionary = trigger.dictionaryValue()
                        let digest = trigger.digest
                        XCTAssertEqual(trigger.paramAttributedString()?.string, expectedLabel, context)
                        XCTAssertEqual(trigger.description, expectedDescription, context)
                        XCTAssertEqual(trigger.dictionaryValue() as NSDictionary,
                                       dictionary as NSDictionary, context)
                        XCTAssertEqual(trigger.digest, digest, context)
                    }
                }
                XCTAssertTrue(model.workgroups == fixtures)
                XCTAssertTrue(iTermUserDefaults.workgroupsData == persisted)
            }
        }
    }

    @MainActor
    func testTerminalDescriptionsKeepSharedFallbackDiagnostics() throws {
        try withSyntheticModel { model in
            let named = workgroup(id: "synthetic-named", name: "synthetic-中文\\1")
            let unnamed = workgroup(id: "synthetic-unnamed", name: "")
            let trigger = EnterWorkgroupTrigger()
            let fixtures: [([iTermWorkgroup], Any?, String)] = [
                ([named, unnamed], named.uniqueIdentifier, named.name),
                ([named, unnamed], unnamed.uniqueIdentifier, "Untitled"),
                ([named, unnamed], "synthetic-missing", "(missing)"),
                ([], nil, "(unset)"),
                ([], "", "(unset)"),
                ([unnamed], nil, "Untitled"),
                ([unnamed], "", "Untitled"),
                ([unnamed], NSNumber(value: 17), "Untitled")
            ]
            for (groups, parameter, label) in fixtures {
                model.setAll(groups)
                let persisted = iTermUserDefaults.workgroupsData
                trigger.param = parameter
                let dictionary = trigger.dictionaryValue()
                let digest = trigger.digest
                let expected = "Enter Workgroup “\(label)”"
                XCTAssertEqual(trigger.description, expected)
                XCTAssertEqual(String(format: "Consider %@", trigger), "Consider " + expected)
                XCTAssertEqual(String(format: "Trigger %@ matched string %@", trigger, "fixture"),
                               "Trigger " + expected + " matched string fixture")
                // The parameter row deliberately shares this helper; this is
                // not a separate UI-only value that can safely be translated.
                XCTAssertEqual(trigger.paramAttributedString()?.string, label)
                XCTAssertEqual(trigger.dictionaryValue() as NSDictionary, dictionary as NSDictionary)
                XCTAssertEqual(trigger.digest, digest)
                XCTAssertTrue(model.workgroups == groups)
                XCTAssertTrue(iTermUserDefaults.workgroupsData == persisted)
            }
        }
    }

    @MainActor
    func testExplicitIDsAndEmptyMenuAreNotRewritten() throws {
        try withSyntheticModel { model in
            let fixtures = [workgroup(id: "synthetic-unnamed", name: ""),
                            workgroup(id: "synthetic-named", name: "V")]
            model.setAll(fixtures)
            for trigger in triggers() {
                for id in fixtures.map(\.uniqueIdentifier) + ["synthetic-missing", " "] {
                    trigger.param = id
                    let dictionary = trigger.dictionaryValue()
                    let digest = trigger.digest
                    _ = trigger.description
                    _ = trigger.paramAttributedString()
                    _ = trigger.menuItemsForPoupupButton()
                    XCTAssertEqual(trigger.param as? String, id)
                    XCTAssertEqual(trigger.dictionaryValue() as NSDictionary,
                                   dictionary as NSDictionary)
                    XCTAssertEqual(trigger.digest, digest)
                    if let fixture = fixtures.first(where: { $0.uniqueIdentifier == id }),
                       !fixture.name.isEmpty {
                        XCTAssertEqual(trigger.paramAttributedString()?.string, fixture.name)
                    }
                }
            }
            model.setAll([])
            for trigger in triggers() {
                XCTAssertTrue(try XCTUnwrap(trigger.menuItemsForPoupupButton()).isEmpty)
                XCTAssertNil(trigger.object(at: 0))
                XCTAssertEqual(trigger.index(for: "synthetic-missing"), -1)
                trigger.param = nil
                XCTAssertFalse(try XCTUnwrap(trigger.paramAttributedString()).string.isEmpty)
                XCTAssertNil(trigger.param)
            }
        }
    }
}
