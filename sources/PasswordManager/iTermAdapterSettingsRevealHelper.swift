import AppKit

@objc(iTermAdapterSettingsRevealHelper)
class iTermAdapterSettingsRevealHelper: NSObject {
    @objc weak var secureField: NSSecureTextField?
    @objc weak var plainField: NSTextField?

    @objc init(secureField: NSSecureTextField, plainField: NSTextField) {
        self.secureField = secureField
        self.plainField = plainField
    }

    @objc func toggleReveal(_ sender: NSButton) {
        guard let secureField, let plainField else { return }
        if plainField.isHidden {
            plainField.stringValue = secureField.stringValue
            secureField.isHidden = true
            plainField.isHidden = false
            plainField.window?.makeFirstResponder(plainField)
            sender.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: String(localized: "ui.swift.passwordmanager.itermadaptersettingsrevealhelper.hide.ac20a57b", defaultValue: "Hide", bundle: .main, comment: "User-facing text in iTermAdapterSettingsRevealHelper."))
        } else {
            secureField.stringValue = plainField.stringValue
            plainField.isHidden = true
            secureField.isHidden = false
            secureField.window?.makeFirstResponder(secureField)
            sender.image = NSImage(systemSymbolName: "eye", accessibilityDescription: String(localized: "ui.swift.passwordmanager.itermadaptersettingsrevealhelper.show.0df6f1ca", defaultValue: "Show", bundle: .main, comment: "User-facing text in iTermAdapterSettingsRevealHelper."))
        }
    }
}
