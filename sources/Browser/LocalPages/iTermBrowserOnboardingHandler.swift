//
//  iTermBrowserOnboardingHandler.swift
//  iTerm2
//
//  Created for iTerm2 Browser onboarding flow
//

import Foundation
@preconcurrency import WebKit

struct iTermBrowserOnboardingSettings {
    let adBlockerEnabled: Bool
    let instantReplayEnabled: Bool
}

protocol iTermBrowserOnboardingHandlerDelegate: AnyObject {
    @MainActor func onboardingHandlerEnableAdBlocker(_ handler: iTermBrowserOnboardingHandler)
    @MainActor func onboardingHandlerEnableInstantReplay(_ handler: iTermBrowserOnboardingHandler) 
    @MainActor func onboardingHandlerCreateBrowserProfile(_ handler: iTermBrowserOnboardingHandler) -> String?
    @MainActor func onboardingHandlerSwitchToProfile(_ handler: iTermBrowserOnboardingHandler, guid: String)
    @MainActor func onboardingHandlerCheckBrowserProfileExists(_ handler: iTermBrowserOnboardingHandler) -> Bool
    @MainActor func onboardingHandlerFindBrowserProfileGuid(_ handler: iTermBrowserOnboardingHandler) -> String?
    @MainActor func onboardingHandlerGetSettings(_ handler: iTermBrowserOnboardingHandler) -> iTermBrowserOnboardingSettings
}

@objc(iTermBrowserOnboardingHandler)
@MainActor
class iTermBrowserOnboardingHandler: NSObject, iTermBrowserPageHandler {
    static let setupURL = URL(string: "\(iTermBrowserSchemes.about):onboarding-setup")!
    static let profileURL = URL(string: "\(iTermBrowserSchemes.about):onboarding-profile")!

    weak var delegate: iTermBrowserOnboardingHandlerDelegate?
    private let secret: String
    private let user: iTermBrowserUser
    private var createdProfileGuid: String?

    init(user: iTermBrowserUser) {
        self.user = user
        guard let secret = String.makeSecureHexString() else {
            it_fatalError("Failed to generate secure hex string for onboarding handler")
        }
        self.secret = secret
        super.init()
    }

    // MARK: - iTermBrowserPageHandler

