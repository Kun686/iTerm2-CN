//
//  iTermBrowserStaticPageHandler.swift
//  iTerm2
//
//  Created by George Nachman on 6/22/25.
//

//    # Adding Static iterm2-about: Pages
//
//    This document explains how to add simple static HTML pages to iTerm2's browser system using the built-in template system.
//
//    ## For Static Pages (No JavaScript interaction)
//
//    If you want to add a simple static page that doesn't need to communicate with Swift code:
//
//    ### 1. Create your HTML template
//
//    Create an HTML template file in the Browser sources folder (e.g., `help-page.html`):
//
//    ```html
//    <!DOCTYPE html>
//    <html lang="en">
//    <head>
//        <meta charset="UTF-8">
//        <meta name="viewport" content="width=device-width, initial-scale=1.0">
//        <title>{{TITLE}}</title>
//        <style>
//            {{COMMON_CSS}}
//
//            /* Your custom styles here */
//            .help-container {
//                max-width: 800px;
//            }
//
//            .help-section {
//                margin-bottom: 32px;
//            }
//        </style>
//    </head>
//    <body>
//        <div class="container help-container">
//            <h1>{{TITLE}}</h1>
//            <p>{{SUBTITLE}}</p>
//
//            <div class="help-section">
//                <h2>Getting Started</h2>
//                <p>Your help content here...</p>
//            </div>
//        </div>
//    </body>
//    </html>
//    ```
//
//    ### 2. Register the page
//
//    Add your page to the static page registry in `iTermBrowserStaticPageHandler.swift`:
//
//    ```swift
//    private func setupDefaultPages() {
//        registerStaticPage(urlPath: "welcome", templateName: "welcome-page", substitutions: [
//            "TITLE": "Welcome to iTerm2",
//            "SUBTITLE": "The terminal emulator for macOS that does amazing things."
//        ])
//
//        // Add your page here
//        registerStaticPage(urlPath: "help", templateName: "help-page", substitutions: [
//            "TITLE": "iTerm2 Help",
//            "SUBTITLE": "Find answers to common questions and learn about features."
//        ])
//    }
//    ```
//
//    ### 3. Access your page
//
//    Navigate to `iterm2-about:help` (or whatever urlPath you chose) in the browser.
//
//    ## That's it!
//
//    ## For Interactive Pages
//
//    If you need JavaScript communication with Swift code (like the existing settings, history, and bookmarks pages), you still need to create a custom handler implementing `iTermBrowserPageHandler` and add it to the switch statement in `setupPageContext(for:)`.

import Foundation
@preconcurrency import WebKit

// MARK: - Static Page Configuration

struct iTermBrowserStaticPageConfig {
    var url: URL
    var templateName: String
    var substitutions: [String: String]
    
    init(urlPath: String, templateName: String, substitutions: [String: String] = [:]) {
        self.url = URL(string: "\(iTermBrowserSchemes.about):\(urlPath)")!
        self.templateName = templateName
        self.substitutions = substitutions
    }
}

// MARK: - Static Page Handler

@MainActor
class iTermBrowserStaticPageHandler: NSObject, iTermBrowserPageHandler {
    private let config: iTermBrowserStaticPageConfig
    
    init(config: iTermBrowserStaticPageConfig) {
        self.config = config
        super.init()
    }
    
    func start(urlSchemeTask: WKURLSchemeTask, url: URL) {
        let htmlContent = generateHTML()
        
        guard let data = htmlContent.data(using: .utf8) else {
            let error = NSError(domain: "iTermBrowserStaticPageHandler", 
                               code: -1, 
                               userInfo: [NSLocalizedDescriptionKey: String(localized: "ui.swift.browser.localpages.itermbrowserstaticpagehandler.failed_to_encode_html.c166d582", defaultValue: "Failed to encode HTML", bundle: .main, comment: "User-facing text in iTermBrowserStaticPageHandler.")])
            urlSchemeTask.didFailWithError(error)
            return
        }
        
        // Create HTTP response
        let response = URLResponse(
            url: url,
            mimeType: "text/html",
            expectedContentLength: data.count,
            textEncodingName: "utf-8"
        )
        
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }
    
    func injectJavaScript(into webView: iTermBrowserWebView) {
        // Static pages don't need JavaScript injection
    }
    
    func resetState() {
        // Static pages don't have state to reset
    }
    
    // MARK: - Private Methods
    
    private func generateHTML() -> String {
        return iTermBrowserTemplateLoader.loadTemplate(
            named: config.templateName,
            type: "html",
            substitutions: config.substitutions
        )
    }
}

// MARK: - Static Page Registry

class iTermBrowserStaticPageRegistry {
    static let shared = iTermBrowserStaticPageRegistry()
    
    private var staticPages: [String: iTermBrowserStaticPageConfig] = [:]
    
    private init() {
        setupDefaultPages()
    }
    
    private func setupDefaultPages() {
        // Register all static pages here
        // Note: welcome page is now handled by iTermBrowserWelcomePageHandler as it needs dynamic content
        registerStaticPage(urlPath: "onboarding-intro",
                           templateName: "onboarding-intro",
                           substitutions: onboardingIntroSubstitutions())
        registerStaticPage(urlPath: "onboarding-features",
                           templateName: "onboarding-features",
                           substitutions: onboardingFeaturesSubstitutions())
        #if ITERM_DEBUG
        let pages = [
            "dev",
            "notifications-demo",
            "geolocation-demo",
            "media-demo",
            "password-demo",
            "selection-test",
            "smartselection-demo",
            "indexeddb-demo",
            "clipboard-demo",
            "dragdrop-demo",
            "autofill-demo"
        ]
        for page in pages {
            registerStaticPage(urlPath: page, templateName: page, substitutions: [:])
        }
        #endif
    }

