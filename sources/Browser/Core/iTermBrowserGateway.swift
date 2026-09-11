//
//  iTermBrowserGateway.swift
//  iTerm2
//
//  Created by George Nachman on 9/5/25.
//

import Security

struct ExpiringValue<T> {
    private let duration: TimeInterval
    private var _value: T?
    private var _expiration: TimeInterval

    var value: T? {
        get {
            if NSDate.it_timeSinceBoot() > _expiration {
                return nil
            }
            return _value
        }
        set {
            _value = newValue
            _expiration = NSDate.it_timeSinceBoot() + duration
        }
    }

    mutating func expire() {
        _value = nil
        _expiration = 0
    }

    init(value: T?, duration: TimeInterval) {
        self.duration = duration
        _expiration = 0
        self.value = value
    }
}

@objc
class iTermBrowserGateway: NSObject {
    private static var cached = ExpiringValue<Bool>(value: nil, duration: 30)
    private static let bundleID = "com.googlecode.iterm2.iTermBrowserPlugin"
    private static let teamID = "H7V7XYVQ7D"
    @objc static let didChange = Notification.Name(rawValue: "iTermBrowserGatewayDidChange")

    @objc
    static func reload() {
        cached.expire()
    }

    // Web schemes the GetURL Apple event handler should route to the built-in web
    // browser (when the user hasn't bound the scheme to a specific profile). ftp is
    // excluded because the built-in browser cannot display it; file is included
    // because the browser can render local documents. See issue 12431.
    @objc(schemeRoutesToBuiltInBrowser:)
    static func schemeRoutesToBuiltInBrowser(_ scheme: String?) -> Bool {
        guard let scheme = scheme?.lowercased() else {
            return false
        }
        return scheme == "http" || scheme == "https" || scheme == "file"
    }

    @objc(didLocateBundleManually:)
    static func didLocateBundleManually(_ url: URL) -> String? {
        guard let bundle = Bundle(url: url) else {
            return String(localized: "ui.swift.browser.core.itermbrowsergateway.the_file_at_0_is_not_a_valid.b9dc8a97", defaultValue: "The file at \(url.path) is not a valid app bundle.", bundle: .main, comment: "User-facing text in iTermBrowserGateway.")
        }
        if bundle.bundleIdentifier != Self.bundleID {
            let bundleIdentifier = bundle.bundleIdentifier ?? String(localized: "ui.swift.browser.core.itermbrowsergateway.not_set.1aef9399", defaultValue: "not set", bundle: .main, comment: "User-facing text in iTermBrowserGateway.")
            return String(localized: "ui.swift.browser.core.itermbrowsergateway.this_is_not_the_browser_plugin_this_file.9864ffd8", defaultValue: "This is not the browser plugin. This file’s bundle ID is “\(bundleIdentifier)”.\n The expected ID is “\(Self.bundleID)”.", bundle: .main, comment: "User-facing text in iTermBrowserGateway.")
        }
        if !verifyCodeSignature(at: url, teamID: teamID) {
            return String(localized: "ui.swift.browser.core.itermbrowsergateway.the_code_signature_of_the_plugin_at_0.9bb5c1ab", defaultValue: "The code signature of the plugin at \(url.path) is invalid. Download it again, and ensure your anti-virus does not quarantine it.", bundle: .main, comment: "User-facing text in iTermBrowserGateway.")
        }
        iTermAdvancedSettingsModel.setBrowserPluginPathHint(url.path)
        cached.expire()
        return nil
    }

    @objc(browserAllowedCheckingIfNot:)
    static func browserAllowed(checkIfNo: Bool) -> Bool {
        if let cached = cached.value {
            if !checkIfNo || cached {
                return cached
            }
        }
        if !iTermAdvancedSettingsModel.browserProfiles() {
            return false
        }
        let value = checkPluginInstalled()
        cached.value = value
        NotificationCenter.default.post(name: didChange, object: nil)
        return value
    }

