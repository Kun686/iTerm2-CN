import AppKit
import XCTest
@testable import iTerm2SharedARC

final class MenuItemPopupLocalizationTests: XCTestCase {
    private func withSyntheticMenu(_ body: (NSMenu, Bool) throws -> Void) throws {
        guard Thread.isMainThread,
              iTermUserDefaults.customSuiteName() == "iterm2-tests" else {
            XCTFail("Menu fixtures require main and the isolated ModernTests suite")
            return
        }
        let language = try XCTUnwrap(Bundle.main.preferredLocalizations.first)
        XCTAssertTrue(["en", "zh-Hans"].contains(language))
        let original = NSApp.mainMenu
        let originalWindows = NSApp.windowsMenu
        let originalServices = NSApp.servicesMenu
        let menu = NSMenu(title: "Synthetic main menu")
        menu.autoenablesItems = false
        NSApp.mainMenu = menu
        defer {
            NSApp.mainMenu = original
            NSApp.windowsMenu = originalWindows
            NSApp.servicesMenu = originalServices
            XCTAssertTrue(NSApp.mainMenu === original)
        }
        try body(menu, language == "zh-Hans")
    }

    private func addSubmenu(to menu: NSMenu, title: String, identifier: String) -> NSMenu {
        let root = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        root.identifier = NSUserInterfaceItemIdentifier(identifier)
        let submenu = NSMenu(title: title)
        submenu.autoenablesItems = false
        root.submenu = submenu
        menu.addItem(root)
        return submenu
    }

