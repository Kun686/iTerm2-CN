import XCTest
import JavaScriptCore
import WebKit
@testable import iTerm2SharedARC

private final class CapturingURLSchemeTask: NSObject, WKURLSchemeTask {
    let request: URLRequest
    private(set) var data = Data()
    private(set) var error: Error?
    private(set) var finished = false

    init(url: URL) {
        request = URLRequest(url: url)
    }

    func didReceive(_ response: URLResponse) {
    }

    func didReceive(_ data: Data) {
        self.data.append(data)
    }

    func didFinish() {
        finished = true
    }

    func didFailWithError(_ error: Error) {
        self.error = error
    }
}

final class iTermBrowserTemplateLoaderTests: XCTestCase {
    private func assertNoUnresolvedPlaceholder(
        in template: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(
            template.contains("{{"),
            "Generated browser resource contains an unresolved template placeholder",
            file: file,
            line: line)
    }

    private func assertJavaScriptParses(
        _ source: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let context = JSContext() else {
            XCTFail("Could not create a JavaScriptCore context", file: file, line: line)
            return
        }
        var parseError: String?
        context.exceptionHandler = { _, exception in
            parseError = exception?.toString()
        }

        let literal = iTermBrowserTemplateLoader.javaScriptStringLiteral(source)
        context.evaluateScript("new Function(\(literal));")

        XCTAssertNil(
            parseError,
            "Generated browser JavaScript does not parse: \(parseError ?? "unknown error")",
            file: file,
            line: line)
    }

    private func assertInlineJavaScriptParses(
        in html: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let regex = try! NSRegularExpression(
            pattern: #"<script(?:\s[^>]*)?>([\s\S]*?)</script>"#,
            options: [.caseInsensitive])
        let matches = regex.matches(
            in: html,
            range: NSRange(html.startIndex..<html.endIndex, in: html))
        XCTAssertFalse(matches.isEmpty, "Generated page has no inline script", file: file, line: line)
        for match in matches {
            guard let range = Range(match.range(at: 1), in: html) else {
                XCTFail("Could not read an inline script", file: file, line: line)
                continue
            }
            assertJavaScriptParses(String(html[range]), file: file, line: line)
        }
    }

    @MainActor
    func testSettingsPageReplacesEveryTemplatePlaceholder() {
        let html = iTermBrowserSettingsHandler(user: .devNull).generateSettingsHTML()

        assertNoUnresolvedPlaceholder(in: html)
        assertInlineJavaScriptParses(in: html)
        XCTAssertTrue(html.contains("${escapeHtml(localized.noExtensionsTitle)}"))
        XCTAssertTrue(html.contains("${escapeHtml(localized.noExtensionsDescription)}"))
        XCTAssertTrue(html.contains("${formatLocalized(localized.versionFormat, [version])}"))
    }

    @MainActor
    func testBookmarkPageReplacesEveryTemplatePlaceholder() {
        let html = iTermBrowserBookmarkViewHandler(user: .devNull).generateBookmarksHTML()

        assertNoUnresolvedPlaceholder(in: html)
        assertInlineJavaScriptParses(in: html)
    }

    @MainActor
    func testHistoryPageReplacesEveryTemplatePlaceholder() {
        let historyController = iTermBrowserHistoryController(
            user: .devNull,
            sessionGuid: "template-loader-test",
            navigationState: iTermBrowserNavigationState())
        let html = iTermBrowserHistoryViewHandler(
            user: .devNull,
            historyController: historyController).generateHistoryHTML()

        assertNoUnresolvedPlaceholder(in: html)
        assertInlineJavaScriptParses(in: html)
    }

    @MainActor
    func testPermissionsPageReplacesEveryTemplatePlaceholder() {
        let html = iTermBrowserPermissionsViewHandler(user: .devNull).generatePermissionsHTML()

        assertNoUnresolvedPlaceholder(in: html)
        assertInlineJavaScriptParses(in: html)
    }

