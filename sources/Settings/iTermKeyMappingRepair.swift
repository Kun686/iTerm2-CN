import AppKit

@objc(iTermKeyMappingRepair)
class iTermKeyMappingRepair: NSObject {
    private static let mitigationDisabledKeyPrefix = "NoSyncKeyCode0MitigationDisabled_"

    @objc static func isMitigationDisabled(suffix: String) -> Bool {
        iTermUserDefaults.userDefaults().bool(forKey: mitigationDisabledKeyPrefix + suffix)
    }

    @objc static func setMitigationDisabled(_ disabled: Bool, suffix: String) {
        iTermUserDefaults.userDefaults().set(disabled, forKey: mitigationDisabledKeyPrefix + suffix)
    }

    /// Returns YES if the given serialized key binding has keycode 0 with a character
    /// that doesn't match what keycode 0 actually produces.
    @objc static func serializedKeyBindingHasCorruptedKeyCode0(_ serialized: String) -> Bool {
        let keystroke = iTermKeystroke(serialized: serialized)

        // Only 3-part format has hasVirtualKeyCode == true
        guard keystroke.hasVirtualKeyCode else {
            return false
        }

        // Only care about keycode 0
        guard keystroke.virtualKeyCode == 0 else {
            return false
        }

        // Get what keycode 0 actually produces (no modifiers)
        guard let expectedString = NSEvent.stringForKey(withKeycode: 0, modifiers: 0),
              !expectedString.isEmpty,
              let expectedScalar = expectedString.unicodeScalars.first else {
            // Couldn't determine, be conservative and assume not corrupted
            return false
        }

        // Compare case-insensitively
        let expectedChar = Character(expectedScalar).lowercased()
        let actualChar = Character(UnicodeScalar(keystroke.character) ?? UnicodeScalar(0)).lowercased()

        return expectedChar != actualChar
    }

    /// Returns an array of corrupted serialized key binding strings from a key mapping dictionary.
    @objc static func corruptedKeyBindings(in keyMappings: [String: Any]?) -> [String] {
        guard let keyMappings else {
            return []
        }
        return keyMappings.keys.filter { serializedKeyBindingHasCorruptedKeyCode0($0) }
    }

    /// Repair a key mapping dictionary by converting corrupted 3-component entries
    /// back to 2-component (legacy) format.
    @objc static func repairedKeyMappings(_ keyMappings: [String: Any]) -> [String: Any] {
        var repaired = keyMappings
        let corrupted = corruptedKeyBindings(in: keyMappings)

        for serialized in corrupted {
            guard let value = repaired[serialized] else {
                continue
            }
            repaired.removeValue(forKey: serialized)

            // Create the legacy 2-component format: "0x%x-0x%x" (character-modifierFlags)
            let keystroke = iTermKeystroke(serialized: serialized)
            let legacySerialized = String(format: "0x%x-0x%x", keystroke.character, Int32(keystroke.modifierFlags.rawValue))
            repaired[legacySerialized] = value
        }

        return repaired
    }

    /// Shows a confirmation dialog for repairing corrupted key bindings.
    /// Returns true if the user confirmed, false otherwise.
    @objc static func confirmRepair(keyMappings: [String: Any], window: NSWindow?) -> Bool {
        let corrupted = corruptedKeyBindings(in: keyMappings)
        guard !corrupted.isEmpty else {
            return false
        }

        // Format the list of affected key bindings based on character (not keycode, since it's wrong)
        let descriptions = corrupted.compactMap { serialized -> String? in
            let keystroke = iTermKeystroke(serialized: serialized)
            let keystrokeString = iTermKeystrokeFormatter.string(forKeystrokeIgnoringKeycode: keystroke)
            guard !keystrokeString.isEmpty else { return nil }

            // Get the action description
            guard let actionDict = keyMappings[serialized] as? [String: Any] else {
                return keystrokeString
            }
            let action = iTermKeyBindingAction.withDictionary(actionDict)
            let actionName = action?.displayName ?? String(localized: "ui.swift.settings.itermkeymappingrepair.unknown_action.7ef8915e", defaultValue: "Unknown action", bundle: .main, comment: "User-facing text in iTermKeyMappingRepair.")
            return "\(keystrokeString): \(actionName)"
        }

        let bindingsList = descriptions.sorted().map { "• \($0)" }.joined(separator: "\n")
        let count = corrupted.count
        let message: String
        if count == 1 {
            message = String(localized: "ui.settings.key_mapping_repair.message.singular",
                             defaultValue: "This will repair \(count) key binding that was corrupted by a bug in an earlier version of iTerm2. The affected binding currently displays incorrectly but functions properly. After repair, it will display correctly.\n\nAffected key binding:\n\(bindingsList)",
                             bundle: .main,
                             comment: "Confirmation message for repairing one corrupted key binding.")
        } else {
            message = String(localized: "ui.settings.key_mapping_repair.message.plural",
                             defaultValue: "This will repair \(count) key bindings that were corrupted by a bug in an earlier version of iTerm2. The affected bindings currently display incorrectly but function properly. After repair, they will display correctly.\n\nAffected key bindings:\n\(bindingsList)",
                             bundle: .main,
                             comment: "Confirmation message for repairing multiple corrupted key bindings.")
        }

        let selection = iTermWarning.show(
            withTitle: message,
            actions: [String(localized: "ui.swift.settings.itermkeymappingrepair.repair.1196b6c5", defaultValue: "Repair", bundle: .main, comment: "User-facing text in iTermKeyMappingRepair."), String(localized: "ui.swift.settings.itermkeymappingrepair.cancel.19766ed6", defaultValue: "Cancel", bundle: .main, comment: "User-facing text in iTermKeyMappingRepair.")],
            identifier: nil,
            silenceable: .kiTermWarningTypePersistent,
            window: window
        )

        return selection == .kiTermWarningSelection0
    }
}