    private func addItem(to menu: NSMenu, title: String, identifier: String) -> NSMenuItem {
        // Never dispatch the selector or post an event. These items only supply
        // metadata to the real picker and the existing shortcut matcher.
        let item = NSMenuItem(title: title, action: #selector(syntheticAction(_:)), keyEquivalent: "")
        item.identifier = NSUserInterfaceItemIdentifier(identifier)
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc private func syntheticAction(_ sender: Any?) {
        XCTFail("Menu metadata tests must not execute actions")
    }

    @objc(restoreArchive:) private func metadataRestoreArchive(_ sender: Any?) {
        XCTFail("Built-in action metadata must not be dispatched by picker tests")
    }

    private func localizedFullscreenMenuTitle(chinese: Bool) -> String {
        let title = Bundle.main.localizedString(forKey: "1257.title",
                                               value: "Show Tabs in Fullscreen",
                                               table: "MainMenu")
        XCTAssertEqual(title, chinese ? "在全屏幕中显示标签页" : "Show Tabs in Fullscreen")
        return title
    }

    func testProfileSuffixesLocalizeWithoutChangingNamesOrIdentifiers() throws {
        try withSyntheticMenu { main, chinese in
            let profiles = self.addSubmenu(to: main, title: "Synthetic profiles", identifier: ".Profiles")
            let name = "synthetic-用户 %@ \\n"
            let fixtures = [
                (iTermProfileModelNewWindowMenuItemIdentifierPrefix + "fixture", "New Window", "新建窗口"),
                (iTermProfileModelNewTabMenuItemIdentifierPrefix + "fixture", "New Tab", "新建标签页")
            ]
            let items = fixtures.map { self.addItem(to: profiles, title: name, identifier: $0.0) }
            let popup = MenuItemPopupView(frame: .zero)
            for (index, fixture) in fixtures.enumerated() {
                XCTAssertTrue(popup.select(identifier: fixture.0))
                let title = name + " — " + (chinese ? fixture.2 : fixture.1)
                XCTAssertEqual(popup.comboView?.title, title)
                let selectedTag = popup.comboView?.selectedTag()
                popup.select(title: title)
                XCTAssertEqual(popup.comboView?.selectedTag(), selectedTag)
                XCTAssertEqual(items[index].title, name)
                XCTAssertEqual(items[index].identifier?.rawValue, fixture.0)
                XCTAssertEqual(items[index].action, #selector(self.syntheticAction(_:)))
            }
        }
    }

    func testHiddenActionlessAndSeparatorItemsRemainIneligible() throws {
        try withSyntheticMenu { main, _ in
            let submenu = self.addSubmenu(to: main, title: "Synthetic group", identifier: "synthetic.group")
            let visible = self.addItem(to: submenu, title: "Visible", identifier: "synthetic.visible")
            let hidden = self.addItem(to: submenu, title: "Hidden", identifier: "synthetic.hidden")
            hidden.isHidden = true
            let actionless = self.addItem(to: submenu, title: "Actionless", identifier: "synthetic.actionless")
            actionless.action = nil
            let separator = NSMenuItem.separator()
            separator.identifier = NSUserInterfaceItemIdentifier("synthetic.separator")
            submenu.addItem(separator)
            let popup = MenuItemPopupView(frame: .zero)
            XCTAssertTrue(popup.select(identifier: try XCTUnwrap(visible.identifier).rawValue))
            for item in [hidden, actionless, separator] {
                XCTAssertFalse(popup.select(identifier: try XCTUnwrap(item.identifier).rawValue))
            }
        }
    }

    func testLegacyTitleRestoresSelectionAfterMenuIsLocalized() throws {
        try withSyntheticMenu { main, chinese in
            let submenu = self.addSubmenu(to: main, title: "Synthetic view", identifier: "synthetic.view")
            let originalTitle = "Show Tabs in Fullscreen"
            let displayedTitle = self.localizedFullscreenMenuTitle(chinese: chinese)
            let item = self.addItem(to: submenu, title: displayedTitle, identifier: originalTitle)
            let popup = MenuItemPopupView(frame: .zero)
            // Positive control uses the exact same eligible item and translated
            // label. Only the original binding's absence of an ID differs.
            XCTAssertTrue(popup.select(identifier: originalTitle))
            XCTAssertEqual(popup.comboView?.title, displayedTitle)
            let action = try XCTUnwrap(iTermKeyBindingAction.withAction(
                .ACTION_SELECT_MENU_ITEM, parameter: originalTitle, escaping: .none, applyMode: .currentSession))
            let original = action.dictionaryValue
            popup.select(title: action.parameter)
            XCTAssertEqual(popup.comboView?.title, displayedTitle,
                           "Localizing the menu must not lose a legacy title-only binding")
            XCTAssertEqual(action.dictionaryValue as NSDictionary, original as NSDictionary)
            XCTAssertEqual(item.identifier?.rawValue, originalTitle)
        }
    }

    func testLegacyShortcutMatcherStillRecognizesTheLocalizedMenuItem() throws {
        try withSyntheticMenu { main, chinese in
            let submenu = self.addSubmenu(to: main, title: "Synthetic view", identifier: "synthetic.view")
            let originalTitle = "Show Tabs in Fullscreen"
            let item = self.addItem(to: submenu,
                                    title: self.localizedFullscreenMenuTitle(chinese: chinese),
                                    identifier: originalTitle)
            XCTAssertTrue(ITAddressBookMgr.shortcutIdentifier(originalTitle, title: originalTitle, matchesItem: item))
            XCTAssertTrue(ITAddressBookMgr.shortcutIdentifier(nil, title: item.title, matchesItem: item))
            XCTAssertFalse(ITAddressBookMgr.shortcutIdentifier("synthetic.unknown", title: item.title, matchesItem: item))
            XCTAssertTrue(ITAddressBookMgr.shortcutIdentifier(nil, title: originalTitle, matchesItem: item),
                          "A legacy binding that matched before localization must still match")
        }
    }

    func testRestoreAndReloadPreserveCompleteParametersUntilSelectionChanges() throws {
        try withSyntheticMenu { main, chinese in
            let submenu = self.addSubmenu(to: main, title: "Synthetic view", identifier: "synthetic.view")
            let identifier = "Show Tabs in Fullscreen"
            let displayed = self.localizedFullscreenMenuTitle(chinese: chinese)
            _ = self.addItem(to: submenu, title: displayed, identifier: identifier)
            _ = self.addItem(to: submenu, title: "Synthetic other", identifier: "synthetic.other")
            let popup = MenuItemPopupView(frame: .zero)
            for parameter in [identifier,
                              "在全屏幕中显示标签页",
                              "Old display title\n" + identifier,
                              "Old display title\n" + identifier + "\nopaque %@ 用户\n"] {
                XCTAssertTrue(popup.restore(parameter: parameter))
                XCTAssertEqual(popup.selectedIdentifier, identifier)
                XCTAssertEqual(popup.selectedTitle, displayed)
                XCTAssertEqual(popup.selectedParameter, parameter)
                popup.reloadData()
                XCTAssertEqual(popup.selectedParameter, parameter)
                XCTAssertEqual(popup.selectedIdentifier, identifier)
            }
            // Use the real combo selection path, as a user's selection does.
            XCTAssertTrue(popup.comboView?.selectItem(withIdentifier:
                NSUserInterfaceItemIdentifier("synthetic.other")) == true)
            XCTAssertEqual(popup.selectedParameter, "Synthetic other\nsynthetic.other")
            popup.reloadData()
            XCTAssertEqual(popup.selectedParameter, "Synthetic other\nsynthetic.other")
        }
    }

    func testUnavailableParameterIsNotErasedOrFalselySelected() throws {
        try withSyntheticMenu { main, chinese in
            let submenu = self.addSubmenu(to: main, title: "Synthetic view", identifier: "synthetic.view")
            _ = self.addItem(to: submenu, title: self.localizedFullscreenMenuTitle(chinese: chinese),
                            identifier: "Show Tabs in Fullscreen")
            let popup = MenuItemPopupView(frame: .zero)
            let legacy = chinese ? "Show Tabs in Fullscreen" : "在全屏幕中显示标签页"
            for parameter in ["Unavailable action\nunknown.id\nopaque\n",
                              legacy + "\nunknown.id\nopaque\n"] {
                XCTAssertFalse(popup.restore(parameter: parameter))
                XCTAssertNil(popup.selectedIdentifier)
                XCTAssertNil(popup.selectedTitle)
                XCTAssertEqual(popup.selectedParameter, parameter)
                popup.reloadData()
                XCTAssertNil(popup.selectedTitle)
                XCTAssertEqual(popup.selectedParameter, parameter)
            }
            XCTAssertFalse(popup.select(identifier: "unknown.id"))
            XCTAssertNil(popup.selectedParameter)
        }
    }

    func testImplicitIdentifierUsesTheBuiltInActionAndRejectsUnrelatedActions() throws {
        try withSyntheticMenu { main, chinese in
            let submenu = self.addSubmenu(to: main, title: "Synthetic shell", identifier: "synthetic.shell")
            let english = "Restore Archive…"
            let displayed = Bundle.main.localizedString(forKey: "UXA-3l-Mrb.title",
                                                         value: english, table: "MainMenu")
            if chinese { XCTAssertNotEqual(displayed, english) }
            let item = self.addItem(to: submenu, title: displayed, identifier: "temporary")
            item.action = #selector(self.metadataRestoreArchive(_:))
            item.identifier = nil
            // This XIB item has no explicit ID. AppKit supplies its action
            // selector, so the generated metadata must use the same identity.
            XCTAssertEqual(item.identifier?.rawValue, "restoreArchive:")
            XCTAssertTrue(ITAddressBookMgr.shortcutIdentifier(nil, title: english, matchesItem: item))
            let popup = MenuItemPopupView(frame: .zero)
            XCTAssertTrue(popup.restore(parameter: english))
            XCTAssertEqual(popup.selectedTitle, displayed)
            XCTAssertEqual(popup.selectedParameter, english)
            item.title = "Unrelated user menu"
            item.action = #selector(self.syntheticAction(_:))
            XCTAssertFalse(ITAddressBookMgr.shortcutIdentifier(nil, title: english, matchesItem: item))
        }
    }
}