    @objc
    static func revealInFinder() {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.activateFileViewerSelecting([appURL])
        }
    }

    @objc
    static func shouldOfferPlugin() -> Bool {
        return iTermAdvancedSettingsModel.browserProfiles() && !checkPluginInstalled()
    }

    @objc
    static func offerPlugin() {
        let selection = iTermWarning.show(withTitle: String(localized: "ui.swift.browser.core.itermbrowsergateway.you_must_install_the_browser_plugin_first_download.a10591f3", defaultValue: "You must install the Browser Plugin first. Download it now?", bundle: .main, comment: "User-facing text in iTermBrowserGateway."),
                                          actions: [String(localized: "ui.swift.browser.core.itermbrowsergateway.ok.565339bc", defaultValue: "OK", bundle: .main, comment: "User-facing text in iTermBrowserGateway."), String(localized: "ui.swift.browser.core.itermbrowsergateway.cancel.19766ed6", defaultValue: "Cancel", bundle: .main, comment: "User-facing text in iTermBrowserGateway.")],
                                          accessory: nil,
                                          identifier: nil,
                                          silenceable: .kiTermWarningTypePersistent,
                                          heading: String(localized: "ui.swift.browser.core.itermbrowsergateway.plugin_required.68601576", defaultValue: "Plugin Required", bundle: .main, comment: "User-facing text in iTermBrowserGateway."),
                                          window: nil)
        if selection == .kiTermWarningSelection0 {
            NSWorkspace.shared.open(URL(string: "https://iterm2.com/browser-plugin.html")!)
        }
    }

    private static let upsellWarningIdentifier = "NoSyncBrowserUpsell"
    @objc
    static func wouldUpsell() -> Bool {
        if let n = iTermWarning.conditionalSavedSelection(forIdentifier: upsellWarningIdentifier) {
            return n.intValue == iTermWarningSelection.kiTermWarningSelection0.rawValue
        }
        return true
    }

    // Return values:
    //   .true -> User will download plugin
    //   .false -> Use system browser
    //   .other -> Abort open
    @objc
    static func upsell() -> iTermTriState {
        // Only "Use System Browser" should be remembered. Remembering "Download"
        // would cause an infinite loop since the plugin would still not be installed.
        // Remembering "Cancel" is also not useful.
        let warning = iTermWarning()
        warning.title = String(localized: "ui.swift.browser.core.itermbrowsergateway.iterm2_can_display_web_pages_but_first_you.592b7c7a", defaultValue: "iTerm2 can display web pages! But first you must download the Browser Plugin.", bundle: .main, comment: "User-facing text in iTermBrowserGateway.")
        warning.actionLabels = [String(localized: "ui.swift.browser.core.itermbrowsergateway.download.d6eafe82", defaultValue: "Download", bundle: .main, comment: "User-facing text in iTermBrowserGateway."), String(localized: "ui.swift.browser.core.itermbrowsergateway.use_system_browser.3e75d58a", defaultValue: "Use System Browser", bundle: .main, comment: "User-facing text in iTermBrowserGateway."), String(localized: "ui.swift.browser.core.itermbrowsergateway.cancel.19766ed6", defaultValue: "Cancel", bundle: .main, comment: "User-facing text in iTermBrowserGateway.")]
        warning.identifier = upsellWarningIdentifier
        warning.warningType = .kiTermWarningTypePermanentlySilenceable
        warning.heading = String(localized: "ui.swift.browser.core.itermbrowsergateway.plugin_required.68601576", defaultValue: "Plugin Required", bundle: .main, comment: "User-facing text in iTermBrowserGateway.")
        warning.doNotRememberLabels = [String(localized: "ui.swift.browser.core.itermbrowsergateway.download.d6eafe82", defaultValue: "Download", bundle: .main, comment: "User-facing text in iTermBrowserGateway."), String(localized: "ui.swift.browser.core.itermbrowsergateway.cancel.19766ed6", defaultValue: "Cancel", bundle: .main, comment: "User-facing text in iTermBrowserGateway.")]
        let selection = warning.runModal()
        switch selection {
        case .kiTermWarningSelection0:
            cached.expire()
            openDownloadPage()
            return .true
        case .kiTermWarningSelection1:
            return .false
        case .kiTermWarningSelection2:
            return .other
        default:
            it_fatalError()
        }
    }

    @objc
    static func openDownloadPage() {
        NSWorkspace.shared.open(URL(string: "https://iterm2.com/browser-plugin.html")!)
        cached.expire()
    }

    private static func checkPluginInstalled() -> Bool {
        if verifyApp(bundleID: bundleID, teamID: teamID) {
            return true
        }
        guard let hint = iTermAdvancedSettingsModel.browserPluginPathHint() else {
            DLog("No hint")
            return false
        }
        if hint.isEmpty {
            DLog("Empty hint")
            return false
        }
        DLog("Check hint \(hint)")
        return verifyCodeSignature(at: URL(fileURLWithPath: hint), teamID: teamID)
    }

    private static func verifyApp(bundleID: String, teamID: String) -> Bool {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            RLog("Error: No app found with bundle ID '\(bundleID)'")
            return false
        }

        RLog("Found app at: \(appURL.path)")
        return verifyCodeSignature(at: appURL, teamID: teamID)
    }

    private static func verifyCodeSignature(at url: URL, teamID: String) -> Bool {
        DLog("Verify that \(url) has signature with team \(teamID)")
        var staticCode: SecStaticCode?

        // Create a static code object from the app URL
        let result = SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode)
        guard result == errSecSuccess, let code = staticCode else {
            RLog("Error: Failed to create static code object (OSStatus: \(result))")
            return false
        }

        // Create requirement string for team ID verification
        let requirementString = "anchor apple generic and certificate leaf[subject.OU] = \"\(teamID)\""

        var requirement: SecRequirement?
        let reqResult = SecRequirementCreateWithString(requirementString as CFString, [], &requirement)
        guard reqResult == errSecSuccess, let req = requirement else {
            RLog("Error: Failed to create requirement (OSStatus: \(reqResult))")
            return false
        }

        // Verify the code signature with the requirement
        let verifyResult = SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: 0), req)

        if verifyResult == errSecSuccess {
            DLog("OK")
            return true
        } else {
            let reason = SecCopyErrorMessageString(verifyResult, nil) as String?
            RLog("Invalid: Error code \(verifyResult): \(reason.d)")
            return false
        }
    }
}
