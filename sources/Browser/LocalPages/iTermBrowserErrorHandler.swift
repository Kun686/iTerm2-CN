//
//  iTermBrowserErrorHandler.swift
//  iTerm2
//
//  Created by George Nachman on 6/18/25.
//

import Foundation
@preconcurrency import WebKit

@objc(iTermBrowserErrorHandler)
class iTermBrowserErrorHandler: NSObject, iTermBrowserPageHandler {
    private var pendingErrorHTML: String?
    
    static let errorURL = URL(string: "\(iTermBrowserSchemes.about):error")!
    
    // MARK: - Public Interface
    
    func generateErrorPageHTML(for error: Error, failedURL: URL?) -> String {
        let (title, message) = errorTitleAndMessage(for: error)
        return generateErrorHTML(title: title, message: message, originalURL: failedURL?.absoluteString)
    }
    
    func setPendingErrorHTML(_ html: String) {
        pendingErrorHTML = html
    }
    
    func consumePendingErrorHTML() -> String? {
        let html = pendingErrorHTML
        pendingErrorHTML = nil
        return html
    }
    
    func hasPendingError() -> Bool {
        return pendingErrorHTML != nil
    }
    
    func clearPendingError() {
        pendingErrorHTML = nil
    }
    
    // MARK: - iTermBrowserPageHandler Protocol
    
    func injectJavaScript(into webView: iTermBrowserWebView) {
        // Error pages don't need JavaScript injection
    }
    
    func resetState() {
        clearPendingError()
    }

    func start(urlSchemeTask: WKURLSchemeTask, url: URL) {
        // Serve our error page HTML
        let htmlToServe = consumePendingErrorHTML() ?? generateErrorPageHTML(
            for: NSError(domain: NSURLErrorDomain, code: NSURLErrorResourceUnavailable, userInfo: [NSLocalizedDescriptionKey: String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.page_not_available.7bc21700", defaultValue: "Page Not Available", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler.")]),
            failedURL: nil
        )

