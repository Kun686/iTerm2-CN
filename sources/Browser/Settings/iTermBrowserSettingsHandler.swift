//
//  iTermBrowserSettingsHandler.swift
//  iTerm2
//
//  Created by George Nachman on 6/18/25.
//

import Foundation
@preconcurrency import WebKit
import WebExtensionsFramework
import AppKit

protocol iTermBrowserSettingsHandlerDelegate: AnyObject {
    @MainActor func settingsHandlerDidUpdateAdblockSettings(_ handler: iTermBrowserSettingsHandler)
    @MainActor func settingsHandlerDidRequestAdblockUpdate(_ handler: iTermBrowserSettingsHandler)
    @MainActor func settingsHandlerWebView(_ handler: iTermBrowserSettingsHandler) -> iTermBrowserWebView?
    @MainActor func settingsHandlerExtensionManager(_ handler: iTermBrowserSettingsHandler) -> iTermBrowserExtensionManagerProtocol?
    @MainActor func settingsHandlerOpenPasswordManager(_ handler: iTermBrowserSettingsHandler)
}

@objc(iTermBrowserSettingsHandler)
@MainActor
class iTermBrowserSettingsHandler: NSObject, iTermBrowserPageHandler {
    static let settingsURL = URL(string: "\(iTermBrowserSchemes.about):settings")!
    weak var delegate: iTermBrowserSettingsHandlerDelegate?
    private let secret: String
    private let user: iTermBrowserUser
    
