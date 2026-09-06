//
//  AccountPicker.swift
//  iTerm2
//
//  Created by George Nachman on 11/25/25.
//

import AppKit

class AccountPicker {
    struct Account: Codable {
        var title: String?
        var accountID: String?
    }

    static func askUserToSelect(from accounts: [Account]) -> String {
        DLog("begin")
        let alert = NSAlert()
        alert.messageText = String(localized: "ui.swift.passwordmanager.accountpicker.select_an_account.f46ab3ce", defaultValue: "Select an Account", bundle: .main, comment: "User-facing text in AccountPicker.")
        alert.informativeText = String(localized: "ui.swift.passwordmanager.accountpicker.please_choose_an_account.3902acad", defaultValue: "Please choose an account:", bundle: .main, comment: "User-facing text in AccountPicker.")
        alert.alertStyle = .informational

        var ids = [String]()
        for account in accounts {
            if let email = account.title, let uuid = account.accountID {
                alert.addButton(withTitle: email)
                ids.append(uuid)
            }
        }
        if ids.count == 1 {
            return ids[0]
        }
        it_assert(ids.count > 1)

        // Can't present a sheet modal within a sheet modal so go app modal instead.
        let response = alert.runModal()

        let selectedIndex = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue

        let uuid = ids[selectedIndex]
        return uuid
    }
}