    private func onboardingIntroSubstitutions() -> [String: String] {
        return [
            "HTML_LANG": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.common.language_code", defaultValue: "en"),
            "PAGE_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.intro.page_title", defaultValue: "Welcome to iTerm2 Browser"),
            "TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.intro.title", defaultValue: "Meet the iTerm2 Browser"),
            "SUBTITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.intro.subtitle", defaultValue: "Terminal + Browser = Trowser"),
            "PROFILE_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.intro.profile.title", defaultValue: "What is a Browser Profile?"),
            "PROFILE_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.intro.profile.description", defaultValue: "In iTerm2, profiles define how sessions look and behave. Terminal profiles open a shell. Browser profiles are different: they open a web browser instead."),
            "HOW_IT_WORKS_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.intro.how_it_works.title", defaultValue: "How It Works"),
            "HOW_IT_WORKS_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.intro.how_it_works.description", defaultValue: "When you create a new tab or split pane using a browser profile, you get a fully-featured web browser instead of a terminal. Mix and match browser and terminal panes however you like: they’re all part of the same iTerm2 experience."),
            "LEARN_MORE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.intro.learn_more", defaultValue: "Learn What’s Possible")
        ]
    }

    private func onboardingFeaturesSubstitutions() -> [String: String] {
        return [
            "HTML_LANG": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.common.language_code", defaultValue: "en"),
            "PAGE_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.page_title", defaultValue: "iTerm2 Browser - Features"),
            "TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.title", defaultValue: "What Can It Do?"),
            "SUBTITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.subtitle", defaultValue: "Power features and thoughtful limitations"),
            "FEATURES_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.features_title", defaultValue: "Why You’ll Love It"),
            "SSH_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.ssh.title", defaultValue: "SSH Integration Magic:"),
            "SSH_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.ssh.description", defaultValue: "View files on remote servers in the browser when using SSH integration."),
            "ITERM_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.iterm.title", defaultValue: "iTerm2 Superpowers:"),
            "ITERM_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.iterm.description", defaultValue: "Hotkey windows, split panes, and custom key bindings but for the web."),
            "ENGINEERS_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.engineers.title", defaultValue: "Built for Engineers:"),
            "ENGINEERS_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.engineers.description", defaultValue: "Copy on select, broadcast input, advanced paste, and regex search simplify workflows."),
            "PRODUCTIVITY_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.productivity.title", defaultValue: "Productivity Tools:"),
            "PRODUCTIVITY_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.productivity.description", defaultValue: "Instant replay, global search, named marks, and the Composer bring iTerm2 features into the browser."),
            "BASICS_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.basics.title", defaultValue: "Browser Basics:"),
            "BASICS_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.basics.description", defaultValue: "Integrates with the iTerm2 password manager, Webkit adblock lists, and iTerm2’s AI chat feature."),
            "LIMITS_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.limits_title", defaultValue: "Know the Limits"),
            "BETA_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.beta.title", defaultValue: "Beta Alert:"),
            "BETA_DESCRIPTION_BEFORE_LINK": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.beta.before_link", defaultValue: "This is the first release! Expect some turbulence. As always,"),
            "FILE_AN_ISSUE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.beta.link", defaultValue: "file an issue"),
            "BETA_DESCRIPTION_AFTER_LINK": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.beta.after_link", defaultValue: "if something goes wrong."),
            "SECONDARY_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.secondary.title", defaultValue: "Secondary Browser:"),
            "SECONDARY_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.secondary.description", defaultValue: "iTerm2 doesn’t expect to be your primary browser. The purpose is to complement the terminal and facilitate particular tasks that other browser can’t."),
            "PLATFORM_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.platform.title", defaultValue: "Platform Constraints:"),
            "PLATFORM_DESCRIPTION": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.platform.description", defaultValue: "Some features like Passkeys and advanced ad blocking are unavailable due to Apple’s restrictions on web views."),
            "BACK": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.common.back", defaultValue: "Back"),
            "GET_STARTED": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.onboarding.features.get_started", defaultValue: "Get Started")
        ]
    }
    
    func registerStaticPage(urlPath: String, templateName: String, substitutions: [String: String] = [:]) {
        let config = iTermBrowserStaticPageConfig(urlPath: urlPath, templateName: templateName, substitutions: substitutions)
        staticPages[config.url.absoluteString] = config
    }
    
    func getConfig(for urlString: String) -> iTermBrowserStaticPageConfig? {
        return staticPages[urlString]
    }
    
    func isStaticPage(_ urlString: String) -> Bool {
        return staticPages[urlString] != nil
    }
    
    // MARK: - Convenience Methods
    
    /// Register multiple static pages at once
    func registerStaticPages(_ pages: [(urlPath: String, templateName: String, substitutions: [String: String])]) {
        for page in pages {
            registerStaticPage(urlPath: page.urlPath, templateName: page.templateName, substitutions: page.substitutions)
        }
    }
    
    /// Get all registered static page URLs
    var registeredURLs: [String] {
        return Array(staticPages.keys)
    }
}
