//
//  iTermStatusBarTriggersComponent.swift
//  iTerm2SharedARC
//
//  Created by George Nachman on 7/2/21.
//

import Foundation

@objc(iTermTriggersDataSource)
protocol TriggersDataSource {
    var numberOfTriggers: Int { get }
    var triggerNames: [String] { get }
    var enabledTriggerIndexes: NSIndexSet { get }
    @objc(toggleTriggerAtIndex:) func toggleTrigger(index: Int)
    @objc(addTrigger) func addTrigger()
    @objc(editTriggers) func editTriggers()
}

@objc(iTermStatusBarTriggersComponent)
class StatusBarTriggersComponent: iTermStatusBarTextComponent {
    private var dataSource: TriggersDataSource? {
        return delegate?.statusBarComponentTriggersDataSource(self)
    }

    override static var compatibleProfileTypes: ProfileType {
        [.terminal]
    }

    override func statusBarComponentIcon() -> NSImage {
        guard let image = NSImage.it_cacheableImageNamed("StatusBarIconTriggers", for: Self.self) else {
            AppSignatureValidator.warn(
                reason: "The icon for the status bar “triggers” component is missing from the app bundle.")
            it_fatalError("Missing StatsBarIconTriggers")
        }
        return image
    }

    override func statusBarComponentShortDescription() -> String {
        return String(localized: "ui.swift.statusbar.components.itermstatusbartriggerscomponent.triggers_menu.36a7eb58", defaultValue: "Triggers Menu", bundle: .main, comment: "User-facing text in iTermStatusBarTriggersComponent.")
    }

    override func statusBarComponentDetailedDescription() -> String {
        return String(localized: "ui.swift.statusbar.components.itermstatusbartriggerscomponent.when_clicked_opens_a_menu_of_triggers_you.41431412", defaultValue: "When clicked, opens a menu of triggers. You can use it to enable or disable triggers.", bundle: .main, comment: "User-facing text in iTermStatusBarTriggersComponent.")
    }

    override func statusBarComponentExemplar(withBackgroundColor backgroundColor: NSColor, textColor: NSColor) -> Any {
        return String(localized: "ui.swift.statusbar.components.itermstatusbartriggerscomponent.triggers.e5ace1dc", defaultValue: "Triggers…", bundle: .main, comment: "User-facing text in iTermStatusBarTriggersComponent.")
    }

    override func statusBarComponentCanStretch() -> Bool {
        return true
    }

    private var stringValue: String {
        return String(localized: "ui.swift.statusbar.components.itermstatusbartriggerscomponent.triggers.e5ace1dc", defaultValue: "Triggers…", bundle: .main, comment: "User-facing text in iTermStatusBarTriggersComponent.")
    }

    override func stringValueForCurrentWidth() -> String? {
        return stringValue
    }

    override var stringVariants: [String]? {
        return [ stringValue ]
    }

    override func statusBarComponentCopyableString() -> String? {
        return nil
    }

    override func statusBarComponentHandlesClicks() -> Bool {
        return true
    }

    override func statusBarComponentIsEmpty() -> Bool {
        return (dataSource?.numberOfTriggers ?? 0) > 0
    }

    override func statusBarComponentDidClick(with view: NSView) {
        openMenu(view)
    }

    override func statusBarComponentMouseDown(with view: NSView) {
        openMenu(view)
    }

    override func statusBarComponentHandlesMouseDown() -> Bool {
        return true
    }

    private func openMenu(_ view: NSView) {
        guard let containingView = view.superview,
              let enabledIndexes = dataSource?.enabledTriggerIndexes else {
            return
        }
        let menu = NSMenu()
        for (index, triggerName) in (dataSource?.triggerNames ?? []).enumerated() {
            let item = NSMenuItem(title: triggerName, action: #selector(toggleTrigger(_:)), keyEquivalent: "")
            item.identifier = NSUserInterfaceItemIdentifier("\(index)")
            item.target = self
            item.state = enabledIndexes.contains(index) ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: String(localized: "ui.swift.statusbar.components.itermstatusbartriggerscomponent.add_trigger.f2bbdcd6", defaultValue: "Add Trigger…", bundle: .main, comment: "User-facing text in iTermStatusBarTriggersComponent."), action: #selector(addTrigger(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: String(localized: "ui.swift.statusbar.components.itermstatusbartriggerscomponent.edit_triggers.094b1ca3", defaultValue: "Edit Triggers…", bundle: .main, comment: "User-facing text in iTermStatusBarTriggersComponent."), action: #selector(editTriggers(_:)), keyEquivalent: ""))

        menu.popUp(positioning: menu.items.first!, at: NSPoint.zero, in: containingView)
    }

    @objc(toggleTrigger:)
    public func toggleTrigger(_ sender: NSMenuItem) {
        guard let identifier = sender.identifier,
              let index = Int(identifier.rawValue),
              let count = dataSource?.numberOfTriggers,
              index >= 0 && index < count else {
            return
        }

        dataSource?.toggleTrigger(index: index)
    }

    @objc(addTrigger:)
    public func addTrigger(_ sender: Any) {
        dataSource?.addTrigger()
    }

    @objc(editTriggers:)
    public func editTriggers(_ sender: Any) {
        dataSource?.editTriggers()
    }
}
