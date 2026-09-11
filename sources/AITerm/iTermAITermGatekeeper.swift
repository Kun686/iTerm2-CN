//
//  iTermAITermGatekeeper.swift
//  iTerm2
//
//  Created by George Nachman on 6/5/25.
//

@objc
class iTermAITermGatekeeper: NSObject {
    @objc
    static func validatePlugin(_ completion: @escaping (String?) -> ()) {
        DLog("validatePlugin")
        iTermAIClient.instance.validate(completion)
    }

    @objc
    static func reloadPlugin(_ completion: @escaping () -> ()) {
        DLog("reloadPlugin")
        iTermAIClient.instance.reload(completion)
    }

    @objc(checkSilently:)
    static func check(silent: Bool = false) -> Bool {
        DLog("check")
        if !iTermAdvancedSettingsModel.generativeAIAllowed() {
            if !silent {
                iTermWarning.show(withTitle: String(localized: "ui.swift.aiterm.itermaitermgatekeeper.generative_ai_features_have_been_disabled_check_with.69006f32", defaultValue: "Generative AI features have been disabled. Check with your system administrator.", bundle: .main, comment: "User-facing text in iTermAITermGatekeeper."),
                                  actions: [String(localized: "ui.swift.aiterm.itermaitermgatekeeper.ok.565339bc", defaultValue: "OK", bundle: .main, comment: "User-facing text in iTermAITermGatekeeper.")],
                                  accessory: nil,
                                  identifier: nil,
                                  silenceable: .kiTermWarningTypePersistent,
                                  heading: String(localized: "ui.swift.aiterm.itermaitermgatekeeper.feature_unavailable.5031e0f3", defaultValue: "Feature Unavailable", bundle: .main, comment: "User-facing text in iTermAITermGatekeeper."),
                                  window: nil)
            }
            return false
        }
        if !iTermAITermGatekeeper.pluginInstalled() {
            if !silent {
                let selection = iTermWarning.show(withTitle: String(localized: "ui.swift.aiterm.itermaitermgatekeeper.you_must_install_the_ai_plugin_before_you.39e3a465", defaultValue: "You must install the AI plugin before you can use this feature.", bundle: .main, comment: "User-facing text in iTermAITermGatekeeper."),
                                                  actions: [String(localized: "ui.swift.aiterm.itermaitermgatekeeper.reveal_in_settings.21379104", defaultValue: "Reveal in Settings", bundle: .main, comment: "User-facing text in iTermAITermGatekeeper."), String(localized: "ui.swift.aiterm.itermaitermgatekeeper.cancel.19766ed6", defaultValue: "Cancel", bundle: .main, comment: "User-facing text in iTermAITermGatekeeper.")],
                                                  accessory: nil,
                                                  identifier: nil,
                                                  silenceable: .kiTermWarningTypePersistent,
                                                  heading: String(localized: "ui.swift.aiterm.itermaitermgatekeeper.plugin_missing.5c735ad6", defaultValue: "Plugin Missing", bundle: .main, comment: "User-facing text in iTermAITermGatekeeper."),
                                                  window: nil)
                if selection == .kiTermWarningSelection0 {
                    PreferencePanel.sharedInstance().openToPreference(withKey: kPhonyPreferenceKeyInstallAIPlugin)
                }
            }
            return false
        }
        if !SecureUserDefaults.instance.enableAI.value {
            if !silent {
                let selection = iTermWarning.show(withTitle: String(localized: "ui.swift.aiterm.itermaitermgatekeeper.you_must_enable_ai_features_in_settings_before.a75b4f1e", defaultValue: "You must enable AI features in settings before you can use this feature.", bundle: .main, comment: "User-facing text in iTermAITermGatekeeper."),
                                                  actions: [String(localized: "ui.swift.aiterm.itermaitermgatekeeper.reveal.36b830bd", defaultValue: "Reveal", bundle: .main, comment: "User-facing text in iTermAITermGatekeeper."), String(localized: "ui.swift.aiterm.itermaitermgatekeeper.cancel.19766ed6", defaultValue: "Cancel", bundle: .main, comment: "User-facing text in iTermAITermGatekeeper.")],
                                                  accessory: nil,
                                                  identifier: nil,
                                                  silenceable: .kiTermWarningTypePersistent,
                                                  heading: String(localized: "ui.swift.aiterm.itermaitermgatekeeper.feature_unavailable.5031e0f3", defaultValue: "Feature Unavailable", bundle: .main, comment: "User-facing text in iTermAITermGatekeeper."),
                                                  window: nil)
                if selection == .kiTermWarningSelection0 {
                    PreferencePanel.sharedInstance().openToPreference(withKey: kPreferenceKeyEnableAI)
                }
            }
            return false
        }
        do {
            try iTermAIClient.instance.validate()
        } catch let error as PluginError {
            RLog("\(error.reason)")
            if !silent {
                iTermWarning.show(withTitle: error.reason,
                                  actions: [String(localized: "ui.swift.aiterm.itermaitermgatekeeper.ok.565339bc", defaultValue: "OK", bundle: .main, comment: "User-facing text in iTermAITermGatekeeper.")],
                                  accessory: nil,
                                  identifier: nil,
                                  silenceable: .kiTermWarningTypePersistent,
                                  heading: String(localized: "ui.swift.aiterm.itermaitermgatekeeper.feature_unavailable.5031e0f3", defaultValue: "Feature Unavailable", bundle: .main, comment: "User-facing text in iTermAITermGatekeeper."),
                                  window: nil)
            }
            return false
        } catch {
            if !silent {
                iTermWarning.show(withTitle: error.localizedDescription,
                                  actions: [String(localized: "ui.swift.aiterm.itermaitermgatekeeper.ok.565339bc", defaultValue: "OK", bundle: .main, comment: "User-facing text in iTermAITermGatekeeper.")],
                                  accessory: nil,
                                  identifier: nil,
                                  silenceable: .kiTermWarningTypePersistent,
                                  heading: String(localized: "ui.swift.aiterm.itermaitermgatekeeper.feature_unavailable.5031e0f3", defaultValue: "Feature Unavailable", bundle: .main, comment: "User-facing text in iTermAITermGatekeeper."),
                                  window: nil)
            }
            return false
        }
        return true
    }

    @objc
    static func pluginInstalled() -> Bool {
        switch Plugin.instance() {
        case .success:
            return true
        case .failure:
            return false
        }
    }

    @objc
    static var allowed: Bool {
        DLog("allowed")
        return iTermAdvancedSettingsModel.generativeAIAllowed() && SecureUserDefaults.instance.enableAI.value
    }
}