    init(user: iTermBrowserUser) {
        self.user = user
        guard let secret = String.makeSecureHexString() else {
            it_fatalError("Failed to generate secure hex string for settings handler")
        }
        self.secret = secret
        super.init()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Interface
    
    func generateSettingsHTML() -> String {
        let isDevNull = (user == .devNull)
        
        // Whether to show the extensions row. Only wired up in debug builds; in
        // release builds it is always hidden. Computing the style per config
        // (rather than a ternary on an always-false flag) avoids a
        // "will never be executed" warning on the dead branch in release builds.
#if ITERM_DEBUG
        var showExtensions = false
        if #available(macOS 14, *) {
            showExtensions = true
        }
        let showExtensionsStyle = showExtensions ? "" : "display: none;"
#else
        let showExtensionsStyle = "display: none;"
#endif
        
        let substitutions = [
            "ADBLOCK_ENABLED": iTermAdvancedSettingsModel.webKitAdblockEnabled() ? "checked" : "",
            "ADBLOCK_URL": iTermAdvancedSettingsModel.adblockListURL().replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;"),
            "SECRET": secret,
            "DEV_NULL_NOTE": isDevNull ? "" : "display: none;",
            "SHOW_EXTENSIONS": showExtensionsStyle,
            "HTML_LANG": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.common.language_code", defaultValue: "en"),
            "PAGE_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.title", defaultValue: "Browser Settings"),
            "PRIVACY_AND_DATA": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.privacy.section", defaultValue: "Privacy & Data"),
            "DEV_NULL_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.dev_null.title", defaultValue: "/dev/null Mode Active"),
            "DEV_NULL_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.dev_null.description", defaultValue: "This profile is in /dev/null mode. Cookies, history, and all other browser data are stored in RAM and will be lost when the tab is closed."),
            "CLEAR_ALL_COOKIES_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.cookies.clear.title", defaultValue: "Clear All Cookies"),
            "CLEAR_ALL_COOKIES_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.cookies.clear.description", defaultValue: "Remove all stored cookies from websites"),
            "CLEAR_COOKIES": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.cookies.clear.action", defaultValue: "Clear Cookies"),
            "CLEAR_WEBSITE_DATA_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.website_data.clear.title", defaultValue: "Clear Website Data"),
            "CLEAR_WEBSITE_DATA_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.website_data.clear.description", defaultValue: "Remove cookies, cache, and local storage"),
            "CLEAR_ALL_DATA": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.website_data.clear.action", defaultValue: "Clear All Data"),
            "SITE_PERMISSIONS": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.permissions.section", defaultValue: "Site Permissions"),
            "MANAGE_SITE_PERMISSIONS_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.permissions.manage.title", defaultValue: "Manage Site Permissions"),
            "MANAGE_SITE_PERMISSIONS_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.permissions.manage.description", defaultValue: "View and revoke permissions granted to websites (camera, microphone, location, notifications)"),
            "MANAGE_PERMISSIONS": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.permissions.manage.action", defaultValue: "Manage Permissions"),
            "SAVED_PASSWORDS": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.passwords.section", defaultValue: "Saved Passwords"),
            "MANAGE_SAVED_PASSWORDS_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.passwords.manage.title", defaultValue: "Manage Saved Passwords"),
            "MANAGE_SAVED_PASSWORDS_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.passwords.manage.description", defaultValue: "Open the password manager to view or remove website usernames and passwords, including those remembered for HTTP authentication"),
            "MANAGE_PASSWORDS": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.passwords.manage.action", defaultValue: "Manage Passwords"),
            "LINK_OPENING": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.link_opening.section", defaultValue: "Link Opening"),
            "OPEN_LINKS_FROM_TERMINAL_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.link_opening.terminal.title", defaultValue: "Open Links From Terminal"),
            "OPEN_LINKS_FROM_TERMINAL_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.link_opening.terminal.description", defaultValue: "Choose where links from the terminal should open"),
            "ALWAYS_ASK": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.link_opening.option.ask", defaultValue: "Always Ask"),
            "BUILT_IN_BROWSER": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.link_opening.option.builtin", defaultValue: "Built-in Browser"),
            "DEFAULT_BROWSER": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.link_opening.option.default", defaultValue: "Default Browser"),
            "SEARCH_ENGINE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.search.section", defaultValue: "Search Engine"),
            "DEFAULT_SEARCH_ENGINE_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.search.default.title", defaultValue: "Default Search Engine"),
            "DEFAULT_SEARCH_ENGINE_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.search.default.description", defaultValue: "Choose your preferred search engine for web searches"),
            "CUSTOM": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.search.option.custom", defaultValue: "Custom"),
            "CUSTOM_SEARCH_URL_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.search.custom_url.title", defaultValue: "Custom Search URL"),
            "CUSTOM_SEARCH_URL_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.search.custom_url.description", defaultValue: "Enter a custom search URL template. Use %@ where the search query should be inserted."),
            "CUSTOM_SUGGEST_URL_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.search.suggestions_url.title", defaultValue: "Custom Search Suggestions URL"),
            "CUSTOM_SUGGEST_URL_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.search.suggestions_url.description", defaultValue: "Optional: Enter a URL template for search suggestions (OpenSearch format). Use %@ where the search query should be inserted."),
            "AD_BLOCKING": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.adblock.section", defaultValue: "Ad Blocking"),
            "ENABLE_AD_BLOCKING_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.adblock.enable.title", defaultValue: "Enable WebKit Ad Blocking"),
            "ENABLE_AD_BLOCKING_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.adblock.enable.description", defaultValue: "Block ads using WebKit content rules (list-based blocking)"),
            "FILTER_LIST_URL_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.adblock.filter_url.title", defaultValue: "Filter List URL"),
            "FILTER_LIST_URL_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.adblock.filter_url.description", defaultValue: "URL for downloading WebKit ad blocking rules (updates daily)"),
            "UPDATE_NOW": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.adblock.update.action", defaultValue: "Update Now"),
            "FILTER_STATISTICS_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.adblock.statistics.title", defaultValue: "WebKit Filter Statistics"),
            "LOADING_FILTER_STATISTICS": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.adblock.statistics.loading", defaultValue: "Loading filter statistics…"),
            "PROXY_SETTINGS": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.proxy.section", defaultValue: "Proxy Settings"),
            "ENABLE_HTTP_PROXY_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.proxy.enable.title", defaultValue: "Enable HTTP Proxy"),
            "ENABLE_HTTP_PROXY_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.proxy.enable.description", defaultValue: "Route browser traffic through a CONNECT proxy server."),
            "PROXY_SERVER_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.proxy.server.title", defaultValue: "Proxy Server"),
            "PROXY_SERVER_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.proxy.server.description", defaultValue: "HTTP CONNECT proxy address and port"),
            "BROWSER_EXTENSIONS": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.extensions.section", defaultValue: "Browser Extensions"),
            "BROWSER_EXTENSIONS_BETA": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.extensions.beta_description", defaultValue: "This feature is still in development. It is not intended for general use yet."),
            "EXTENSIONS_DIRECTORY_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.extensions.directory.title", defaultValue: "Extensions Directory"),
            "EXTENSIONS_DIRECTORY_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.extensions.directory.description", defaultValue: "Manage your browser extensions directory location and install new extensions"),
            "REVEAL_IN_FINDER": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.settings.extensions.reveal.action", defaultValue: "Reveal in Finder"),
            "CLEAR_COOKIES_PROMPT_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.settings.confirm.clear_cookies", defaultValue: "This will remove all cookies. Continue?"),
            "CLEAR_ALL_DATA_PROMPT_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.settings.confirm.clear_all_data", defaultValue: "This will remove all browsing data including cookies, cache, and local storage. Continue?"),
            "UPDATING_AD_BLOCK_RULES_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.settings.adblock.status.updating", defaultValue: "Updating ad block rules…"),
            "NO_FILTER_RULES_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.settings.adblock.statistics.empty", defaultValue: "No filter rules loaded"),
            "FILTER_RULES_LOADED_FORMAT_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.settings.adblock.statistics.loaded_format", defaultValue: "%1$@ filter rules loaded"),
            "UPDATED_LAST_HOUR_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.settings.adblock.statistics.updated_last_hour", defaultValue: "(updated in the last hour)"),
            "UPDATED_HOURS_AGO_FORMAT_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.settings.adblock.statistics.updated_hours_ago_format", defaultValue: "(updated %1$@ hours ago)"),
            "UPDATED_DAYS_AGO_FORMAT_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.settings.adblock.statistics.updated_days_ago_format", defaultValue: "(updated %1$@ days ago)"),
            "NO_EXTENSIONS_TITLE_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.settings.extensions.empty.title", defaultValue: "No Extensions Found"),
            "NO_EXTENSIONS_DESCRIPTION_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.settings.extensions.empty.description", defaultValue: "No browser extensions are currently installed. Extensions should be placed in your extensions directory as configured in your profile preferences."),
            "NO_DESCRIPTION_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.settings.extensions.no_description", defaultValue: "No description available"),
            "UNKNOWN_VERSION_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.settings.extensions.unknown_version", defaultValue: "Unknown version"),
            "VERSION_FORMAT_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.settings.extensions.version_format", defaultValue: "Version %1$@"),
            "PERMISSIONS_FORMAT_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.settings.extensions.permissions_format", defaultValue: "%1$@ permissions"),
            "HOST_PERMISSIONS_FORMAT_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.settings.extensions.host_permissions_format", defaultValue: "%1$@ host permissions")
        ]
        
        return iTermBrowserTemplateLoader.loadTemplate(named: "settings-page",
                                                       type: "html",
                                                       substitutions: substitutions)
    }
    
    func start(urlSchemeTask: WKURLSchemeTask, url: URL) {
        let htmlToServe = generateSettingsHTML()
        
        guard let data = htmlToServe.data(using: .utf8) else {
            urlSchemeTask.didFailWithError(NSError(domain: "iTermBrowserSettingsHandler", code: -1, userInfo: [NSLocalizedDescriptionKey: String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.failed_to_encode_html.c166d582", defaultValue: "Failed to encode HTML", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler.")]))
            return
        }
        
        let response = URLResponse(url: url, mimeType: "text/html", expectedContentLength: data.count, textEncodingName: "utf-8")
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }
    
    func injectSettingsJavaScript(into webView: iTermBrowserWebView) {
        let clearCookiesPrompt = String(
            localized: "ui.browser.settings.confirm.clear_cookies",
            defaultValue: "This will remove all cookies from all websites. Continue?",
            bundle: .main,
            comment: "Confirmation before clearing all browser cookies.")
        let clearAllDataPrompt = String(
            localized: "ui.browser.settings.confirm.clear_all_data",
            defaultValue: "This will remove all browsing data including cookies, cache, and local storage. Continue?",
            bundle: .main,
            comment: "Confirmation before clearing all browser data.")
        let clearCookiesPromptJSON =
            iTermBrowserTemplateLoader.javaScriptStringLiteral(clearCookiesPrompt)
        let clearAllDataPromptJSON =
            iTermBrowserTemplateLoader.javaScriptStringLiteral(clearAllDataPrompt)
        let script = """
        // Direct functions that call Swift
        window.clearCookies = function() {
            if (confirm(\(clearCookiesPromptJSON))) {
                window.webkit.messageHandlers['\(iTermBrowserSchemes.about):settings'].postMessage({action: 'clearCookies'});
            }
        };
        
        window.clearAllData = function() {
            if (confirm(\(clearAllDataPromptJSON))) {
                window.webkit.messageHandlers['\(iTermBrowserSchemes.about):settings'].postMessage({action: 'clearAllData'});
            }
        };
        
        """
        
        Task { @MainActor in
            _ = try? await webView.safelyEvaluateJavaScript(iife(script), contentWorld: .page)
        }
    }
    
    func handleSettingsMessage(_ message: [String: Any], webView: iTermBrowserWebView) {
        guard let action = message["action"] as? String,
              let sessionSecret = message["sessionSecret"] as? String,
              sessionSecret == secret else {
            RLog("Invalid or missing session secret for settings action")
            return
        }
        
        switch action {
        case "clearCookies":
            clearCookies(webView: webView)
        case "clearAllData":
            clearAllWebsiteData(webView: webView)
        case "setAdblockEnabled":  // webkit
            if let enabled = message["value"] as? Bool {
                setAdblockEnabled(enabled, webView: webView)
            }
        case "setAdblockURL":
            if let url = message["value"] as? String {
                setAdblockURL(url, webView: webView)
            }
        case "setSearchCommand":
            if let url = message["value"] as? String {
                setSearchCommand(url, webView: webView)
            }
        case "setSearchSuggestURL":
            if let url = message["value"] as? String {
                setSearchSuggestURL(url, webView: webView)
            }
        case "forceAdblockUpdate":
            forceAdblockUpdate(webView: webView)
        case "getAdblockSettings":
            sendAdblockSettings(to: webView)
        case "getSearchSettings":
            sendSearchSettings(to: webView)
        case "getAdblockStats":
            sendAdblockStats(to: webView)
        case "setProxyEnabled":
            if let enabled = message["value"] as? Bool {
                setProxyEnabled(enabled, webView: webView)
            }
        case "setProxyHost":
            if let host = message["value"] as? String {
                setProxyHost(host, webView: webView)
            }
        case "setProxyPort":
            if let port = message["value"] as? Int {
                setProxyPort(port, webView: webView)
            }
        case "getProxySettings":
            sendProxySettings(to: webView)
        case "getExtensions":
#if ITERM_DEBUG
            if #available(macOS 14, *) {
                sendExtensions(to: webView)
            }
#endif
        case "setExtensionEnabled":
#if ITERM_DEBUG
            if #available(macOS 14, *) {
                if let extensionId = message["extensionId"] as? String,
                   let enabled = message["enabled"] as? Bool {
                    setExtensionEnabled(extensionId, enabled: enabled, webView: webView)
                }
            }
