//
//  ReloadBrowserTrigger.swift
//  iTerm2
//
//  Created by George Nachman on 9/19/25.
//

@objc(InjectJavascriptURLTrigger)
class InjectJavascriptURLTrigger: Trigger {
    override var description: String {
        return String(localized: "ui.swift.triggers.injectjavascripttrigger.inject_javascript_url_regex.ad9221c7", defaultValue: "Inject Javascript (URL Regex)", bundle: .main, comment: "User-facing text in InjectJavascriptTrigger.")
    }

    override static var title: String {
        return String(localized: "ui.swift.triggers.injectjavascripttrigger.inject_javascript_url_regex.ad9221c7", defaultValue: "Inject Javascript (URL Regex)", bundle: .main, comment: "User-facing text in InjectJavascriptTrigger.")
    }

    override func takesParameter() -> Bool {
        true
    }
    override var isIdempotent: Bool {
        false
    }
    override func triggerOptionalParameterPlaceholder(withInterpolation interpolation: Bool) -> String? {
        return String(localized: "ui.swift.triggers.injectjavascripttrigger.javascript.75712c3e", defaultValue: "Javascript", bundle: .main, comment: "User-facing text in InjectJavascriptTrigger.")
    }
    override func triggerOptionalDefaultParameterValue(withInterpolation interpolation: Bool) -> String? {
        "console.log('Testing');"
    }
    override var allowedMatchTypes: Set<NSNumber> {
        return Set([ NSNumber(value: iTermTriggerMatchType.urlRegex.rawValue) ])
    }
    override var matchType: iTermTriggerMatchType {
        .urlRegex
    }
    override var isBrowserTrigger: Bool {
        true
    }
}

extension InjectJavascriptURLTrigger: BrowserTrigger {
    func performBrowserAction(matchID: String?,
                              urlCaptures: [String],
                              contentCaptures: [String]?,
                              in client: any BrowserTriggerClient) async -> [BrowserTriggerAction] {
        let scheduler = client.scopeProvider.triggerCallbackScheduler()
        await withCheckedContinuation { continuation in
            paramWithBackreferencesReplaced(withValues: urlCaptures + (contentCaptures ?? []),
                                            absLine: -1,
                                            scope: client.scopeProvider,
                                            useInterpolation: client.useInterpolation).then { message in
                scheduler.scheduleTriggerCallback {
                    Task {
                        client.triggerDelegate?.browserTriggerInject(message as String)
                        continuation.resume()
                    }
                }
            }
        }
        return []
    }
}

@objc(InjectJavascriptContentTrigger)
class InjectJavascriptContentTrigger: Trigger {
    override var description: String {
        return String(localized: "ui.swift.triggers.injectjavascripttrigger.inject_javascript_content_regex.a9f64e67", defaultValue: "Inject Javascript (Content Regex)", bundle: .main, comment: "User-facing text in InjectJavascriptTrigger.")
    }

    override static var title: String {
        return String(localized: "ui.swift.triggers.injectjavascripttrigger.inject_javascript_content_regex.a9f64e67", defaultValue: "Inject Javascript (Content Regex)", bundle: .main, comment: "User-facing text in InjectJavascriptTrigger.")
    }

    override func takesParameter() -> Bool {
        true
    }
    override var isIdempotent: Bool {
        false
    }
    override func triggerOptionalParameterPlaceholder(withInterpolation interpolation: Bool) -> String? {
        return String(localized: "ui.swift.triggers.injectjavascripttrigger.javascript.75712c3e", defaultValue: "Javascript", bundle: .main, comment: "User-facing text in InjectJavascriptTrigger.")
    }
    override func triggerOptionalDefaultParameterValue(withInterpolation interpolation: Bool) -> String? {
        "console.log('Testing');"
    }
    override var allowedMatchTypes: Set<NSNumber> {
        return Set([ NSNumber(value: iTermTriggerMatchType.pageContentRegex.rawValue) ])
    }
    override var matchType: iTermTriggerMatchType {
        .pageContentRegex
    }
    override var isBrowserTrigger: Bool {
        true
    }
}

extension InjectJavascriptContentTrigger: BrowserTrigger {
    func performBrowserAction(matchID: String?,
                              urlCaptures: [String],
                              contentCaptures: [String]?,
                              in client: any BrowserTriggerClient) async -> [BrowserTriggerAction] {
        let scheduler = client.scopeProvider.triggerCallbackScheduler()
        await withCheckedContinuation { continuation in
            paramWithBackreferencesReplaced(withValues: urlCaptures + (contentCaptures ?? []),
                                            absLine: -1,
                                            scope: client.scopeProvider,
                                            useInterpolation: client.useInterpolation).then { message in
                scheduler.scheduleTriggerCallback {
                    Task {
                        client.triggerDelegate?.browserTriggerInject(message as String)
                        continuation.resume()
                    }
                }
            }
        }
        return []
    }
}