    @MainActor
    func testWelcomePageReplacesEveryTemplatePlaceholder() throws {
        let handler = try XCTUnwrap(iTermBrowserWelcomePageHandler(user: .devNull))

        let html = handler.generateWelcomeHTML()
        assertNoUnresolvedPlaceholder(in: html)
        assertInlineJavaScriptParses(in: html)
    }

    @MainActor
    func testOnboardingPagesReplaceEveryTemplatePlaceholder() throws {
        let handler = iTermBrowserOnboardingHandler(user: .devNull)
        for url in [
            iTermBrowserOnboardingHandler.profileURL,
            iTermBrowserOnboardingHandler.setupURL
        ] {
            let task = CapturingURLSchemeTask(url: url)
            handler.start(urlSchemeTask: task, url: url)

            XCTAssertNil(task.error)
            XCTAssertTrue(task.finished)
            let html = try XCTUnwrap(String(data: task.data, encoding: .utf8))
            assertNoUnresolvedPlaceholder(in: html)
            assertInlineJavaScriptParses(in: html)
        }
    }

    @MainActor
    func testStaticOnboardingPagesReplaceEveryTemplatePlaceholder() throws {
        for page in ["onboarding-intro", "onboarding-features"] {
            let url = "\(iTermBrowserSchemes.about):\(page)"
            let config = try XCTUnwrap(iTermBrowserStaticPageRegistry.shared.getConfig(for: url))
            let html = iTermBrowserTemplateLoader.loadTemplate(
                named: config.templateName,
                type: "html",
                substitutions: config.substitutions)

            assertNoUnresolvedPlaceholder(in: html)
        }
    }

    @MainActor
    func testErrorAndSourcePagesReplaceEveryTemplatePlaceholder() {
        let errorHTML = iTermBrowserErrorHandler().generateErrorPageHTML(
            for: URLError(.cannotConnectToHost),
            failedURL: URL(string: "https://example.com"))
        let sourceHTML = iTermBrowserSourceHandler().generateSourcePageHTML(
            for: "<html></html>",
            url: URL(string: "https://example.com")!)

        assertNoUnresolvedPlaceholder(in: errorHTML)
        assertNoUnresolvedPlaceholder(in: sourceHTML)
        assertInlineJavaScriptParses(in: errorHTML)
        assertInlineJavaScriptParses(in: sourceHTML)
    }

    func testSSHFailurePageReplacesEveryTemplatePlaceholder() {
        let html = iTermBrowserTemplateLoader.loadTemplate(
            named: "ssh-page-no-conductor",
            type: "html",
            substitutions: [
                "HTML_LANG": iTermBrowserTemplateLoader.localizedHTML(
                    "ui.browser.page.common.language_code",
                    defaultValue: "en"),
                "PAGE_TITLE": "Problem viewing file",
                "HEADING": "Could not display file",
                "MESSAGE_PREFIX": "No connection to",
                "HOST": "example.com",
                "MESSAGE_SUFFIX": "using SSH integration could be found.",
                "TRY_AGAIN": "Try Again"
            ])

        assertNoUnresolvedPlaceholder(in: html)
        assertInlineJavaScriptParses(in: html)
    }

    @MainActor
    func testAutofillScriptReplacesEveryTemplatePlaceholder() throws {
        let handler = try XCTUnwrap(iTermBrowserAutofillHandler())

        assertNoUnresolvedPlaceholder(in: handler.javascript)
        assertJavaScriptParses(handler.javascript)
    }

    @MainActor
    func testPasswordManagerScriptReplacesEveryTemplatePlaceholder() throws {
        let handler = try XCTUnwrap(iTermBrowserPasswordManagerHandler())

        assertNoUnresolvedPlaceholder(in: handler.javascript)
        assertJavaScriptParses(handler.javascript)
    }