        guard let data = htmlToServe.data(using: .utf8) else {
            urlSchemeTask.didFailWithError(NSError(domain: "iTermBrowserManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode HTML"]))
            return
        }

        let response = URLResponse(url: url, mimeType: "text/html", expectedContentLength: data.count, textEncodingName: "utf-8")
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    // MARK: - Error Page Generation
    
    private func generateErrorHTML(title: String, message: String, originalURL: String?) -> String {
        let urlDisplay = originalURL ?? ""
        let urlDisplayHTML = urlDisplay.isEmpty ? "" : "<div class=\"error-url\">\(urlDisplay)</div>"
        
        let substitutions = [
            "HTML_LANG": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.common.language_code", defaultValue: "en"),
            "TITLE": title.escapedForHTML,
            "MESSAGE": message,
            "URL_DISPLAY": urlDisplayHTML,
            "ORIGINAL_URL": originalURL ?? "",
            "TRY_AGAIN": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.common.try_again", defaultValue: "Try Again"),
            "DETAILS": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.error.connection_hint", defaultValue: "Check your internet connection and try reloading the page.")
        ]
        
        return iTermBrowserTemplateLoader.loadTemplate(named: "error-page",
                                                       type: "html",
                                                       substitutions: substitutions)
    }
    
    // Navigation errors are also logged and returned to callers; keep their fields raw.
    private func localizedNavigationErrorDescription(_ error: Error) -> String {
        let diagnostic = error.localizedDescription
        let nsError = error as NSError
        guard nsError.code == -1 else { return diagnostic }
        switch (nsError.domain, diagnostic) {
        case ("iTermBrowserManager", "Invalid URL"):
            return String(localized: "ui.swift.browser.core.itermbrowsermanager.invalid_url.82e45382", defaultValue: "Invalid URL", bundle: .main, comment: "Error shown when an internal browser request has no valid URL.")
        case ("iTermBrowserManager", "Unknown URL scheme"):
            return String(localized: "ui.swift.browser.core.itermbrowsermanager.unknown_url_scheme.f542e0b2", defaultValue: "Unknown URL scheme", bundle: .main, comment: "Error shown when an internal browser URL scheme is not recognized.")
        case ("iTermBrowserManager", "Failed to encode HTML"):
            return String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.failed_to_encode_html.c166d582", defaultValue: "Failed to encode HTML", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler.")
        case ("iTermBrowserBookmarkViewHandler", "Failed to encode HTML"):
            return String(localized: "ui.swift.browser.bookmarks.itermbrowserbookmarkviewhandler.failed_to_encode_html.c166d582", defaultValue: "Failed to encode HTML", bundle: .main, comment: "Error shown when the browser bookmarks page cannot be encoded.")
        default:
            return diagnostic
        }
    }

    private func errorTitleAndMessage(for error: Error) -> (title: String, message: String) {
        let nsError = error as NSError
        let displayDescription = localizedNavigationErrorDescription(error)

        let tuple: (String, String, String?) = {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return (String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.no_internet_connection.13a21216", defaultValue: "No Internet Connection", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.your_computer_appears_to_be_offline_check_your.92a063e9", defaultValue: "Your computer appears to be offline. Check your internet connection and try again.", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), nil)

            case NSURLErrorCannotFindHost:
                return (String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.server_not_found.5320e6c0", defaultValue: "Server Not Found", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.iterm2_can_t_find_the_server_check_that.0a56d308", defaultValue: "iTerm2 can’t find the server. Check that the web address is correct and try again.", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), nil)

            case NSURLErrorTimedOut:
                return (String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.the_connection_timed_out.759738c1", defaultValue: "The Connection Timed Out", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.the_server_didn_t_respond_in_time_the.be947565", defaultValue: "The server didn’t respond in time. The site may be temporarily unavailable or overloaded.", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), nil)

            case NSURLErrorCannotConnectToHost:
                return (String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.can_t_connect_to_server.3149cd61", defaultValue: "Can’t Connect to Server", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.iterm2_can_t_establish_a_secure_connection_to.cd016daa", defaultValue: "iTerm2 can’t establish a secure connection to the server. The server may be down or unreachable.", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), nil)

            case NSURLErrorNetworkConnectionLost:
                return (String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.network_connection_lost.1e335937", defaultValue: "Network Connection Lost", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.the_network_connection_was_lost_check_your_internet.84bef13f", defaultValue: "The network connection was lost. Check your internet connection and try again.", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), nil)

            case NSURLErrorDNSLookupFailed:
                return (String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.server_not_found.5320e6c0", defaultValue: "Server Not Found", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.the_server_s_dns_address_could_not_be.2ccd5dbe", defaultValue: "The server’s DNS address could not be found. Check that the web address is correct.", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), nil)

            case NSURLErrorHTTPTooManyRedirects:
                return (String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.too_many_redirects.531d3bd3", defaultValue: "Too Many Redirects", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.iterm2_can_t_open_the_page_because_the.1a57da18", defaultValue: "iTerm2 can’t open the page because the server redirected too many times.", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), nil)

            case NSURLErrorResourceUnavailable:
                return (String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.page_unavailable.fcc759f1", defaultValue: "Page Unavailable", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.the_requested_page_is_currently_unavailable_try_again.09e4bb38", defaultValue: "The requested page is currently unavailable. Try again later.", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), nil)

            case NSURLErrorNotConnectedToInternet:
                return (String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.no_internet_connection.13a21216", defaultValue: "No Internet Connection", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.your_computer_is_not_connected_to_the_internet.8dcbdb32", defaultValue: "Your computer is not connected to the internet. Check your connection and try again.", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), nil)

            case NSURLErrorServerCertificateUntrusted, NSURLErrorSecureConnectionFailed:
                return (String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.secure_connection_failed.55c71f44", defaultValue: "Secure Connection Failed", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.iterm2_can_t_verify_the_identity_of_the.b0042f3a", defaultValue: "iTerm2 can’t verify the identity of the website. The connection may not be secure.", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), sslErrorDetails(from: error))

            case NSURLErrorFileDoesNotExist:
                return (String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.file_not_found.bf599881", defaultValue: "File Not Found", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.the_requested_file_does_not_exist.02da121e", defaultValue: "The requested file does not exist.", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), nil)

            default:
                return (String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.page_can_t_be_loaded.e6b913ac", defaultValue: "Page Can’t Be Loaded", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.an_error_occurred_while_loading_this_page_0.dc88eff8", defaultValue: "An error occurred while loading this page. \(displayDescription)", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler."), nil)
            }
        }()
        return (title: tuple.0,
                message: "<strong>" + tuple.1.escapedForHTML + "</strong><br/><br/>" + (tuple.2 ?? displayDescription))
    }
}