    func start(urlSchemeTask: WKURLSchemeTask, url: URL) {
        // Determine which template to load based on URL
        let templateName: String
        if url == Self.profileURL {
            templateName = "onboarding-profile"
        } else {
            templateName = "onboarding-setup"
        }
        
        let substitutions = url == Self.profileURL ? profileSubstitutions() : setupSubstitutions()
        let htmlToServe = iTermBrowserTemplateLoader.loadTemplate(
            named: templateName,
            type: "html",
            substitutions: substitutions
        )

        guard let data = htmlToServe.data(using: .utf8) else {
            urlSchemeTask.didFailWithError(NSError(domain: "iTermBrowserOnboardingHandler", code: -1, userInfo: [NSLocalizedDescriptionKey: String(localized: "ui.swift.browser.localpages.itermbrowseronboardinghandler.failed_to_encode_html.c166d582", defaultValue: "Failed to encode HTML", bundle: .main, comment: "User-facing text in iTermBrowserOnboardingHandler.")]))
            return
        }

        let response = URLResponse(url: url, mimeType: "text/html", expectedContentLength: data.count, textEncodingName: "utf-8")
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    // MARK: - Message Handling

    func handleOnboardingMessage(_ message: [String: Any], webView: iTermBrowserWebView) {
        guard let action = message["action"] as? String,
              let sessionSecret = message["sessionSecret"] as? String,
              sessionSecret == secret else {
            RLog("Invalid or missing session secret for onboarding action")
            return
        }

        switch action {
        case "enableAdBlocker":
            delegate?.onboardingHandlerEnableAdBlocker(self)
            updateUIStatus("adblocker-status", enabled: true, webView: webView)

        case "enableInstantReplay":
            delegate?.onboardingHandlerEnableInstantReplay(self)
            updateUIStatus("replay-status", enabled: true, webView: webView)

        case "createBrowserProfile":
            if let guid = delegate?.onboardingHandlerCreateBrowserProfile(self) {
                createdProfileGuid = guid
                let script = "onProfileCreated(true);"
                Task { @MainActor in
                    _ = try? await webView.safelyEvaluateJavaScript(iife(script), contentWorld: .page)
                }
            } else {
                // Profile already existed
                createdProfileGuid = delegate?.onboardingHandlerFindBrowserProfileGuid(self)
                let script = "onProfileCreated(false);"
                Task { @MainActor in
                    _ = try? await webView.safelyEvaluateJavaScript(iife(script), contentWorld: .page)
                }
            }
            
        case "checkProfileExists":
            let exists = delegate?.onboardingHandlerCheckBrowserProfileExists(self) ?? false
            if exists {
                createdProfileGuid = delegate?.onboardingHandlerFindBrowserProfileGuid(self)
                let script = "onProfileCreated(false);" // false means it already existed
                Task { @MainActor in
                    _ = try? await webView.safelyEvaluateJavaScript(iife(script), contentWorld: .page)
                }
            }
            
        case "switchToProfile":
            if let guid = createdProfileGuid ?? delegate?.onboardingHandlerFindBrowserProfileGuid(self) {
                delegate?.onboardingHandlerSwitchToProfile(self, guid: guid)
            } else {
                RLog("No browser profile found to switch to")
            }
            
        case "getSettingsStatus":
            sendSettingsStatus(to: webView)
            
        case "completeOnboarding":
            iTermUserDefaults.userDefaults().set(true, forKey: "NoSyncBrowserOnboardingCompleted")

        default:
            RLog("Unknown onboarding action: \(action)")
        }
    }

    private func updateUIStatus(_ statusId: String, enabled: Bool, webView: iTermBrowserWebView) {
        let script = "updateStatus('\(statusId)', \(enabled));"
        Task { @MainActor in
            _ = try? await webView.safelyEvaluateJavaScript(iife(script), contentWorld: .page)
        }
    }
    
    private func sendSettingsStatus(to webView: iTermBrowserWebView) {
        let settings = delegate?.onboardingHandlerGetSettings(self) ?? iTermBrowserOnboardingSettings(adBlockerEnabled: false, instantReplayEnabled: false)
        let profileExists = delegate?.onboardingHandlerCheckBrowserProfileExists(self) ?? false
        
        let script = """
        updateInitialStatus({
            adBlockerEnabled: \(settings.adBlockerEnabled),
            instantReplayEnabled: \(settings.instantReplayEnabled),
            profileExists: \(profileExists)
        });
        """
        Task { @MainActor in
            _ = try? await webView.safelyEvaluateJavaScript(iife(script), contentWorld: .page)
        }
    }
    
    func injectJavaScript(into webView: iTermBrowserWebView) {

    }

    func resetState() {

    }

    private func profileSubstitutions() -> [String: String] {
        return [
            "SECRET": secret,
            "HTML_LANG": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.common.language_code", defaultValue: "en"),
            "PAGE_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.profile.page_title", defaultValue: "iTerm2 Browser - Create Profile"),
            "TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.profile.title", defaultValue: "First Things First"),
            "SUBTITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.profile.subtitle", defaultValue: "Let's create a browser profile to get started"),
            "PROFILE_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.profile.profile_title", defaultValue: "Create Your Browser Profile"),
            "PROFILE_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.profile.profile_description", defaultValue: "A browser profile stores all your preferences and settings specifically for web browsing. This keeps your terminal and browser configurations separate and organized."),
            "CREATE_PROFILE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.profile.create_profile", defaultValue: "Create Browser Profile"),
            "SUCCESS": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.profile.success", defaultValue: "Success!"),
            "SUCCESS_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.profile.success_description", defaultValue: "Your browser profile has been created. You can now continue to configure your browsing experience."),
            "NOTE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.profile.note", defaultValue: "Note:"),
            "NOTE_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.profile.note_description", defaultValue: "You can create multiple browser profiles with different settings for different use cases. Each profile can have its own keyboard shortcuts and browser-specific configurations."),
            "BACK": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.common.back", defaultValue: "Back"),
            "CONTINUE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.profile.continue", defaultValue: "Continue to Setup"),
            "PROFILE_CREATED_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.onboarding.profile.status.created", defaultValue: "✓ Profile Created"),
            "PROFILE_EXISTS_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.onboarding.profile.status.exists", defaultValue: "✓ Profile Exists"),
            "PROFILE_ALREADY_EXISTS_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.onboarding.profile.status.already_exists", defaultValue: "A browser profile already exists. You can continue to the next step.")
        ]
    }

    private func setupSubstitutions() -> [String: String] {
        return [
            "SECRET": secret,
            "HTML_LANG": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.common.language_code", defaultValue: "en"),
            "PAGE_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.setup.page_title", defaultValue: "iTerm2 Browser - Setup"),
            "TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.setup.title", defaultValue: "Let’s Get You Set Up"),
            "SUBTITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.setup.subtitle", defaultValue: "Quick configuration to get the most out of your browser"),
            "AD_BLOCKER": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.setup.ad_blocker.title", defaultValue: "Ad Blocker"),
            "DISABLED": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.setup.status.disabled", defaultValue: "Disabled"),
            "AD_BLOCKER_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.setup.ad_blocker.description", defaultValue: "Blocks ads and trackers using WebKit content blockers. Improves browsing speed and privacy without sacrificing compatibility. If enabled, a new block list will be downloaded from the internet once a day."),
            "ENABLE_AD_BLOCKER": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.setup.ad_blocker.enable", defaultValue: "Enable Ad Blocker"),
            "INSTANT_REPLAY": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.setup.instant_replay.title", defaultValue: "Instant Replay"),
            "INSTANT_REPLAY_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.setup.instant_replay.description", defaultValue: "Instant Replay keeps a rolling screen recording of your browser window, storing only the most recent contents. If you miss something, launch the player to review what was on the screen. Requires screen recording permission."),
            "ENABLE_INSTANT_REPLAY": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.setup.instant_replay.enable", defaultValue: "Enable Instant Replay"),
            "TIP": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.setup.tip", defaultValue: "Tip:"),
            "TIP_PREFIX": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.setup.tip.prefix", defaultValue: "To view or change browser settings, go to"),
            "PREFERENCES_PATH": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.setup.tip.preferences_path", defaultValue: "Preferences → Profiles → Web"),
            "TIP_INFIX": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.setup.tip.infix", defaultValue: "or by clicking the ☰ button in the browser toolbar and then select"),
            "SETTINGS": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.welcome.settings", defaultValue: "Settings"),
            "TIP_SUFFIX": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.setup.tip.suffix", defaultValue: "."),
            "BACK": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.common.back", defaultValue: "Back"),
            "START_BROWSING": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.setup.start_browsing", defaultValue: "Start Browsing"),
            "ENABLED_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.onboarding.setup.status.enabled", defaultValue: "Enabled"),
            "DISABLED_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.onboarding.setup.status.disabled", defaultValue: "Disabled"),
            "CREATED_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.onboarding.setup.status.created", defaultValue: "Created"),
            "NOT_CREATED_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.onboarding.setup.status.not_created", defaultValue: "Not Created"),
            "DONE_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.onboarding.setup.status.done", defaultValue: "✓ Done")
        ]
    }
}
