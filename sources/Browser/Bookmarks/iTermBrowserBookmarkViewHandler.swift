//
//  iTermBrowserBookmarkViewHandler.swift
//  iTerm2
//
//  Created by George Nachman on 6/21/25.
//

import WebKit
import Foundation

@objc protocol iTermBrowserBookmarkViewHandlerDelegate: AnyObject {
    @MainActor func bookmarkViewHandlerDidNavigateToURL(_ handler: iTermBrowserBookmarkViewHandler, url: String)
}

@objc(iTermBrowserBookmarkViewHandler)
@MainActor
class iTermBrowserBookmarkViewHandler: NSObject, iTermBrowserPageHandler {
    static let bookmarksURL = URL(string: "\(iTermBrowserSchemes.about):bookmarks")!
    private let user: iTermBrowserUser

    weak var delegate: iTermBrowserBookmarkViewHandlerDelegate?

    init(user: iTermBrowserUser) {
        self.user = user
    }
}


@objc(iTermBrowserBookmarkViewHandler)
@MainActor
extension iTermBrowserBookmarkViewHandler {
    // MARK: - Public Interface
    
    func generateBookmarksHTML() -> String {
        let scriptSubstitutions = [
            "DELETE_BOOKMARK_PROMPT_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.bookmarks.confirm.delete", defaultValue: "Delete this bookmark?"),
            "CLEAR_ALL_PROMPT_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.bookmarks.confirm.clear_all", defaultValue: "This will delete all bookmarks. This action cannot be undone. Continue?"),
            "UNTITLED_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.bookmarks.untitled", defaultValue: "Untitled"),
            "ADDED_FORMAT_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.bookmarks.added_format", defaultValue: "Added %1$@"),
            "NAVIGATE_TITLE_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.bookmarks.navigate_tooltip", defaultValue: "Click to navigate to this URL"),
            "DELETE_TITLE_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.bookmarks.delete_tooltip", defaultValue: "Delete this bookmark"),
            "NO_BOOKMARKS_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.bookmarks.empty.title", defaultValue: "No bookmarks found"),
            "EMPTY_DESCRIPTION_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.bookmarks.empty.description", defaultValue: "Start bookmarking your favorite websites to see them here."),
            "BOOKMARK_DELETED_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.bookmarks.status.deleted", defaultValue: "Bookmark deleted"),
            "ALL_BOOKMARKS_CLEARED_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.bookmarks.status.cleared", defaultValue: "All bookmarks cleared"),
            "PAGE_TITLE_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.page.bookmarks.title", defaultValue: "Bookmarks")
        ]
        let script = iTermBrowserTemplateLoader.loadTemplate(named: "bookmarks-page",
                                                             type: "js",
                                                             substitutions: scriptSubstitutions)
        return iTermBrowserTemplateLoader.loadTemplate(named: "bookmarks-page",
                                                       type: "html",
                                                       substitutions: [
                                                           "HTML_LANG": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.common.language_code", defaultValue: "en"),
                                                           "PAGE_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.bookmarks.title", defaultValue: "Bookmarks"),
                                                           "PAGE_SUBTITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.bookmarks.subtitle", defaultValue: "Manage and organize your saved websites"),
                                                           "CLEAR_ALL": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.bookmarks.clear_all", defaultValue: "Clear All"),
                                                           "SEARCH_PLACEHOLDER": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.bookmarks.search_placeholder", defaultValue: "Search bookmarks..."),
                                                           "SORT_BY": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.bookmarks.sort_by", defaultValue: "Sort by:"),
                                                           "SORT_DATE_ADDED": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.bookmarks.sort.date_added", defaultValue: "Date Added"),
                                                           "SORT_TITLE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.bookmarks.sort.title", defaultValue: "Title"),
                                                           "SORT_URL": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.bookmarks.sort.url", defaultValue: "URL"),
                                                           "FILTER_BY_TAGS": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.bookmarks.filter_by_tags", defaultValue: "Filter by tags:"),
                                                           "LOADING": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.bookmarks.loading", defaultValue: "Loading bookmarks..."),
                                                           "LOAD_MORE": iTermBrowserTemplateLoader.localizedHTML("ui.browser.page.common.load_more", defaultValue: "Load More"),
                                                           "BOOKMARKS_SCRIPT": script
                                                       ])
    }
    
    func start(urlSchemeTask: WKURLSchemeTask, url: URL) {
        let htmlToServe = generateBookmarksHTML()
        
        guard let data = htmlToServe.data(using: .utf8) else {
            urlSchemeTask.didFailWithError(NSError(domain: "iTermBrowserBookmarkViewHandler", code: -1, userInfo: [NSLocalizedDescriptionKey: String(localized: "ui.swift.browser.bookmarks.itermbrowserbookmarkviewhandler.failed_to_encode_html.c166d582", defaultValue: "Failed to encode HTML", bundle: .main, comment: "Error shown when the browser bookmarks page cannot be encoded.")]))
            return
        }
        
        let response = URLResponse(url: url, mimeType: "text/html", expectedContentLength: data.count, textEncodingName: "utf-8")
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }
    
    func handleBookmarkMessage(_ message: [String: Any], webView: iTermBrowserWebView) async {
        DLog("Bookmark message received: \(message)")

        guard let action = message["action"] as? String else {
            DLog("No action in bookmark message")
            return
        }
        
        switch action {
        case "loadBookmarks":
            DLog("Handling bookmark action: \(action)")
            let offset = message["offset"] as? Int ?? 0
            let limit = message["limit"] as? Int ?? 50
            let searchQuery = message["searchQuery"] as? String ?? ""
            let sortBy = message["sortBy"] as? String ?? "dateAdded"
            let tags = message["tags"] as? [String] ?? []
            await loadBookmarks(offset: offset,
                               limit: limit,
                               searchQuery: searchQuery,
                               sortBy: sortBy,
                               tags: tags,
                               webView: webView)

        case "loadTags":
            await loadTags(webView: webView)

        case "deleteBookmark":
            if let url = message["url"] as? String {
                await deleteBookmark(url: url, webView: webView)
            }

        case "navigateToURL":
            if let url = message["url"] as? String {
                delegate?.bookmarkViewHandlerDidNavigateToURL(self, url: url)
            }

        case "clearAllBookmarks":
            await clearAllBookmarks(webView: webView)
            
        default:
            DLog("Unknown bookmark action: \(action)")
        }
    }
    
    // MARK: - Private Implementation
    
    private func loadBookmarks(offset: Int, limit: Int, searchQuery: String, sortBy: String, tags: [String], webView: iTermBrowserWebView) async {
        DLog("Loading bookmarks: offset=\(offset), limit=\(limit), query='\(searchQuery)', sortBy=\(sortBy), tags=\(tags)")
        
        guard let database = await BrowserDatabase.instance(for: user) else {
            RLog("Failed to get database instance")
            await sendBookmarks([], hasMore: false, to: webView)
            return
        }
        
        DLog("Got database instance, querying bookmarks...")
        
        let bookmarks: [BrowserBookmarks]
        let sortOption = BookmarkSortOption(rawValue: sortBy) ?? .dateAdded
        
        if !tags.isEmpty || !searchQuery.isEmpty {
            // Use combined search with tags
            bookmarks = await database.searchBookmarksWithTags(
                searchTerms: searchQuery,
                tags: tags,
                offset: offset,
                limit: limit + 1  // +1 to check if there are more
            )
        } else if !searchQuery.isEmpty {
            // Use text search only
            bookmarks = await database.searchBookmarks(
                terms: searchQuery,
                offset: offset,
                limit: limit + 1
            )
        } else {
            // Get all bookmarks with sorting
            bookmarks = await database.getAllBookmarks(
                sortBy: sortOption,
                offset: offset,
                limit: limit + 1
            )
        }
        
        DLog("Found \(bookmarks.count) bookmarks")
        
        let hasMore = bookmarks.count > limit
        let limitedBookmarks = Array(bookmarks.prefix(limit))
        
        // Get tags for each bookmark
        var bookmarksWithTags: [[String: Any]] = []
        for bookmark in limitedBookmarks {
            let tags = await database.getTagsForBookmark(url: bookmark.url)
            var bookmarkData: [String: Any] = [
                "url": bookmark.url,
                "title": bookmark.title ?? "",
                "dateAdded": bookmark.dateAdded.timeIntervalSince1970
            ]
            if !tags.isEmpty {
                bookmarkData["tags"] = tags
            }
            bookmarksWithTags.append(bookmarkData)
        }
        
        await sendBookmarks(bookmarksWithTags, hasMore: hasMore, to: webView)
    }
    
    private func loadTags(webView: iTermBrowserWebView) async {
        guard let database = await BrowserDatabase.instance(for: user) else {
            await sendTags([], to: webView)
            return
        }
        
        let tags = await database.getAllTags()
        await sendTags(tags, to: webView)
    }
    
    private func deleteBookmark(url: String, webView: iTermBrowserWebView) async {
        guard let database = await BrowserDatabase.instance(for: user) else { return }

        let success = await database.removeBookmark(url: url)
        if success {
            await sendBookmarkDeletedConfirmation(url: url, to: webView)
        }
    }
    
    private func clearAllBookmarks(webView: iTermBrowserWebView) async {
        guard let database = await BrowserDatabase.instance(for: user) else { return }
        await database.deleteAllBookmarks()
        await sendBookmarksClearedConfirmation(to: webView)
    }
    
    @MainActor
    private func sendBookmarks(_ bookmarks: [[String: Any]], hasMore: Bool, to webView: iTermBrowserWebView) async {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: [
                "bookmarks": bookmarks,
                "hasMore": hasMore
            ], options: [])

            if let jsonString = String(data: jsonData, encoding: .utf8) {
                let script = "window.onBookmarksLoaded && window.onBookmarksLoaded(\(jsonString)); 1"
                do {
                    let result = try await webView.safelyEvaluateJavaScript(script)
                    DLog("JavaScript executed successfully: \(String(describing: result))")
                } catch {
                    RLog("Failed to execute JavaScript: \(error)")
                }
            }
        } catch {
            RLog("Failed to serialize bookmarks: \(error)")
        }
    }
    
    @MainActor
    private func sendTags(_ tags: [String], to webView: iTermBrowserWebView) async {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: [
                "tags": tags
            ], options: [])

            if let jsonString = String(data: jsonData, encoding: .utf8) {
                let script = "window.onTagsLoaded && window.onTagsLoaded(\(jsonString)); 1"
                do {
                    let result = try await webView.safelyEvaluateJavaScript(script)
                    DLog("JavaScript executed successfully: \(String(describing: result))")
                } catch {
                    DLog("Failed to execute JavaScript: \(error)")
                }
            }
        } catch {
            DLog("Failed to serialize tags: \(error)")
        }
    }
    
    @MainActor
    private func sendBookmarkDeletedConfirmation(url: String, to webView: iTermBrowserWebView) async {
        let script = "window.onBookmarkDeleted && window.onBookmarkDeleted('\(url.replacingOccurrences(of: "'", with: "\\'"))'); 1"
        do {
            let result = try await webView.safelyEvaluateJavaScript(script)
            DLog("JavaScript executed successfully: \(String(describing: result))")
        } catch {
            DLog("Failed to execute JavaScript: \(error)")
        }
    }
    
    @MainActor
    private func sendBookmarksClearedConfirmation(to webView: iTermBrowserWebView) async {
        let script = "window.onBookmarksCleared && window.onBookmarksCleared(); 1"
        do {
            let result = try await webView.safelyEvaluateJavaScript(script)
            DLog("JavaScript executed successfully: \(String(describing: result))")
        } catch {
            DLog("Failed to execute JavaScript: \(error)")
        }
    }
    
    // MARK: - iTermBrowserPageHandler Protocol
    
    func injectJavaScript(into webView: iTermBrowserWebView) {
        // Bookmark pages don't need JavaScript injection beyond what's in the HTML
    }
    
    func resetState() {
        // Bookmark handler doesn't maintain state that needs resetting
    }
}
