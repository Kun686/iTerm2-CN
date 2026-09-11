//
//  iTermBrowserSourceHandler.swift
//  iTerm2
//
//  Created by George Nachman on 6/19/25.
//

import WebKit

class iTermBrowserSourceHandler: NSObject, iTermBrowserPageHandler {
    static let sourceURL = URL(string: "\(iTermBrowserSchemes.about):source")!

    private var pendingSourceHTML: String?
    
    func generateSourcePageHTML(for rawSource: String, url: URL) -> String {
        // Escape HTML entities for safe display but preserve whitespace characters
        let escapedSource = rawSource
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: "\n", with: "<br/>")
            .replacingOccurrences(of: "  ", with: "&nbsp;&nbsp;")
            // Keep tabs as tabs - CSS will handle the display with tab-size
        
        // Load template and substitute source
        return iTermBrowserTemplateLoader.loadTemplate(named: "view-source",
                                                       type: "html",
                                                       substitutions: pageSubstitutions(source: escapedSource,
                                                                                     url: url.absoluteString.escapedForHTML))
    }
    
    func setPendingSourceHTML(_ html: String) {
        pendingSourceHTML = html
    }
    
    func clearPendingSource() {
        pendingSourceHTML = nil
    }
    
    func start(urlSchemeTask: WKURLSchemeTask, url: URL) {
        guard url == Self.sourceURL else {
            urlSchemeTask.didFailWithError(NSError(domain: "iTermBrowserSourceHandler", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid source URL"]))
            return
        }
        
        let htmlContent: String
        if let pendingHTML = pendingSourceHTML {
            htmlContent = pendingHTML
            pendingSourceHTML = nil // Clear after use
        } else {
            // Fallback content if no source is pending
            htmlContent = iTermBrowserTemplateLoader.loadTemplate(named: "view-source",
                                                                  type: "html",
                                                                  substitutions: pageSubstitutions(
                                                                    source: iTermBrowserTemplateLoader.localizedHTML("ui.swift.browser.viewsource.itermbrowsersourcehandler.no_source_available.53d64b2b", defaultValue: "No source available"),
                                                                    url: ""))
        }
        
        let data = htmlContent.data(using: .utf8) ?? Data()
        let response = URLResponse(url: url, mimeType: "text/html", expectedContentLength: data.count, textEncodingName: "utf-8")
        
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }
    
    // MARK: - iTermBrowserPageHandler Protocol
    
    func injectJavaScript(into webView: iTermBrowserWebView) {
        // Source pages don't need JavaScript injection
    }
    
    func resetState() {
        clearPendingSource()
    }

    private func pageSubstitutions(source: String, url: String) -> [String: String] {
        return [
            "HTML_LANG": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.common.language_code", defaultValue: "en"),
            "PAGE_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.view_source.page_title", defaultValue: "View Source"),
            "HEADING": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.view_source.heading", defaultValue: "Page Source"),
            "SOURCE": source,
            "URL": url
        ]
    }
}
