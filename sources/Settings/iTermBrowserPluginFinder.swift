//
//  iTermBrowserPluginFinder.swift
//  iTerm2SharedARC
//
//  Created by George Nachman on 9/24/25.
//

import AppKit

@objc
class iTermBrowserPluginFinder: NSObject, NSOpenSavePanelDelegate {
    @objc static var instance: iTermBrowserPluginFinder?
    private let allowedBundleName = "iTermBrowserPlugin"

    @objc
    func openFindPanel(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.delegate = self
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.title = String(localized: "ui.swift.settings.itermbrowserpluginfinder.select_0.5d348f18", defaultValue: "Select \(allowedBundleName)", bundle: .main, comment: "User-facing text in iTermBrowserPluginFinder.")
        panel.prompt = String(localized: "ui.swift.settings.itermbrowserpluginfinder.choose.c7f93783", defaultValue: "Choose", bundle: .main, comment: "User-facing text in iTermBrowserPluginFinder.")
        panel.message = String(localized: "ui.swift.settings.itermbrowserpluginfinder.select_0.5fd5246b", defaultValue: "Select \(allowedBundleName).", bundle: .main, comment: "User-facing text in iTermBrowserPluginFinder.")
        panel.allowedContentTypes = [.bundle, .application, .applicationBundle]
        panel.begin { response in
            if response == .OK {
                completion(panel.url)
            } else {
                completion(nil)
            }
        }
    }

    // MARK: - NSOpenSavePanelDelegate

    func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        guard url.pathExtension == "app" else {
            return false
        }
        return url.deletingPathExtension().lastPathComponent == allowedBundleName
    }

    func panel(_ sender: Any, validate url: URL) throws {
        let isCorrect = url.deletingPathExtension().lastPathComponent == allowedBundleName
        if !isCorrect {
            throw NSError(domain: NSCocoaErrorDomain,
                          code: NSUserCancelledError,
                          userInfo: [NSLocalizedDescriptionKey:
                                     String(localized: "ui.swift.settings.itermbrowserpluginfinder.you_must_select_0.d648f864", defaultValue: "You must select \(allowedBundleName)", bundle: .main, comment: "User-facing text in iTermBrowserPluginFinder.")])
        }
    }
}
