//
//  HyperlinkBrowserTrigger.swift
//  iTerm2
//
//  Created by George Nachman on 8/3/25.
//

class HyperlinkBrowserTrigger: Trigger {
    override var description: String {
        let parameter = param as? String ?? String(localized: "ui.swift.triggers.hyperlinkbrowsertrigger.nil_parameter.930f8a95", defaultValue: "(nil)", bundle: .main, comment: "Fallback shown when a hyperlink trigger has no URL parameter.")
        return String(localized: "ui.swift.triggers.hyperlinkbrowsertrigger.make_hyperlink_with_url_0.30e7c32f", defaultValue: "Make Hyperlink with URL “\(parameter)”", bundle: .main, comment: "User-facing text in HyperlinkBrowserTrigger.")
    }
    override static var title: String {
        String(localized: "ui.swift.triggers.hyperlinkbrowsertrigger.make_hyperlink.0df9e2a5", defaultValue: "Make Hyperlink…", bundle: .main, comment: "User-facing text in HyperlinkBrowserTrigger.")
    }
    override func takesParameter() -> Bool {
        true
    }
    override var isIdempotent: Bool {
        true
    }
    override func triggerOptionalParameterPlaceholder(withInterpolation interpolation: Bool) -> String? {
        return triggerOptionalDefaultParameterValue(withInterpolation: interpolation)
    }
    override func triggerOptionalDefaultParameterValue(withInterpolation interpolation: Bool) -> String? {
        if interpolation {
            "https://\\(match0)"
        } else {
            "https://\\0"
        }
    }
    override var allowedMatchTypes: Set<NSNumber> {
        return Set([ NSNumber(value: iTermTriggerMatchType.pageContentRegex.rawValue )])
    }
    override var matchType: iTermTriggerMatchType {
        .pageContentRegex
    }
    override var isBrowserTrigger: Bool {
        true
    }
}

extension HyperlinkBrowserTrigger: BrowserTrigger {
    func performBrowserAction(matchID: String?,
                              urlCaptures: [String],
                              contentCaptures: [String]?,
                              in client: any BrowserTriggerClient) async -> [BrowserTriggerAction] {
        guard let matchID else {
            DLog("No match id")
            return []
        }
        let scheduler = client.scopeProvider.triggerCallbackScheduler()
        paramWithBackreferencesReplaced(withValues: urlCaptures + (contentCaptures ?? []),
                                        absLine: -1,
                                        scope: client.scopeProvider,
                                        useInterpolation: client.useInterpolation).then { message in
            scheduler.scheduleTriggerCallback {
                client.triggerDelegate?.browserTriggerMakeHyperlink(matchID: matchID,
                                                                    url: message as String)
            }
        }
        return []
    }
}
