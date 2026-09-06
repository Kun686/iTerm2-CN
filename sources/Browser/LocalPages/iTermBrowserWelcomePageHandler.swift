//
//  iTermBrowserWelcomePageHandler.swift
//  iTerm2
//
//  Created by George Nachman on 1/3/25.
//

import WebKit
import Foundation

@objc protocol iTermBrowserWelcomePageHandlerDelegate: AnyObject {
    @MainActor func welcomePageHandlerDidNavigateToURL(_ handler: iTermBrowserWelcomePageHandler, url: String)
}

@objc(iTermBrowserWelcomePageHandler)
@MainActor
class iTermBrowserWelcomePageHandler: NSObject, iTermBrowserPageHandler {
    static let welcomeURL = URL(string: "\(iTermBrowserSchemes.about):welcome")!
    private let user: iTermBrowserUser
    private let secret: String
    weak var delegate: iTermBrowserWelcomePageHandlerDelegate?
    
    init?(user: iTermBrowserUser) {
        self.user = user
        guard let secret = String.makeSecureHexString() else {
            return nil
        }
        self.secret = secret
        super.init()
    }
    
    // MARK: - Public Interface
    
    func generateWelcomeHTML() -> String {
        let script = iTermBrowserTemplateLoader.loadTemplate(named: "welcome-page",
                                                             type: "js",
                                                             substitutions: [
                                                                 "SECRET": secret,
                                                                 "EMPTY_TITLE_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.welcome.empty.title", defaultValue: "Your most visited sites will appear here"),
                                                                 "EMPTY_HINT_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.welcome.empty.hint", defaultValue: "Start browsing to build your history!"),
                                                                 "VISIT_FORMAT_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.welcome.visit_format.singular", defaultValue: "%1$lld visit"),
                                                                 "VISITS_FORMAT_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.welcome.visit_format.plural", defaultValue: "%1$lld visits")
                                                             ])
        return iTermBrowserTemplateLoader.loadTemplate(named: "welcome-page",
                                                       type: "html",
                                                       substitutions: [
                                                           "HTML_LANG": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.common.language_code", defaultValue: "en"),
                                                           "PAGE_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.welcome.page_title", defaultValue: "Welcome to iTerm2 Browser"),
                                                           "WELCOME_BACK": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.welcome.title", defaultValue: "Welcome Back"),
                                                           "WELCOME_SUBTITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.welcome.subtitle", defaultValue: "Pick up where you left off"),
                                                           "TOP_SITES": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.welcome.top_sites", defaultValue: "Top Sites"),
                                                           "REFRESH": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.common.refresh", defaultValue: "Refresh"),
                                                           "QUICK_ACTIONS": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.welcome.quick_actions", defaultValue: "Quick Actions"),
                                                           "BOOKMARKS": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.bookmarks.title", defaultValue: "Bookmarks"),
                                                           "HISTORY": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.welcome.history", defaultValue: "History"),
                                                           "SETTINGS": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.welcome.settings", defaultValue: "Settings"),
                                                           "PERMISSIONS": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.welcome.permissions", defaultValue: "Permissions"),
                                                           "WELCOME_SCRIPT": script
                                                       ])
    }
    
    func start(urlSchemeTask: WKURLSchemeTask, url: URL) {
        // Check if onboarding is complete
        let onboardingCompleted = iTermUserDefaults.userDefaults().bool(forKey: "NoSyncBrowserOnboardingCompleted")
        
        if !onboardingCompleted {
            // Redirect to onboarding page
            let redirectHTML = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta http-equiv="refresh" content="0; url=iterm2-about:onboarding-intro">
            </head>
            <body>
                <script>window.location.href = "iterm2-about:onboarding-intro";</script>
            </body>
            </html>
            """
            
            guard let data = redirectHTML.data(using: .utf8) else {
                urlSchemeTask.didFailWithError(NSError(domain: "iTermBrowserWelcomePageHandler", code: -1, userInfo: [NSLocalizedDescriptionKey: String(localized: "ui.swift.browser.localpages.itermbrowserwelcomepagehandler.failed_to_encode_redirect_html.b3f62562", defaultValue: "Failed to encode redirect HTML", bundle: .main, comment: "User-facing text in iTermBrowserWelcomePageHandler.")]))
                return
            }
            
            let response = URLResponse(url: url, mimeType: "text/html", expectedContentLength: data.count, textEncodingName: "utf-8")
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
            return
        }
        
        // Onboarding is complete, show the welcome page with top sites
        let htmlToServe = generateWelcomeHTML()
        
        guard let data = htmlToServe.data(using: .utf8) else {
            urlSchemeTask.didFailWithError(NSError(domain: "iTermBrowserWelcomePageHandler", code: -1, userInfo: [NSLocalizedDescriptionKey: String(localized: "ui.swift.browser.localpages.itermbrowserwelcomepagehandler.failed_to_encode_html.c166d582", defaultValue: "Failed to encode HTML", bundle: .main, comment: "User-facing text in iTermBrowserWelcomePageHandler.")]))
            return
        }
        
        let response = URLResponse(url: url, mimeType: "text/html", expectedContentLength: data.count, textEncodingName: "utf-8")
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }
    
    func handleWelcomeMessage(_ message: [String: Any], webView: iTermBrowserWebView) async {
        DLog("Welcome message received: \(message)")

        guard let action = message["action"] as? String,
              let sessionSecret = message["sessionSecret"] as? String,
              sessionSecret == secret else {
            RLog("Invalid or missing session secret for welcome action")
            return
        }
        
        switch action {
        case "loadTopSites":
            DLog("Handling welcome action: \(action)")
            return await loadTopSites(webView: webView)
            
        case "navigateToURL":
            if let url = message["url"] as? String {
                delegate?.welcomePageHandlerDidNavigateToURL(self, url: url)
            }
            return
            
        default:
            return
        }
    }
    
    // MARK: - iTermBrowserPageHandler Protocol
    
    func injectJavaScript(into webView: iTermBrowserWebView) {
        // JavaScript will be injected via the template
    }
    
    func resetState() {
        // Welcome page doesn't have persistent state to reset
    }
    
    // MARK: - Private Implementation
    
    private func loadTopSites(webView: iTermBrowserWebView) async {
        DLog("Loading top visited sites")
        
        guard let database = await BrowserDatabase.instance(for: user) else {
            RLog("Could not get database instance")
            await sendTopSitesResponse([], webView: webView)
            return
        }
        
        let topSites = await database.topVisitedUrls(limit: 5)
        
        DLog("Fetched \(topSites.count) top sites")
        
        // Convert to JavaScript-friendly format
        let sitesData = topSites.map { site in
            return [
                "url": site.url,
                "title": site.title ?? site.hostname,
                "hostname": site.hostname.removing(prefix: "."),
                "visitCount": site.visitCount
            ]
        }
        
        await sendTopSitesResponse(sitesData, webView: webView)
    }
    
    private func sendTopSitesResponse(_ sites: [[String: Any]], webView: iTermBrowserWebView) async {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: sites, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
            
            let script = "return window.handleTopSitesResponse(\(jsonString));"

            do {
                _ = try await webView.safelyEvaluateJavaScript(iife(script), contentWorld: .page)
                DLog("Successfully sent top sites to page")
            } catch {
                RLog("Error sending top sites response: \(error)")
            }
        } catch {
            RLog("Error serializing top sites: \(error)")
        }
    }
}