    @MainActor
    func testFindScriptReplacesEveryTemplatePlaceholder() throws {
        let manager = try XCTUnwrap(iTermBrowserFindManager.create())

        assertNoUnresolvedPlaceholder(in: manager.javascript)
        assertJavaScriptParses(manager.javascript)
    }

    func testNamedMarkScriptReplacesEveryTemplatePlaceholder() {
        let script = iTermBrowserTemplateLoader.loadTemplate(
            named: "show-named-mark-annotations",
            type: "js",
            substitutions: [
                "MARKS_JSON": "[]",
                "SECRET": "secret",
                "EXPAND_TOOLTIP_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral(
                    "ui.browser.script.named_mark.expand_tooltip",
                    defaultValue: "Click to expand and edit name"),
                "NAME_PLACEHOLDER_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral(
                    "ui.browser.script.named_mark.name_placeholder",
                    defaultValue: "Enter mark name"),
                "SAVE_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral(
                    "ui.browser.script.named_mark.save",
                    defaultValue: "Save"),
                "DELETE_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral(
                    "ui.browser.script.named_mark.delete",
                    defaultValue: "Delete"),
                "CLOSE_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral(
                    "ui.browser.script.named_mark.close",
                    defaultValue: "Close")
            ])

        assertNoUnresolvedPlaceholder(in: script)
        assertJavaScriptParses(script)
    }

    func testReaderModeScriptReplacesEveryTemplatePlaceholder() {
        let css = iTermBrowserTemplateLoader.loadTemplate(
            named: "reader-mode",
            type: "css",
            substitutions: [:])
        let script = iTermBrowserTemplateLoader.loadTemplate(
            named: "reader-mode-with-styles",
            type: "js",
            substitutions: [
                "READER_MODE_CSS": css,
                "ARTICLE_FALLBACK_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral(
                    "ui.browser.script.reader_mode.article_fallback",
                    defaultValue: "Article")
            ])

        assertNoUnresolvedPlaceholder(in: script)
        assertJavaScriptParses(script)
    }

    func testFilePageReplacesEveryTemplatePlaceholder() {
        let html = iTermBrowserTemplateLoader.loadTemplate(
            named: "file-page",
            type: "html",
            substitutions: [
                "COMMON_CSS": "",
                "HTML_LANG": iTermBrowserTemplateLoader.localizedHTML(
                    "ui.browser.page.common.language_code",
                    defaultValue: "en"),
                "TITLE": "Directory",
                "PATH": "/tmp",
                "CONTENT": "<ul></ul>"
            ])

        assertNoUnresolvedPlaceholder(in: html)
    }

    func testLocalizedHTMLUsesFallbackAndEscapesMarkup() {
        let result = iTermBrowserTemplateLoader.localizedHTML(
            "test.browser.page.missing-html-key",
            defaultValue: "<&>\"'")

        XCTAssertEqual(result, "&lt;&amp;&gt;&quot;&#39;")
    }

    func testLocalizedJavaScriptStringLiteralUsesFallbackAndRoundTrips() throws {
        let input = "</script> & \"quoted\""

        let literal = iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral(
            "test.browser.page.missing-javascript-key",
            defaultValue: input)

        XCTAssertEqual(try JSONDecoder().decode(String.self, from: Data(literal.utf8)), input)
        XCTAssertFalse(literal.contains("<"))
    }

    func testJavaScriptStringLiteralRoundTripsAndCannotCloseInlineScript() throws {
        let input = "</script> & \"quoted\"\\line\nnext\u{2028}paragraph\u{2029}end"

        let literal = iTermBrowserTemplateLoader.javaScriptStringLiteral(input)

        XCTAssertFalse(literal.contains("<"))
        XCTAssertFalse(literal.contains(">"))
        XCTAssertFalse(literal.contains("&"))
        XCTAssertFalse(literal.contains("\u{2028}"))
        XCTAssertFalse(literal.contains("\u{2029}"))
        XCTAssertEqual(try JSONDecoder().decode(String.self, from: Data(literal.utf8)), input)
    }

}