/// Returns a detailed TLS/SSL error message if `error` is an SSL-related NSURLError.
func sslErrorDetails(from error: Error) -> String? {
    let ns = error as NSError
    if ns.domain != NSURLErrorDomain {
        return nil
    }
    // Common TLS/SSL URL error codes
    let sslURLCodes: Set<Int> = [
        URLError.serverCertificateUntrusted.rawValue,
        URLError.serverCertificateHasBadDate.rawValue,
        URLError.serverCertificateHasUnknownRoot.rawValue,
        URLError.serverCertificateNotYetValid.rawValue,
        URLError.clientCertificateRejected.rawValue,
        URLError.clientCertificateRequired.rawValue
    ]
    if !sslURLCodes.contains(ns.code) {
        return nil
    }

    var lines: [String] = []

    if let os = ns.userInfo["_kCFStreamErrorCodeKey"] as? Int,
       let description = sslErrorDescription(for: os) {
        lines.append(description.escapedForHTML)
    }

    // Extract SecTrust safely from userInfo (NSURLErrorFailingURLPeerTrustErrorKey)
    if let trust = secTrust(fromUserInfo: ns.userInfo) {
        // Certificate chain subjects
        let subjects = certificateSubjects(from: trust)
        if !subjects.isEmpty {
            lines.append(String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.certificate_chain.d35d94bd", defaultValue: "Certificate chain:", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler.").escapedForHTML)
            for (idx, s) in subjects.enumerated() {
                lines.append("  [\(idx)] \(s.escapedForHTML)")
            }
        }
    }

    return lines.joined(separator: "<br/>\n")
}

/// Robustly extract SecTrust from NSError.userInfo, handling CF bridging.
private func secTrust(fromUserInfo ui: [String: Any]) -> SecTrust? {
    guard let any = ui[NSURLErrorFailingURLPeerTrustErrorKey] else {
        return nil
    }
    // Work through CFTypeRef to avoid “AnyObject is not convertible to SecTrust”
    let cf = any as CFTypeRef
    if CFGetTypeID(cf) == SecTrustGetTypeID() {
        return (cf as! SecTrust)
    }
    return nil
}

/// Map SecureTransport OSStatus to a readable name and a short hint.
private func sslErrorDescription(for status: Int) -> String? {
    // Subset of the most useful SSL codes you’ll actually see.
    switch OSStatus(status) {
    case errSSLXCertChainInvalid:        return String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.the_presented_chain_is_not_valid_e_g.f551a1b4", defaultValue: "The presented chain is not valid (e.g., self-signed without trust).", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler.")
    case errSSLUnknownRootCert:          return String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.the_root_ca_is_unknown_not_in_trust.3f8a2430", defaultValue: "The root CA is unknown (not in trust store).", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler.")
    case errSSLNoRootCert:               return String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.no_root_certificate_found_to_anchor_the_chain.19b9f6f5", defaultValue: "No root certificate found to anchor the chain.", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler.")
    case errSSLBadCert:                  return String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.the_certificate_is_malformed_or_otherwise_bad.44944bed", defaultValue: "The certificate is malformed or otherwise bad.", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler.")
    case errSSLCertExpired:              return String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.the_certificate_is_expired.abb335c1", defaultValue: "The certificate is expired.", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler.")
    case errSSLCertNotYetValid:          return String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.the_certificate_is_not_yet_valid.51a73ea8", defaultValue: "The certificate is not yet valid.", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler.")
    case errSSLHostNameMismatch:         return String(localized: "ui.swift.browser.localpages.itermbrowsererrorhandler.the_hostname_does_not_match_the_certificate.31da68f2", defaultValue: "The hostname does not match the certificate.", bundle: .main, comment: "User-facing text in iTermBrowserErrorHandler.")
    default:                             return SecCopyErrorMessageString(OSStatus(status), nil) as? String
    }
}

/// Get human-friendly subject summaries for the chain.
private func certificateSubjects(from trust: SecTrust) -> [String] {
    guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate] else {
        return []
    }
    return chain.compactMap { SecCertificateCopySubjectSummary($0) as String? }
}
