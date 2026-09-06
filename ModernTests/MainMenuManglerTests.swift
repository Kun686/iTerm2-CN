//
//  MainMenuManglerTests.swift
//  ModernTests
//

import AppKit
import XCTest
@testable import iTerm2SharedARC

final class MainMenuManglerTests: XCTestCase {
    func testApplicationIdentityUsesStableIdentifiersWithoutChangingActions() {
        let mainMenu = NSMenu(title: "Main")
        let applicationItem = NSMenuItem(title: "iTerm2", action: nil, keyEquivalent: "")
        let applicationMenu = NSMenu(title: "iTerm2")
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)

        let about = NSMenuItem(title: "About iTerm2",
                               action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                               keyEquivalent: "")
        about.identifier = NSUserInterfaceItemIdentifier("About iTerm2")
        applicationMenu.addItem(about)

        let helpRoot = NSMenuItem(title: "Help", action: nil, keyEquivalent: "")
        let helpMenu = NSMenu(title: "Help")
        helpRoot.submenu = helpMenu
        mainMenu.addItem(helpRoot)
        let help = NSMenuItem(title: "iTerm2 Help", action: #selector(NSApplication.showHelp(_:)), keyEquivalent: "?")
        help.identifier = NSUserInterfaceItemIdentifier("iTerm2 Help")
        helpMenu.addItem(help)

        let originalAboutAction = about.action
        let originalHelpAction = help.action
        MainMenuMangler().applyApplicationIdentity(
            "iTerm2-CN",
            titleFormatsByIdentifier: [
                "About iTerm2": "About %@",
                "iTerm2 Help": "%@ Help"
            ],
            in: mainMenu)

        XCTAssertEqual(applicationItem.title, "iTerm2-CN")
        XCTAssertEqual(applicationMenu.title, "iTerm2-CN")
        XCTAssertEqual(about.title, "About iTerm2-CN")
        XCTAssertEqual(help.title, "iTerm2-CN Help")
        XCTAssertEqual(about.identifier?.rawValue, "About iTerm2")
        XCTAssertEqual(help.identifier?.rawValue, "iTerm2 Help")
        XCTAssertEqual(about.action, originalAboutAction)
        XCTAssertEqual(help.action, originalHelpAction)
        XCTAssertEqual(help.keyEquivalent, "?")
    }
}