#endif
        case "revealExtensionsDirectory":
#if ITERM_DEBUG
            if #available(macOS 14, *) {
                revealExtensionsDirectory(webView: webView)
            }
#endif
        case "openPasswordManager":
            delegate?.settingsHandlerOpenPasswordManager(self)
        case "setLinkOpeningPreference":
            if let preference = message["value"] as? String {
                setLinkOpeningPreference(preference, webView: webView)
            }
        case "getLinkOpeningPreference":
            sendLinkOpeningPreference(to: webView)
        default:
            break
        }
    }
    
    private func clearCookies(webView: iTermBrowserWebView) {
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        cookieStore.getAllCookies { cookies in
            for cookie in cookies {
                cookieStore.delete(cookie) {
                    DLog("Cookie deleted")
                }
            }
        }
    }
    
    private func clearAllWebsiteData(webView: iTermBrowserWebView) {
        let websiteDataStore = webView.configuration.websiteDataStore
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        
        websiteDataStore.removeData(ofTypes: dataTypes, modifiedSince: Date(timeIntervalSince1970: 0)) {
            let user = self.user
            Task {
                let message: String
                if await BrowserDatabase.instance(for: user)?.erase() == true {
                    message = String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.all_website_data_has_been_cleared_successfully.4be6bca3", defaultValue: "All website data has been cleared successfully!", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler.")
                } else {
                    if let url = BrowserDatabaseCollection.url(for: user) {
                        message = String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.the_browser_database_could_not_be_deleted_it.d8290d7a", defaultValue: "The browser database could not be deleted. It is in \(url.path)", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler.")
                    } else {
                        message = String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.the_browser_database_could_not_be_deleted_your.f05136fa", defaultValue: "The browser database could not be deleted. Your application support folder could not be found.", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler.")
                    }
                }
                DispatchQueue.main.async {
                    Task { @MainActor in
                        let literal = iTermBrowserTemplateLoader.javaScriptStringLiteral(message)
                        _ = try? await webView.safelyEvaluateJavaScript(
                            iife("alert(\(literal));"),
                            contentWorld: .page)
                    }
                }
            }
        }
    }
    
    // MARK: - Adblock Settings

    // This is for webkit adblocking
    private func setAdblockEnabled(_ enabled: Bool, webView: iTermBrowserWebView) {
        iTermAdvancedSettingsModel.setWebKitAdblockEnabled(enabled)
        delegate?.settingsHandlerDidUpdateAdblockSettings(self)
        
        RLog("Ad blocking \(enabled ? "enabled" : "disabled")")
        
        let message = enabled ? String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.ad_blocking_enabled.76d964e1", defaultValue: "Ad blocking enabled", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler.") : String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.ad_blocking_disabled.687a8706", defaultValue: "Ad blocking disabled", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler.")
        showStatusMessage(message, type: "success", in: webView)
    }
    
    private func setAdblockURL(_ url: String, webView: iTermBrowserWebView) {
        guard !url.isEmpty else { return }
        
        iTermAdvancedSettingsModel.setAdblockListURL(url)
        delegate?.settingsHandlerDidUpdateAdblockSettings(self)
        
        DLog("Ad block URL updated to: \(url)")
        showStatusMessage(String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.filter_list_url_updated.c08928ec", defaultValue: "Filter list URL updated", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."), type: "success", in: webView)
    }
    
    private func forceAdblockUpdate(webView: iTermBrowserWebView) {
        delegate?.settingsHandlerDidRequestAdblockUpdate(self)
        RLog("Force update of ad block rules requested")
    }
    
    private func sendAdblockSettings(to webView: iTermBrowserWebView) {
        let enabled = iTermAdvancedSettingsModel.webKitAdblockEnabled()
        let url = iTermAdvancedSettingsModel.adblockListURL() ?? ""
        
        let settings = [
            "enabled": enabled,
            "url": url
        ] as [String: Any]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: settings)
            let jsonString = String(data: jsonData, encoding: .utf8)!
            
            let script = "updateAdblockUI(\(jsonString));"
            Task { @MainActor in
            _ = try? await webView.safelyEvaluateJavaScript(iife(script), contentWorld: .page)
        }
        } catch {
            RLog("Failed to encode adblock settings: \(error)")
        }
    }
    
    private func sendAdblockStats(to webView: iTermBrowserWebView) {
        let ruleCount = iTermBrowserAdblockManager.shared.getRuleCount()
        let lastUpdate = iTermUserDefaults.userDefaults().object(forKey: "NoSyncAdblockLastUpdate") as? Date
        
        let stats = [
            "ruleCount": ruleCount,
            "lastUpdate": lastUpdate?.timeIntervalSince1970 ?? 0
        ] as [String: Any]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: stats)
            let jsonString = String(data: jsonData, encoding: .utf8)!
            
            let script = "updateAdblockStats(\(jsonString));"
            Task { @MainActor in
            _ = try? await webView.safelyEvaluateJavaScript(iife(script), contentWorld: .page)
        }
        } catch {
            DLog("Failed to encode adblock stats: \(error)")
        }
    }
    
    private func showStatusMessage(_ message: String, type: String, in webView: iTermBrowserWebView) {
        let messageLiteral = iTermBrowserTemplateLoader.javaScriptStringLiteral(message)
        let typeLiteral = iTermBrowserTemplateLoader.javaScriptStringLiteral(type)
        let script = "showStatus(\(messageLiteral), \(typeLiteral));"
        Task { @MainActor in
            _ = try? await webView.safelyEvaluateJavaScript(iife(script), contentWorld: .page)
        }
    }
    
    @objc func showAdblockUpdateSuccess(in webView: iTermBrowserWebView) {
        showStatusMessage(String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.ad_block_rules_updated_successfully.24e9433f", defaultValue: "Ad block rules updated successfully", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."), type: "success", in: webView)
    }
    
    @objc func showAdblockUpdateError(_ error: String, in webView: iTermBrowserWebView) {
        showStatusMessage(String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.failed_to_update_ad_block_rules_0.2d43e2be", defaultValue: "Failed to update ad block rules: \(error)", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."), type: "error", in: webView)
    }
    
    // MARK: - Search Settings
    
    private func setSearchCommand(_ url: String, webView: iTermBrowserWebView) {
        guard !url.isEmpty, url.contains("%@") else {
            showStatusMessage(String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.invalid_search_url_must_contain_placeholder.79de23de", defaultValue: "Invalid search URL: must contain %@ placeholder", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."), type: "error", in: webView)
            return
        }
        
        iTermAdvancedSettingsModel.setSearchCommand(url)
        DLog("Search command updated to: \(url)")
        showStatusMessage(String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.search_engine_updated.bc77fd62", defaultValue: "Search engine updated", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."), type: "success", in: webView)
    }
    
    private func setSearchSuggestURL(_ url: String, webView: iTermBrowserWebView) {
        if !url.isEmpty && !url.contains("%@") {
            showStatusMessage(String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.invalid_suggestion_url_must_contain_placeholder.e4a176e2", defaultValue: "Invalid suggestion URL: must contain %@ placeholder", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."), type: "error", in: webView)
            return
        }
        
        iTermAdvancedSettingsModel.setSearchSuggestURL(url)
        DLog("Search suggestion URL updated to: \(url.isEmpty ? "disabled" : url)")
        if url.isEmpty {
            showStatusMessage(String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.search_suggestions_disabled.0ac1405e", defaultValue: "Search suggestions disabled", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."), type: "success", in: webView)
        } else {
            showStatusMessage(String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.search_suggestions_updated.dbe5408a", defaultValue: "Search suggestions updated", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."), type: "success", in: webView)
        }
    }
    
    private func sendSearchSettings(to webView: iTermBrowserWebView) {
        let searchCommand = iTermAdvancedSettingsModel.searchCommand()!
        let searchSuggestURL = iTermAdvancedSettingsModel.searchSuggestURL()!
        
        let settings = [
            "searchCommand": searchCommand,
            "searchSuggestURL": searchSuggestURL
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: settings)
            let jsonString = String(data: jsonData, encoding: .utf8)!
            
            let script = "updateSearchEngineUI(\(jsonString));"
            Task { @MainActor in
            _ = try? await webView.safelyEvaluateJavaScript(iife(script), contentWorld: .page)
        }
        } catch {
            DLog("Failed to encode search settings: \(error)")
        }
    }
    
    // MARK: - Proxy Settings
    
    private func setProxyEnabled(_ enabled: Bool, webView: iTermBrowserWebView) {
        iTermAdvancedSettingsModel.setBrowserProxyEnabled(enabled)
        
        RLog("Browser proxy \(enabled ? "enabled" : "disabled")")
        
        let message = enabled ? String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.proxy_enabled.474f3f1d", defaultValue: "Proxy enabled", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler.") : String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.proxy_disabled.b73022a5", defaultValue: "Proxy disabled", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler.")
        showStatusMessage(message, type: "success", in: webView)
        
        // Notify delegate to reconfigure webview if needed
        delegate?.settingsHandlerDidUpdateAdblockSettings(self)
    }
    
    private func setProxyHost(_ host: String, webView: iTermBrowserWebView) {
        guard !host.isEmpty else { return }
        
        iTermAdvancedSettingsModel.setBrowserProxyHost(host)
        
        DLog("Browser proxy host updated to: \(host)")
        showStatusMessage(String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.proxy_host_updated.e5ec5ef5", defaultValue: "Proxy host updated", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."), type: "success", in: webView)
        
        // Notify delegate to reconfigure webview if needed
        delegate?.settingsHandlerDidUpdateAdblockSettings(self)
    }
    
    private func setProxyPort(_ port: Int, webView: iTermBrowserWebView) {
        guard port >= 1 && port <= 65535 else {
            showStatusMessage(String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.invalid_port_number.2cf03e17", defaultValue: "Invalid port number", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."), type: "error", in: webView)
            return
        }
        
        iTermAdvancedSettingsModel.setBrowserProxyPort(Int32(port))
        
        DLog("Browser proxy port updated to: \(port)")
        showStatusMessage(String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.proxy_port_updated.2a53bd9a", defaultValue: "Proxy port updated", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."), type: "success", in: webView)
        
        // Notify delegate to reconfigure webview if needed
        delegate?.settingsHandlerDidUpdateAdblockSettings(self)
    }
    
    private func sendProxySettings(to webView: iTermBrowserWebView) {
        let enabled = iTermAdvancedSettingsModel.browserProxyEnabled()
        let host = iTermAdvancedSettingsModel.browserProxyHost() ?? "127.0.0.1"
        let port = iTermAdvancedSettingsModel.browserProxyPort()
        
        let settings = [
            "enabled": enabled,
            "host": host,
            "port": port
        ] as [String: Any]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: settings)
            let jsonString = String(data: jsonData, encoding: .utf8)!
            
            let script = "updateProxyUI(\(jsonString));"
            Task { @MainActor in
            _ = try? await webView.safelyEvaluateJavaScript(iife(script), contentWorld: .page)
        }
        } catch {
            DLog("Failed to encode proxy settings: \(error)")
        }
    }
    
    // MARK: - Extension Settings
    
    private func sendExtensions(to webView: iTermBrowserWebView) {
        if #available(macOS 14, *) {
            sendExtensionsForMacOS14(to: webView)
        } else {
            // Extensions not supported on macOS < 14
            let script = "updateExtensionsUI([]);"
            Task { @MainActor in
            _ = try? await webView.safelyEvaluateJavaScript(iife(script), contentWorld: .page)
        }
        }
    }
    
    @available(macOS 14, *)
    private func sendExtensionsForMacOS14(to webView: iTermBrowserWebView) {
        guard let extensionManager = delegate?.settingsHandlerExtensionManager(self) else {
            // Send empty array if extension manager is not available
            let script = "updateExtensionsUI([]);"
            Task { @MainActor in
            _ = try? await webView.safelyEvaluateJavaScript(iife(script), contentWorld: .page)
        }
            return
        }
        
        let availableExtensions = extensionManager.availableExtensions
        
        let extensionsData = availableExtensions.map { browserExtension in
            let manifest = browserExtension.manifest
            return [
                "id": browserExtension.id.stringValue,
                "name": manifest.name,
                "description": manifest.description ?? String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.no_description_available.aab5e3e7", defaultValue: "No description available", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."),
                "version": manifest.version,
                "permissions": manifest.permissions ?? [],
                "hostPermissions": manifest.hostPermissions ?? [],
                "enabled": extensionManager.extensionEnabled(id: browserExtension.id)
            ] as [String: Any]
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: extensionsData)
            let jsonString = String(data: jsonData, encoding: .utf8)!
            
            let script = "updateExtensionsUI(\(jsonString));"
            Task { @MainActor in
            _ = try? await webView.safelyEvaluateJavaScript(script, contentWorld: .page)
        }
        } catch {
            DLog("Failed to encode extensions data: \(error)")
            let script = "updateExtensionsUI([]);"
            Task { @MainActor in
            _ = try? await webView.safelyEvaluateJavaScript(script, contentWorld: .page)
        }
        }
    }
    
    private func setExtensionEnabled(_ extensionIdString: String, enabled: Bool, webView: iTermBrowserWebView) {
        if #available(macOS 14, *) {
            setExtensionEnabledForMacOS14(extensionIdString, enabled: enabled, webView: webView)
        } else {
            showStatusMessage(String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.extensions_not_supported_on_this_macos_version.bdc76221", defaultValue: "Extensions not supported on this macOS version", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."), type: "error", in: webView)
        }
    }
    
    @available(macOS 14, *)
    private func setExtensionEnabledForMacOS14(_ extensionIdString: String, enabled: Bool, webView: iTermBrowserWebView) {
        guard let extensionManager = delegate?.settingsHandlerExtensionManager(self) else {
            showStatusMessage(String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.extension_management_not_available.0f32c794", defaultValue: "Extension management not available", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."), type: "error", in: webView)
            return
        }
        
        let extensionId = ExtensionID(stringValue: extensionIdString)
        extensionManager.set(id: extensionId, enabled: enabled)
        
        RLog("Extension \(extensionIdString) \(enabled ? "enabled" : "disabled")")
        
        let message = enabled ? String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.extension_enabled.866b8d57", defaultValue: "Extension enabled", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler.") : String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.extension_disabled.9b6d7d87", defaultValue: "Extension disabled", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler.")
        showStatusMessage(message, type: "success", in: webView)
        
        // Note: Extensions list will be automatically refreshed via delegate callback
        // when the profile observer detects the change
    }
    
    private func revealExtensionsDirectory(webView: iTermBrowserWebView) {
        if #available(macOS 14, *) {
            revealExtensionsDirectoryForMacOS14(webView: webView)
        } else {
            showStatusMessage(String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.extensions_not_supported_on_this_macos_version.bdc76221", defaultValue: "Extensions not supported on this macOS version", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."), type: "error", in: webView)
        }
    }
    
    @available(macOS 14, *)
    private func revealExtensionsDirectoryForMacOS14(webView: iTermBrowserWebView) {
        guard let extensionManager = delegate?.settingsHandlerExtensionManager(self) else {
            showStatusMessage(String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.extension_management_not_available.0f32c794", defaultValue: "Extension management not available", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."), type: "error", in: webView)
            return
        }
        
        // Get the extensions directory from the extension manager
        guard let extensionsURL = extensionManager.extensionsDirectory else {
            showStatusMessage(String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.extensions_directory_not_configured_in_profile_preferences.e9769a47", defaultValue: "Extensions directory not configured in profile preferences", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."), type: "error", in: webView)
            return
        }
        
        // Create the directory if it doesn't exist
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: extensionsURL, withIntermediateDirectories: true, attributes: nil)
            
            // Reveal in Finder
            NSWorkspace.shared.activateFileViewerSelecting([extensionsURL])
            
            DLog("Revealed extensions directory in Finder: \(extensionsURL.path)")
            showStatusMessage(String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.extensions_directory_revealed_in_finder.2045c3ec", defaultValue: "Extensions directory revealed in Finder", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."), type: "success", in: webView)
            
        } catch {
            DLog("Failed to create or reveal extensions directory: \(error)")
            showStatusMessage(String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.failed_to_create_extensions_directory_0.039e6fa5", defaultValue: "Failed to create extensions directory: \(error.localizedDescription)", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."), type: "error", in: webView)
        }
    }
    
    // MARK: - Link Opening Preference

    private func setLinkOpeningPreference(_ preference: String, webView: iTermBrowserWebView) {
        let identifier = "NoSyncOpenLinksInApp"

        switch preference {
        case "ask":
            // Unsilence the warning to allow the prompt to show again
            iTermWarning.unsilenceIdentifier(identifier)
            showStatusMessage(String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.link_opening_preference_set_to_always_ask.56d7d4bd", defaultValue: "Link opening preference set to always ask", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."), type: "success", in: webView)

        case "builtin":
            // Set permanent selection to "Open in iTerm2" (selection 1)
            iTermWarning.setIdentifier(identifier, permanentSelection: .kiTermWarningSelection1)
            showStatusMessage(String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.links_will_always_open_in_built_in_browser.ffa1e444", defaultValue: "Links will always open in built-in browser", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."), type: "success", in: webView)

        case "default":
            // Set permanent selection to "Use Default Browser" (selection 0)
            iTermWarning.setIdentifier(identifier, permanentSelection: .kiTermWarningSelection0)
            showStatusMessage(String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.links_will_always_open_in_default_browser.c56f6ab3", defaultValue: "Links will always open in default browser", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."), type: "success", in: webView)

        default:
            showStatusMessage(String(localized: "ui.swift.browser.settings.itermbrowsersettingshandler.invalid_link_opening_preference.a1d431df", defaultValue: "Invalid link opening preference", bundle: .main, comment: "User-facing text in iTermBrowserSettingsHandler."), type: "error", in: webView)
            return
        }

        RLog("Link opening preference updated to: \(preference)")
    }

    private func sendLinkOpeningPreference(to webView: iTermBrowserWebView) {
        let identifier = "NoSyncOpenLinksInApp"

        var preference = "ask"
        if let savedSelection = iTermWarning.conditionalSavedSelection(forIdentifier: identifier) {
            switch iTermWarningSelection(rawValue: savedSelection.intValue) {
            case .kiTermWarningSelection0:
                preference = "default"
            case .kiTermWarningSelection1:
                preference = "builtin"
            default:
                preference = "ask"
            }
        }

        let settings = ["preference": preference]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: settings)
            let jsonString = String(data: jsonData, encoding: .utf8)!

            let script = "updateLinkOpeningUI(\(jsonString));"
            Task { @MainActor in
                _ = try? await webView.safelyEvaluateJavaScript(script, contentWorld: .page)
            }
        } catch {
            DLog("Failed to encode link opening preference: \(error)")
        }
    }

    // MARK: - iTermBrowserPageHandler Protocol

    func injectJavaScript(into webView: iTermBrowserWebView) {
        injectSettingsJavaScript(into: webView)
    }

    func resetState() {
        // Settings handler doesn't maintain state that needs resetting
    }
}

// MARK: - iTermBrowserExtensionManagerDelegate

extension iTermBrowserSettingsHandler: iTermBrowserExtensionManagerDelegate {
    func extensionManagerDidUpdateExtensions(_ manager: iTermBrowserExtensionManagerProtocol) {
        // Refresh the extensions list in the settings UI
        guard let webView = delegate?.settingsHandlerWebView(self) else { return }
        sendExtensions(to: webView)
    }
}
