//
//  MenuItemPopupView.swift
//  iTerm2SharedARC
//
//  Created by George Nachman on 11/29/21.
//

import Foundation
import SearchableComboListView

private extension SearchableComboViewGroup {
    static func fromMainMenu() -> [SearchableComboViewGroup] {
        guard let mainMenu = NSApp.mainMenu else {
            return []
        }
        var nextTag = 1
        let tagProvider = { () -> Int in
            defer {
                nextTag += 1
            }
            return nextTag
        }
        return groupsFromMenuItems(mainMenu, ancestors: [], tagProvider: tagProvider)
    }

    private static func groupsFromMenuItems(_ menu: NSMenu,
                                            ancestors: [NSMenuItem],
                                            tagProvider: () -> (Int)) -> [SearchableComboViewGroup] {
        return menu.items.flatMap { item -> [SearchableComboViewGroup] in
            guard let submenu = item.submenu else {
                return []
            }
            guard submenu != NSApp.servicesMenu else {
                return []
            }
            let items = SearchableComboViewItem.itemsFromMenu(submenu,
                                                              ancestors: ancestors + [item],
                                                              tagProvider: tagProvider)
            let path = ancestors.map { $0.title }
            let topGroup = SearchableComboViewGroup((path + [item.title]).joined(separator: " > "),
                                                    items: items)
            let innerGroups = groupsFromMenuItems(submenu,
                                                  ancestors: ancestors + [item],
                                                  tagProvider: tagProvider)
            if items.isEmpty {
                return innerGroups
            }
            return [topGroup] + innerGroups
        }
    }
}

private extension NSMenuItem {
    func  isWindowMenuItem(parent: NSMenu) -> Bool {
        guard parent == NSApp.windowsMenu else {
            return false
        }
        if let action = action, NSStringFromSelector(action) == "_toggleIPad:" {
            // SideCar "move to ipad" item.
            return true
        }
        guard target as? NSWindow != nil else {
            return false
        }
        return action == #selector(NSWindow.makeKeyAndOrderFront(_:))
    }

    func isMoveToDisplayItem(parent: NSMenu) -> Bool {
        guard parent == NSApp.windowsMenu else {
            return false
        }
        guard let selector = action else {
            return false
        }
        return NSStringFromSelector(selector) == "_moveToDisplay:"
    }

    private enum ItemType {
        case newWindow
        case newTab
        case other
    }

    private func itemType(descendsFromProfiles: Bool) -> ItemType {
        guard descendsFromProfiles else {
            return .other
        }
        guard !self.hasSubmenu else {
            return .other
        }
        guard let identifier = self.identifier.map({ String($0 as NSString) }) else {
            return .other
        }
        if identifier.hasPrefix(iTermProfileModelNewTabMenuItemIdentifierPrefix) {
            return .newTab
        }
        if identifier.hasPrefix(iTermProfileModelNewWindowMenuItemIdentifierPrefix) {
            return .newWindow
        }
        return .other
    }

    func title(descendsFromProfiles: Bool) -> String {
        switch itemType(descendsFromProfiles: descendsFromProfiles) {
        case .newWindow:
            return String(localized: "ui.swift.settings.menuitempopupview.0_new_window.83f5d25f",
                          defaultValue: "\(self.title) — New Window",
                          bundle: .main,
                          comment: "Searchable menu item title for opening a profile in a new window.")
        case .newTab:
            return String(localized: "ui.swift.settings.menuitempopupview.0_new_tab.90b97d6d",
                          defaultValue: "\(self.title) — New Tab",
                          bundle: .main,
                          comment: "Searchable menu item title for opening a profile in a new tab.")
        case .other:
            return self.title
        }
    }
}

private extension SearchableComboViewItem {
    static func itemsFromMenu(_ menu: NSMenu,
                              ancestors: [NSMenuItem],
                              tagProvider: () -> (Int)) -> [SearchableComboViewItem] {
        let standardItems = menu.items.compactMap { menuItem -> SearchableComboViewItem? in
            if menuItem.hasSubmenu {
                return nil
            }
            if menuItem.isHidden {
                return nil
            }
            if menuItem.isSeparatorItem {
                return nil
            }
            if menuItem.action == nil {
                return nil
            }
            return SearchableComboViewItem.fromMenuItem(menuItem,
                                                        parent: menu,
                                                        ancestors: ancestors,
                                                        tagProvider: tagProvider)
        }
        if menu == NSApp.windowsMenu {
            return standardItems + moveToScreenItems(tagProvider: tagProvider)
        }
        return standardItems
    }

    static private func moveToScreenItems(tagProvider: () -> (Int)) -> [SearchableComboViewItem] {
        return NSScreen.screens.map { screen in
            return SearchableComboViewItem(String(localized: "ui.swift.settings.menuitempopupview.move_to_0.699bb2f5",
                                                  defaultValue: "Move to \(screen.it_uniqueName())",
                                                  bundle: .main,
                                                  comment: "Searchable Window-menu action for moving a window to a display."),
                                           tag: tagProvider(),
                                           identifier: screen.it_uniqueKey())
        }
    }
    private static func fromMenuItem(_ item: NSMenuItem,
                                     parent: NSMenu,
                                     ancestors: [NSMenuItem],
                                     tagProvider: () -> (Int)) -> SearchableComboViewItem? {
        guard !item.isSeparatorItem else {
            return nil
        }
        guard !item.isWindowMenuItem(parent: parent) else {
            return nil
        }
        guard !item.isMoveToDisplayItem(parent: parent) else {
            return nil
        }
        let profilesIdentifier = NSUserInterfaceItemIdentifier(".Profiles")
        let descendsFromProfiles = ancestors.contains { $0.identifier == profilesIdentifier }
        return SearchableComboViewItem(item.title(descendsFromProfiles: descendsFromProfiles),
                                       tag: tagProvider(),
                                       identifier: item.identifier.map { $0 as NSString as String })
    }
}

@objc(iTermMenuItemPopupView)
class MenuItemPopupView: NSView {
    @objc private(set) var comboView: SearchableComboView? = nil
    @IBOutlet var delegate: SearchableComboViewDelegate? {
        set {
            comboView?.delegate = newValue
        }
        get {
            return comboView?.delegate
        }
    }

    init() {
        super.init(frame: NSRect.zero)
        reloadData()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        reloadData()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        reloadData()
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        comboView?.frame = self.bounds
    }

    @objc func reloadData() {
        let identifier = selectedIdentifier
        comboView?.removeFromSuperview()
        let newComboView = SearchableComboView(SearchableComboViewGroup.fromMainMenu(),
                                               defaultTitle: String(localized: "ui.swift.settings.menuitempopupview.select_menu_item.b037b203",
                                                                    defaultValue: "Select Menu Item…",
                                                                    bundle: .main,
                                                                    comment: "Placeholder title in the searchable menu-item picker."))
        newComboView.frame = self.bounds
        newComboView.delegate = comboView?.delegate
        addSubview(newComboView)
        comboView = newComboView
        if let identifier = identifier {
            _ = select(identifier: identifier)
        }
    }

    @objc var selectedTitle: String? {
        return comboView?.selectedItem?.title
    }

    @objc var selectedIdentifier: String? {
        return comboView?.selectedItem?.identifier.map { $0 as NSString as String }
    }

    @objc(selectItemWithTitle:) func select(title: String) {
        _ = comboView?.selectItem(withTitle: title)
    }

    @discardableResult
    @objc(selectItemWithIdentifier:) func select(identifier: String) -> Bool {
        return comboView?.selectItem(withIdentifier: NSUserInterfaceItemIdentifier(identifier)) ?? false
    }
}
