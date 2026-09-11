//
//  AppSignatureValidator.swift
//  iTerm2
//
//  Created by George Nachman on 9/22/25.
//

import Foundation
import Security

@objc(iTermAppSignatureValidator)
class AppSignatureValidator: NSObject {
    /// Returns the Team Identifier of the current app if the code signature is valid.
    /// - Returns: The team ID string, or `nil` if the signature is invalid or missing.
    @objc
    static func currentAppTeamID() -> String? {
        let selfURL = Bundle.main.bundleURL as CFURL
        var staticCode: SecStaticCode?

        let status = SecStaticCodeCreateWithPath(selfURL, [], &staticCode)
        if status != errSecSuccess {
            return nil
        }

        guard let code = staticCode else {
            return nil
        }

        let flags: SecCSFlags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode)
        let verifyStatus = SecStaticCodeCheckValidity(code, flags, nil)
        if verifyStatus != errSecSuccess {
            return nil
        }

        var info: CFDictionary?
        let infoStatus = SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation|kSecCSRequirementInformation|kSecCSDynamicInformation), &info)
        if infoStatus != errSecSuccess {
            return nil
        }
        print(info as! [String:Any])
        guard let dict = info as? [String: Any],
        let teamID = dict[kSecCodeInfoTeamIdentifier as String] as? String else {
            return nil
        }

        return teamID
    }

    @objc
    static func warn(reason: String) {
        let team = currentAppTeamID()
        let message = if team == nil {
            String(localized: "ui.swift.hacks.appsignaturevalidator.a_required_file_appears_to_be_missing_or.f5640313", defaultValue: "A required file appears to be missing or corrupted and iTerm2’s code signature could not be verified.\n\nYou should download a fresh copy of the app and reinstall it.", bundle: .main, comment: "User-facing text in AppSignatureValidator.")
        } else if team == "H7V7XYVQ7D" {
            String(localized: "ui.swift.hacks.appsignaturevalidator.a_required_file_appears_to_be_missing_or.905e94a4", defaultValue: "A required file appears to be missing or corrupted and iTerm2’s code signature did not match that of the official distribution.\n\nYou should download a fresh copy of the app and reinstall it.", bundle: .main, comment: "User-facing text in AppSignatureValidator.")
        } else {
            String(localized: "ui.swift.hacks.appsignaturevalidator.a_required_file_appears_to_be_missing_or.85976d5f", defaultValue: "A required file appears to be missing or corrupted, yet against all odds the code signature for iTerm2 is valid. Please file a bug at https://iterm2.com/bugs", bundle: .main, comment: "User-facing text in AppSignatureValidator.")
        }
        let alert = NSAlert()
        alert.messageText = String(localized: "ui.swift.hacks.appsignaturevalidator.application_corrupt.c446cbb1", defaultValue: "Application Corrupt", bundle: .main, comment: "User-facing text in AppSignatureValidator.")
        alert.informativeText = reason + ": " + message
        alert.addButton(withTitle: String(localized: "ui.swift.hacks.appsignaturevalidator.ok.565339bc", defaultValue: "OK", bundle: .main, comment: "User-facing text in AppSignatureValidator."))
        alert.alertStyle = .critical
        alert.runModal()
    }
}

