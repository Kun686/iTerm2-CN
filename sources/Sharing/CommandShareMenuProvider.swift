//
//  CommandShareMenuProvider.swift
//  iTerm2SharedARC
//
//  Created by George Nachman on 5/30/24.
//

import Foundation

@objc(iTermCommandShareMenuProvider)
@MainActor
class CommandShareMenuProvider: NSObject {
    private let mark: VT100ScreenMarkReading
    private let promisedContent: iTermRenegablePromise<NSAttributedString>
    private let defaultBackgroundColor: NSColor
    private let commandURL: URL?

    @objc
    init(mark: VT100ScreenMarkReading,
         promisedContent: iTermRenegablePromise<NSAttributedString>,
         defaultBackgroundColor: NSColor,
         commandURL: URL?) {
        self.mark = mark
        self.promisedContent = promisedContent
        self.defaultBackgroundColor = defaultBackgroundColor
        self.commandURL = commandURL
    }

    @objc
    func pop(locationInWindow: NSPoint,
             view: NSView) {
        guard let window = view.window else {
            return
        }
        let menu = SimpleContextMenu()
        let command = mark.fullCommand ?? ""
        if !command.isEmpty {
            let snippetTitle = mark.firstLineOfCommand.flatMap { $0.isEmpty ? nil : $0 } ?? command
            menu.addItem(title: String(localized: "ui.swift.sharing.commandsharemenuprovider.add_command_as_snippet.1d7e8a18", defaultValue: "Add Command as Snippet", bundle: .main, comment: "User-facing text in CommandShareMenuProvider.")) { [weak window] in
                CommandShareMenuProvider.addCommandAsSnippet(title: snippetTitle,
                                                             value: command,
                                                             window: window,
                                                             locationInWindow: locationInWindow)
            }
        }

        menu.addSeparator()

        let mark = self.mark
        let promisedContent = self.promisedContent
        let defaultBackgroundColor = self.defaultBackgroundColor
        menu.addItem(title: String(localized: "ui.swift.sharing.commandsharemenuprovider.save_command_output.50dceb6f", defaultValue: "Save Command & Output…", bundle: .main, comment: "User-facing text in CommandShareMenuProvider.")) { [weak window] in
            CommandShareMenuProvider.saveCommandAndOutput(promisedContent: promisedContent,
                                                          defaultBackgroundColor: defaultBackgroundColor,
                                                          mark: mark,
                                                          window: window)
        }

        menu.addSeparator()

        menu.addItem(title: String(localized: "ui.swift.sharing.commandsharemenuprovider.share_command_output.383ff6e0", defaultValue: "Share Command Output…", bundle: .main, comment: "User-facing text in CommandShareMenuProvider.")) { [weak view] in
            if let view {
                CommandShareMenuProvider.shareCommandOutput(locationInWindow: locationInWindow,
                                                            promisedContent: promisedContent,
                                                            view: view)
            }
        }

        menu.addSeparator()

        if let commandURL {
            menu.addItem(title: String(localized: "ui.swift.sharing.commandsharemenuprovider.copy_command_url_to_clipboard.f165a68f", defaultValue: "Copy Command URL to Clipboard", bundle: .main, comment: "User-facing text in CommandShareMenuProvider.")) { [weak window] in
                CommandShareMenuProvider.copyCommandURL(url: commandURL,
                                                        window: window,
                                                        locationInWindow: locationInWindow)
            }
            menu.addItem(title: String(localized: "ui.swift.sharing.commandsharemenuprovider.share_command_url.3daeb75f", defaultValue: "Share Command URL…", bundle: .main, comment: "User-facing text in CommandShareMenuProvider.")) { [weak view] in
                if let view {
                    CommandShareMenuProvider.shareCommandURL(locationInWindow: locationInWindow,
                                                             url: commandURL,
                                                             view: view)
                }
            }
        }

        if !menu.isEmpty, let event = NSApp.currentEvent {
            menu.show(in: view, for: event)
        }
    }

    private static func addCommandAsSnippet(title: String,
                                            value: String,
                                            window: NSWindow?,
                                            locationInWindow: NSPoint) {
        let snippet = iTermSnippet(title: title,
                                   value: value,
                                   guid: UUID().uuidString,
                                   tags: [],
                                   escaping: .none,
                                   version: iTermSnippet.currentVersion())
        iTermSnippetsModel.sharedInstance().addSnippet(snippet)
        guard let window else {
            return
        }
        let point = window.convertPoint(toScreen: locationInWindow)
        ToastWindowController.showToast(withMessage: String(localized: "ui.swift.sharing.commandsharemenuprovider.snippet_added.0a54b0a6", defaultValue: "Snippet Added", bundle: .main, comment: "Confirmation shown after adding a command as a snippet."),
                                        duration: 1,
                                        topLeftScreenCoordinate: point,
                                        pointSize: 12)
    }

    private static func defaultCommand(_ maybeCommand: String?) -> String {
        let fallback = String(localized: "ui.swift.sharing.commandsharemenuprovider.iterm2_command.2d85e969", defaultValue: "iTerm2 Command", bundle: .main, comment: "Default filename for a saved command and its output.")
        guard let justCommand = maybeCommand else {
            return fallback
        }
        let command = justCommand as NSString
        guard let path = command.componentsInShellCommand().first else {
            return fallback
        }
        return path.lastPathComponent
    }

    private static func saveCommandAndOutput(promisedContent: iTermRenegablePromise<NSAttributedString>,
                                             defaultBackgroundColor: NSColor,
                                             mark: VT100ScreenMarkReading,
                                             window: NSWindow?) {
        guard let window else {
            return
        }
        let saver = AttributedStringSaver(promisedContent)
        saver.documentAttributes = [ .backgroundColor: defaultBackgroundColor]
        saver.save(defaultName: defaultCommand(mark.fullCommand), window: window)
    }

    private static func copyCommandURL(url: URL, window: NSWindow?, locationInWindow: NSPoint) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let objects: [any NSPasteboardWriting] = [ url as NSURL, url.absoluteString as NSString ]
        pasteboard.writeObjects(objects)

        guard let window else {
            return
        }
        let point = window.convertPoint(toScreen: locationInWindow)
        ToastWindowController.showToast(withMessage: String(localized: "ui.swift.sharing.commandsharemenuprovider.copied.8d525e5f", defaultValue: "Copied", bundle: .main, comment: "Confirmation shown after copying a command URL."),
                                        duration: 1,
                                        topLeftScreenCoordinate: point,
                                        pointSize: 12)
    }

    private static func shareCommandURL(locationInWindow: NSPoint,
                                        url: URL,
                                        view: NSView) {
        var viewRect = NSRect()
        viewRect.origin = locationInWindow
        let picker = NSSharingServicePicker(items: [url])
        picker.show(relativeTo: viewRect, of: view, preferredEdge: .minY)
    }

    private static func shareCommandOutput(locationInWindow: NSPoint,
                                           promisedContent: iTermRenegablePromise<NSAttributedString>,
                                           view: NSView) {
        var viewRect = NSRect()
        viewRect.origin = locationInWindow
        promisedContent.wait().whenFirst { [weak view] attributedString in
            guard let view else {
                return
            }
            let picker = NSSharingServicePicker(items: [attributedString])
            picker.show(relativeTo: viewRect, of: view, preferredEdge: .minY)
        }
    }
}
