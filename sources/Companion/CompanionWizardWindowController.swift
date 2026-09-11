//
//  CompanionWizardWindowController.swift
//  iTerm2
//
//  The first-run onboarding wizard for pairing a companion device. It replaces
//  the scavenger hunt of installing two plugins, granting two consents, and
//  finding the phone app with a single guided flow: install (download both
//  plugins, grant both consents in one password prompt), then phone-app install,
//  show the pairing code, confirm the SAS, and finish on a live status screen.
//  Only first-time users see it; CompanionOnboardingRouter sends everyone else to
//  the plain CompanionPairingWindowController. The actual pairing (QR, handshake,
//  SAS, relay status) is all CompanionPairingController, reached through the same
//  callbacks the plain window uses, so this controller is just presentation.
//  Layout uses explicit frames (no auto layout).
//

import AppKit
import CompanionProtocol

@MainActor
@objc(iTermCompanionWizardWindowController)
final class CompanionWizardWindowController: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {
    @objc static let shared = CompanionWizardWindowController()

    /// The wizard's steps. The router picks the starting step from how much setup
    /// is already done; transitions from there are driven by the buttons and the
    /// pairing controller's callbacks.
    enum Screen {
        case fullSetup      // 1.1: install both plugins + grant both consents
        case companionOnly  // 1.2: install the companion plugin + grant its consent
        case phoneApp       // 2: install iTerm2 Buddy on the phone
        case showCode       // 3: authenticate, then show the pairing QR
        case sasEntry       // 4: confirm the 6-digit code the phone shows
        case paired         // 5: paired, with live connection status
    }

    private static let contentWidth: CGFloat = 460
    private static let contentHeight: CGFloat = 560

    private let controller = CompanionPairingController.shared
    private var currentScreen: Screen = .fullSetup
    private var screenView: NSView?

    // Controls whose state outlives a single action, rebuilt with each screen.
    private weak var activeStatusLabel: NSTextField?
    private weak var apiKeyField: NSSecureTextField?
    private weak var providerPopup: NSPopUpButton?
    private weak var apiKeyHelpButton: NSButton?
    private weak var installButton: NSButton?
    private weak var installSpinner: NSProgressIndicator?
    private weak var showCodeButton: NSButton?
    private weak var qrImageView: NSImageView?
    private weak var sasField: NSTextField?
    private weak var sasVerifyButton: NSButton?
    private weak var checkmarkImageView: NSImageView?
    private weak var pairedInstructionsLabel: NSTextField?

    private var relayStatusTimer: Timer?
    // The in-flight install (download + consent + persist). Held so it can be
    // cancelled if the user closes the wizard mid-install.
    private var installTask: Task<Void, Never>?

    @objc init() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0,
                                                width: Self.contentWidth,
                                                height: Self.contentHeight),
                            styleMask: [.titled, .closable],
                            backing: .buffered,
                            defer: false)
        panel.isFloatingPanel = true
        panel.title = String(localized: "ui.swift.companion.companionwizardwindowcontroller.set_up_a_companion_device.ff500029", defaultValue: "Set Up a Companion Device", bundle: .main, comment: "User-facing text in CompanionWizardWindowController.")
        super.init(window: panel)
        panel.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        it_fatalError("CompanionWizardWindowController does not support coder initialization")
    }

    /// Show the wizard starting at the given screen and wire up the pairing
    /// controller's callbacks.
    func show(startingAt screen: Screen) {
        // Never re-drive a wizard that is already open. Re-routing here (e.g. the
        // user clicks the menu again while a QR is shown or a handshake is in
        // progress) would jump the window back to an earlier screen and abandon
        // the live pairing the controller is still running. Just surface it.
        if window?.isVisible == true {
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        installCallbacks()
        showWindow(nil)
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        goTo(screen)
    }

    // MARK: Navigation

    private func goTo(_ screen: Screen) {
        // Always tear down any running relay-status timer first. buildPairedScreen
        // schedules a fresh one, so even a .paired -> .paired transition (a phone
        // reconnect re-firing onPaired) must not orphan the previous timer.
        relayStatusTimer?.invalidate()
        relayStatusTimer = nil
        currentScreen = screen
        // Clear the per-screen control references; the builder repopulates the
        // ones its screen uses.
        activeStatusLabel = nil
        apiKeyField = nil
        providerPopup = nil
        installButton = nil
        installSpinner = nil
        showCodeButton = nil
        qrImageView = nil
        sasField = nil
        sasVerifyButton = nil
        checkmarkImageView = nil
        pairedInstructionsLabel = nil

        screenView?.removeFromSuperview()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: Self.contentWidth, height: Self.contentHeight))
        switch screen {
        case .fullSetup: buildInstallScreen(in: view, full: true)
        case .companionOnly: buildInstallScreen(in: view, full: false)
        case .phoneApp: buildPhoneAppScreen(in: view)
        case .showCode: buildShowCodeScreen(in: view)
        case .sasEntry: buildSASScreen(in: view)
        case .paired: buildPairedScreen(in: view)
        }
        window?.contentView?.addSubview(view)
        screenView = view

        // First responder must be set after the view is in the window hierarchy,
        // not during the builder. Put the cursor in the SAS field so the user can
        // type the code immediately after scanning.
        if screen == .sasEntry, let field = sasField {
            window?.makeFirstResponder(field)
        }
    }

    // MARK: Shared builders

    private func addTitle(_ text: String, to view: NSView) {
        let title = NSTextField(labelWithString: text)
        title.font = .boldSystemFont(ofSize: 20)
        title.alignment = .center
        title.frame = NSRect(x: 20, y: Self.contentHeight - 64, width: Self.contentWidth - 40, height: 28)
        view.addSubview(title)
    }

    private func addBodyLabel(_ text: String, to view: NSView, y: CGFloat, height: CGFloat) {
        let label = NSTextField(wrappingLabelWithString: text)
        label.alignment = .center
        label.isSelectable = false
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: 40, y: y, width: Self.contentWidth - 80, height: height)
        view.addSubview(label)
    }

    private func makeStatusLabel() -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: "")
        label.alignment = .center
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 3
        label.frame = NSRect(x: 30, y: 96, width: Self.contentWidth - 60, height: 48)
        return label
    }

    private func makeButton(_ title: String, action: Selector, isDefault: Bool = false) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        if isDefault {
            button.keyEquivalent = "\r"
        }
        button.sizeToFit()
        return button
    }

    /// A centered, full-width-ish button at a given y.
    private func place(_ button: NSButton, centeredAtY y: CGFloat, minWidth: CGFloat = 0) {
        let width = max(button.frame.width + 30, minWidth)
        button.frame = NSRect(x: (Self.contentWidth - width) / 2, y: y, width: width, height: 32)
    }

    private func setStatus(_ text: String, color: NSColor) {
        activeStatusLabel?.stringValue = text
        activeStatusLabel?.textColor = color
    }

    // MARK: Screen 1.1 / 1.2 - install

    private func buildInstallScreen(in view: NSView, full: Bool) {
        addTitle(full ? String(localized: "ui.swift.companion.companionwizardwindowcontroller.set_up_your_companion_device.528759c0", defaultValue: "Set Up Your Companion Device", bundle: .main, comment: "User-facing text in CompanionWizardWindowController.") : String(localized: "ui.swift.companion.companionwizardwindowcontroller.enable_companion_pairing.db3a3119", defaultValue: "Enable Companion Pairing", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), to: view)

        let explanation = full
            ? String(localized: "ui.swift.companion.companionwizardwindowcontroller.this_installs_the_ai_and_companion_plugins_and.73fe95c3", defaultValue: "This installs the AI and Companion plugins and turns on both features. Afterward, iTerm2 can send data off this Mac, but only with your explicit consent.", bundle: .main, comment: "User-facing text in CompanionWizardWindowController.")
            : String(localized: "ui.swift.companion.companionwizardwindowcontroller.this_installs_the_companion_plugin_and_turns_on.9e929a3c", defaultValue: "This installs the Companion plugin and turns on companion device pairing. Afterward, iTerm2 can send data off this Mac, but only with your explicit consent.", bundle: .main, comment: "User-facing text in CompanionWizardWindowController.")
        addBodyLabel(explanation, to: view, y: Self.contentHeight - 160, height: 80)

        // Learn-more link sits right under the introductory paragraph, above the
        // API key controls.
        let learnMore = makeButton(String(localized: "ui.swift.companion.companionwizardwindowcontroller.learn_about_the_companion_app.d768a348", defaultValue: "Learn About the Companion App", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), action: #selector(openDocs))
        place(learnMore, centeredAtY: Self.contentHeight - 200)
        view.addSubview(learnMore)

        var nextY = Self.contentHeight - 250
        if full {
            let keyLabel = NSTextField(labelWithString: String(localized: "ui.swift.companion.companionwizardwindowcontroller.api_key.2f77effd", defaultValue: "API key:", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."))
            keyLabel.alignment = .right
            keyLabel.frame = NSRect(x: 20, y: nextY - 5, width: 90, height: 22)
            view.addSubview(keyLabel)

            let keyField = NSSecureTextField(frame: NSRect(x: 118, y: nextY - 2, width: Self.contentWidth - 138, height: 24))
            keyField.placeholderString = String(localized: "ui.swift.companion.companionwizardwindowcontroller.paste_your_api_key.e35b296b", defaultValue: "Paste your API key", bundle: .main, comment: "User-facing text in CompanionWizardWindowController.")
            // Pre-fill an existing key so a user who already configured AI doesn't
            // have to find it again; Install stays gated on the field being non-empty.
            keyField.stringValue = AITermControllerObjC.apiKey ?? ""
            keyField.delegate = self
            view.addSubview(keyField)
            apiKeyField = keyField

            nextY -= 38
            let providerLabel = NSTextField(labelWithString: String(localized: "ui.swift.companion.companionwizardwindowcontroller.provider.672f1efd", defaultValue: "Provider:", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."))
            providerLabel.alignment = .right
            providerLabel.frame = NSRect(x: 20, y: nextY - 5, width: 90, height: 22)
            view.addSubview(providerLabel)

            let popup = NSPopUpButton(frame: NSRect(x: 114, y: nextY - 3, width: 200, height: 26))
            // Each item's tag is the iTermAIVendor raw value. Apple Intelligence is
            // intentionally absent: it runs on-device and uses no API key, so it has
            // no place on a "paste your API key" screen.
            let vendors: [(String, Int)] = [
                ("Anthropic", Int(iTermAIVendor.anthropic.rawValue)),
                ("OpenAI", Int(iTermAIVendor.openAI.rawValue)),
                ("Gemini", Int(iTermAIVendor.gemini.rawValue)),
                ("DeepSeek", Int(iTermAIVendor.deepSeek.rawValue)),
                ("Llama", Int(iTermAIVendor.llama.rawValue))]
            for (title, tag) in vendors {
                popup.addItem(withTitle: title)
                popup.lastItem?.tag = tag
            }
            // Preserve the user's existing provider choice: the prefilled key
            // belongs to that vendor, so defaulting to Anthropic would silently
            // re-pair the key with the wrong provider (and overwrite the saved
            // vendor on Install). Fall back to Anthropic only when there is no
            // saved (or no listed) vendor.
            let savedVendor = Int(iTermPreferences.int(forKey: kPreferenceKeyAIVendor))
            if !popup.selectItem(withTag: savedVendor) {
                popup.selectItem(withTag: Int(iTermAIVendor.anthropic.rawValue))
            }
            popup.target = self
            popup.action = #selector(providerChanged)
            view.addSubview(popup)
            providerPopup = popup

            nextY -= 36
            let getKey = makeButton(String(localized: "ui.swift.companion.companionwizardwindowcontroller.get_an_api_key.42bc0c32", defaultValue: "Get an API Key", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), action: #selector(openGetAPIKey))
            getKey.frame = NSRect(x: 114, y: nextY, width: getKey.frame.width + 24, height: 28)
            view.addSubview(getKey)
            apiKeyHelpButton = getKey
            updateAPIKeyHelpButton()
        }

        let status = makeStatusLabel()
        view.addSubview(status)
        activeStatusLabel = status

        let spinner = NSProgressIndicator(frame: NSRect(x: (Self.contentWidth - 24) / 2, y: 150, width: 24, height: 24))
        spinner.style = .spinning
        spinner.isDisplayedWhenStopped = false
        view.addSubview(spinner)
        installSpinner = spinner

        let install = makeButton(String(localized: "ui.swift.companion.companionwizardwindowcontroller.install.569ca49f", defaultValue: "Install", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), action: #selector(installPressed), isDefault: true)
        place(install, centeredAtY: 40, minWidth: 160)
        view.addSubview(install)
        installButton = install
        // Screen 1.1 requires an API key; 1.2 has no key field and stays enabled.
        updateInstallEnabled()
    }

    /// The iTermAIVendor raw value currently selected in the provider popup,
    /// falling back to Anthropic (the default provider) when there is no popup.
    private var selectedVendorTag: Int {
        return providerPopup?.selectedTag() ?? Int(iTermAIVendor.anthropic.rawValue)
    }

    private func updateInstallEnabled() {
        guard currentScreen == .fullSetup else { return }
        let hasKey = !(apiKeyField?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        installButton?.isEnabled = hasKey
    }

    private func setInstalling(_ installing: Bool) {
        installButton?.isEnabled = !installing
        apiKeyField?.isEnabled = !installing
        providerPopup?.isEnabled = !installing
        if installing {
            installSpinner?.startAnimation(nil)
        } else {
            installSpinner?.stopAnimation(nil)
        }
    }

    @objc private func installPressed(_ sender: Any) {
        let full = (currentScreen == .fullSetup)
        let apiKey = (apiKeyField?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if full && apiKey.isEmpty {
            setStatus(String(localized: "ui.swift.companion.companionwizardwindowcontroller.enter_your_api_key_to_continue.7b38a6c2", defaultValue: "Enter your API key to continue.", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), color: .systemRed)
            return
        }
        let vendor = Int32(selectedVendorTag)
        // Capture the prior AI defaults and consents so a failed or abandoned
        // setup can restore them: we must not silently change the user's saved
        // key/vendor, nor leave consent on (possibly with no usable key), when
        // install never completes.
        let priorAPIKey = full ? AITermControllerObjC.apiKey : nil
        let priorVendor = full ? iTermPreferences.int(forKey: kPreferenceKeyAIVendor) : 0
        let priorEnableAI = SecureUserDefaults.instance.enableAI.value
        let priorEnableCompanion = SecureUserDefaults.instance.enableCompanionPairing.value
        setInstalling(true)
        installTask = Task { [weak self] in
            guard let self else { return }
            // Bail out with no side effects if the window was dismissed (and this
            // Task cancelled by windowWillClose) during the multi-second install:
            // do not navigate, raise the admin prompt, or write defaults on a gone
            // window.
            let active: () -> Bool = { [weak self] in
                guard let self, !Task.isCancelled else { return false }
                return self.window?.isVisible == true
                    && (self.currentScreen == .fullSetup || self.currentScreen == .companionOnly)
            }
            var wroteAIDefaults = false
            var grantedConsent = false
            do {
                if full {
                    self.setStatus(String(localized: "ui.swift.companion.companionwizardwindowcontroller.downloading_the_ai_plugin.5e359c5f", defaultValue: "Downloading the AI plugin…", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), color: .secondaryLabelColor)
                    try await CompanionPluginInstaller.installAIPlugin()
                }
                self.setStatus(String(localized: "ui.swift.companion.companionwizardwindowcontroller.downloading_the_companion_plugin.cba7bee2", defaultValue: "Downloading the companion plugin…", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), color: .secondaryLabelColor)
                try await CompanionPluginInstaller.installCompanionPlugin()
                // The next step raises an admin password prompt and writes
                // defaults, so stop here if the user already closed the wizard.
                guard active() else { return }
                self.setStatus(String(localized: "ui.swift.companion.companionwizardwindowcontroller.granting_consent.7306b781", defaultValue: "Granting consent…", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), color: .secondaryLabelColor)
                try SecureUserDefaults.grantConsent(ai: full, companion: true)
                grantedConsent = true
                if full {
                    // Persist the key/vendor only now that the plugins installed
                    // and consent was granted, so an earlier failure leaves the
                    // saved defaults untouched.
                    AITermControllerObjC.apiKey = apiKey
                    iTermPreferences.setInt(vendor, forKey: kPreferenceKeyAIVendor)
                    wroteAIDefaults = true
                }
                self.setStatus(String(localized: "ui.swift.companion.companionwizardwindowcontroller.verifying.63bbd08c", defaultValue: "Verifying…", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), color: .secondaryLabelColor)
                guard self.verifyReady(full: full) else {
                    throw CompanionPluginInstallerError.verificationFailed(
                        full ? String(localized: "ui.swift.companion.companionwizardwindowcontroller.ai_and_companion_plugins.39299df0", defaultValue: "AI and companion plugins", bundle: .main, comment: "User-facing text in CompanionWizardWindowController.") : String(localized: "ui.swift.companion.companionwizardwindowcontroller.companion_plugin.56041357", defaultValue: "companion plugin", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."))
                }
                guard active() else { return }
                self.goTo(.phoneApp)
            } catch {
                // Roll back everything this attempt changed so a failed setup does
                // not leave consent on, a switched vendor, or a replaced key.
                // Reverting a secure default to its prior value needs no
                // authorization (it is fail-safe), so this is a silent cleanup.
                if grantedConsent {
                    if full, !priorEnableAI { try? SecureUserDefaults.instance.enableAI.reset() }
                    if !priorEnableCompanion { try? SecureUserDefaults.instance.enableCompanionPairing.reset() }
                }
                if wroteAIDefaults {
                    AITermControllerObjC.apiKey = priorAPIKey
                    iTermPreferences.setInt(priorVendor, forKey: kPreferenceKeyAIVendor)
                }
                guard active() else { return }
                self.setInstalling(false)
                self.failAndFallBackToPlainWindow(error)
            }
        }
    }

    private func verifyReady(full: Bool) -> Bool {
        return CompanionSetupState.companionConfigured
            && (!full || CompanionSetupState.aiConfigured)
    }

    /// On any setup failure, explain it and hand the user to the plain settings
    /// window so they can finish manually (the status quo before the wizard).
    private func failAndFallBackToPlainWindow(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "ui.swift.companion.companionwizardwindowcontroller.setup_could_not_be_completed.97b72697", defaultValue: "Setup Could Not Be Completed", bundle: .main, comment: "User-facing text in CompanionWizardWindowController.")
        alert.informativeText = error.localizedDescription
            + String(localized: "ui.swift.companion.companionwizardwindowcontroller.you_can_finish_setting_up_in_companion_device.f6e740a9", defaultValue: "\n\nYou can finish setting up in Companion Device Settings.", bundle: .main, comment: "User-facing text in CompanionWizardWindowController.")
        alert.addButton(withTitle: String(localized: "ui.swift.companion.companionwizardwindowcontroller.ok.565339bc", defaultValue: "OK", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."))
        let finish = { [weak self] in
            self?.close()
            CompanionPairingWindowController.shared.showAndBeginPairing()
        }
        if let window {
            alert.beginSheetModal(for: window) { _ in finish() }
        } else {
            alert.runModal()
            finish()
        }
    }

    // MARK: Screen 2 - phone app

    // Flip to true in the launch build once iTerm2 Buddy is live on the App
    // Store. When true, the setup wizard links straight to the App Store and
    // never mentions the TestFlight beta, whatever this iTerm2 build's release
    // channel is. Leave false until the iOS app is released.
    private static let companionIOSAppIsOnAppStore = false

    // A redirect on iterm2.com that we control, so the shipped app never hardcodes
    // the raw App Store URL. Point it at the App Store page
    // (https://apps.apple.com/app/id<APPLE_ID>, the app's Apple ID from App Store
    // Connect) at launch. Until that redirect is set up, this link will not resolve.
    private static let companionAppStoreURL = "https://iterm2.com/companion-app-store"

    private func buildPhoneAppScreen(in view: NSView) {
        addTitle(String(localized: "ui.swift.companion.companionwizardwindowcontroller.install_iterm2_buddy_on_your_iphone.2167b98c", defaultValue: "Install iTerm2 Buddy on Your iPhone", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), to: view)
        addBodyLabel(String(localized: "ui.swift.companion.companionwizardwindowcontroller.pairing_connects_this_mac_to_the_iterm2_buddy.71da1d27", defaultValue: "Pairing connects this Mac to the iTerm2 Buddy app on your iPhone. Install it now, then come back and continue.", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."),
                     to: view, y: Self.contentHeight - 170, height: 80)

        if !Self.companionIOSAppIsOnAppStore && (Bundle.it_isEarlyAdopter() || Bundle.it_isNightlyBuild()) {
            addBodyLabel(String(localized: "ui.swift.companion.companionwizardwindowcontroller.this_is_a_beta_build_so_iterm2_buddy.bbc4b4b5", defaultValue: "This is a beta build, so iTerm2 Buddy is distributed through TestFlight. Install TestFlight, then join the beta.", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."),
                         to: view, y: Self.contentHeight - 260, height: 60)
            let testFlight = makeButton(String(localized: "ui.swift.companion.companionwizardwindowcontroller.install_testflight.c7c23016", defaultValue: "Install TestFlight", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), action: #selector(openTestFlightApp))
            place(testFlight, centeredAtY: Self.contentHeight - 300, minWidth: 220)
            view.addSubview(testFlight)

            let join = makeButton(String(localized: "ui.swift.companion.companionwizardwindowcontroller.join_the_iterm2_buddy_beta.fe4f8b63", defaultValue: "Join the iTerm2 Buddy Beta", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), action: #selector(openJoinBeta))
            place(join, centeredAtY: Self.contentHeight - 342, minWidth: 220)
            view.addSubview(join)
        } else {
            let appStore = makeButton(String(localized: "ui.swift.companion.companionwizardwindowcontroller.get_iterm2_buddy.7b7b4c6b", defaultValue: "Get iTerm2 Buddy", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), action: #selector(openReleaseApp))
            place(appStore, centeredAtY: Self.contentHeight - 280, minWidth: 220)
            view.addSubview(appStore)
        }

        let next = makeButton(String(localized: "ui.swift.companion.companionwizardwindowcontroller.next.1ff57a29", defaultValue: "Next", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), action: #selector(phoneAppNextPressed), isDefault: true)
        place(next, centeredAtY: 40, minWidth: 160)
        view.addSubview(next)
    }

    @objc private func phoneAppNextPressed(_ sender: Any) {
        goTo(.showCode)
    }

    // MARK: Screen 3 - show code

    private func buildShowCodeScreen(in view: NSView) {
        addTitle(String(localized: "ui.swift.companion.companionwizardwindowcontroller.show_the_pairing_code.caf5dde7", defaultValue: "Show the Pairing Code", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), to: view)
        addBodyLabel(String(localized: "ui.swift.companion.companionwizardwindowcontroller.on_your_iphone_open_iterm2_buddy_and_tap.a952c0e5", defaultValue: "On your iPhone, open iTerm2 Buddy and tap Scan. Then reveal the pairing code below and point the camera at it.", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."),
                     to: view, y: Self.contentHeight - 170, height: 80)

        let qr = NSImageView(frame: NSRect(x: (Self.contentWidth - 240) / 2, y: 190, width: 240, height: 240))
        qr.imageScaling = .scaleProportionallyUpOrDown
        qr.wantsLayer = true
        qr.layer?.backgroundColor = NSColor.white.cgColor
        qr.isHidden = true
        view.addSubview(qr)
        qrImageView = qr

        let showButton = NSButton(title: String(localized: "ui.swift.companion.companionwizardwindowcontroller.show_pairing_code.b183e71c", defaultValue: "Show Pairing Code", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), target: self, action: #selector(showPairingCodePressed))
        showButton.bezelStyle = .rounded
        showButton.controlSize = .large
        showButton.sizeToFit()
        let width = showButton.frame.width + 48
        showButton.frame = NSRect(x: (Self.contentWidth - width) / 2, y: 290, width: width, height: showButton.frame.height)
        view.addSubview(showButton)
        showCodeButton = showButton

        let status = makeStatusLabel()
        view.addSubview(status)
        activeStatusLabel = status

        let back = makeButton(String(localized: "ui.swift.companion.companionwizardwindowcontroller.back.76900f1b", defaultValue: "Back", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), action: #selector(backToPhoneAppPressed))
        back.frame = NSRect(x: 20, y: 40, width: 90, height: 32)
        view.addSubview(back)
    }

    @objc private func backToPhoneAppPressed(_ sender: Any) {
        controller.stopAdvertising()
        goTo(.phoneApp)
    }

    @objc private func showPairingCodePressed(_ sender: Any) {
        showCodeButton?.isEnabled = false
        setStatus(String(localized: "ui.swift.companion.companionwizardwindowcontroller.authenticating.a705b075", defaultValue: "Authenticating…", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), color: .secondaryLabelColor)
        Task { [weak self] in
            guard let self else { return }
            let authenticated = await self.controller.authenticateToPair()
            guard self.window?.isVisible == true, self.currentScreen == .showCode else { return }
            if !authenticated {
                self.showCodeButton?.isEnabled = true
                self.setStatus(String(localized: "ui.swift.companion.companionwizardwindowcontroller.authentication_is_required_to_show_the_pairing_code.f32cfa64", defaultValue: "Authentication is required to show the pairing code.", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), color: .systemRed)
                return
            }
            do {
                let code = try self.controller.startPairing()
                self.showCodeButton?.isHidden = true
                self.qrImageView?.isHidden = false
                self.qrImageView?.image = CompanionPairingController.qrImage(for: code.urlString(), pointSize: 240)
                self.setStatus(String(localized: "ui.swift.companion.companionwizardwindowcontroller.waiting_for_your_iphone.cc26edb8", defaultValue: "Waiting for your iPhone…", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), color: .secondaryLabelColor)
            } catch {
                self.showCodeButton?.isEnabled = true
                self.setStatus(String(localized: "ui.swift.companion.companionwizardwindowcontroller.could_not_start_pairing_0.c77bcd5a", defaultValue: "Could not start pairing: \(error.localizedDescription)", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), color: .systemRed)
            }
        }
    }

    // MARK: Screen 4 - SAS entry

    private func buildSASScreen(in view: NSView) {
        addTitle(String(localized: "ui.swift.companion.companionwizardwindowcontroller.confirm_the_code.d869860e", defaultValue: "Confirm the Code", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), to: view)
        addBodyLabel(String(localized: "ui.swift.companion.companionwizardwindowcontroller.type_the_6_digit_code_shown_on_your.4d3d2563", defaultValue: "Type the 6-digit code shown on your iPhone. This confirms you’re pairing with your own phone.", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."),
                     to: view, y: Self.contentHeight - 170, height: 70)

        let field = NSTextField(string: "")
        field.alignment = .center
        field.font = .monospacedDigitSystemFont(ofSize: 30, weight: .medium)
        field.placeholderString = "000000"
        field.frame = NSRect(x: (Self.contentWidth - 170) / 2, y: 300, width: 170, height: 48)
        field.target = self
        field.action = #selector(sasVerifyPressed)
        field.delegate = self
        view.addSubview(field)
        sasField = field

        let verify = makeButton(String(localized: "ui.swift.companion.companionwizardwindowcontroller.verify.eea2745e", defaultValue: "Verify", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), action: #selector(sasVerifyPressed), isDefault: true)
        place(verify, centeredAtY: 250, minWidth: 120)
        verify.isEnabled = false
        view.addSubview(verify)
        sasVerifyButton = verify

        let status = makeStatusLabel()
        view.addSubview(status)
        activeStatusLabel = status

        let back = makeButton(String(localized: "ui.swift.companion.companionwizardwindowcontroller.back.76900f1b", defaultValue: "Back", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), action: #selector(backFromSASPressed))
        back.frame = NSRect(x: 20, y: 40, width: 90, height: 32)
        view.addSubview(back)
    }

    @objc private func backFromSASPressed(_ sender: Any) {
        // Abort the in-progress attempt and return to the code screen so the user
        // can reveal a fresh code and rescan.
        controller.stopAdvertising()
        goTo(.showCode)
    }

    @objc private func sasVerifyPressed(_ sender: Any) {
        guard let field = sasField,
              CompanionPairingController.isCompleteSAS(field.stringValue) else { return }
        controller.submitSASEntry(field.stringValue)
        field.stringValue = ""
        sasVerifyButton?.isEnabled = false
    }

    func controlTextDidChange(_ obj: Notification) {
        switch currentScreen {
        case .fullSetup:
            updateInstallEnabled()
        case .sasEntry:
            sasVerifyButton?.isEnabled = CompanionPairingController.isCompleteSAS(sasField?.stringValue ?? "")
        default:
            break
        }
    }

    // MARK: Screen 5 - paired

    private func buildPairedScreen(in view: NSView) {
        addTitle(String(localized: "ui.swift.companion.companionwizardwindowcontroller.companion_device_paired.f043ebf2", defaultValue: "Companion Device Paired", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), to: view)

        let check = NSImageView(frame: NSRect(x: (Self.contentWidth - 130) / 2, y: 320, width: 130, height: 130))
        check.imageScaling = .scaleProportionallyUpOrDown
        let config = NSImage.SymbolConfiguration(pointSize: 96, weight: .regular)
        let image = NSImage(systemSymbolName: SFSymbol.checkmarkCircleFill.rawValue,
                            accessibilityDescription: String(localized: "ui.swift.companion.companionwizardwindowcontroller.companion_device_connection_status.1355ac74", defaultValue: "Companion device connection status", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."))?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        check.image = image
        view.addSubview(check)
        checkmarkImageView = check

        let instructions = NSTextField(wrappingLabelWithString: "")
        instructions.alignment = .center
        instructions.font = .systemFont(ofSize: 13)
        instructions.textColor = .secondaryLabelColor
        instructions.maximumNumberOfLines = 3
        instructions.frame = NSRect(x: 40, y: 230, width: Self.contentWidth - 80, height: 70)
        view.addSubview(instructions)
        pairedInstructionsLabel = instructions

        let status = makeStatusLabel()
        view.addSubview(status)
        activeStatusLabel = status

        let close = makeButton(String(localized: "ui.swift.companion.companionwizardwindowcontroller.close.7d9eb7ac", defaultValue: "Close", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), action: #selector(closePressed), isDefault: true)
        place(close, centeredAtY: 40, minWidth: 160)
        view.addSubview(close)

        updatePairedConnectionText()
        relayStatusTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updatePairedConnectionText()
            }
        }
    }

    private func updatePairedConnectionText() {
        guard currentScreen == .paired else { return }
        if controller.isConnected {
            pairedInstructionsLabel?.stringValue = String(localized: "ui.swift.companion.companionwizardwindowcontroller.your_companion_device_is_paired_and_connected.6da9c995", defaultValue: "Your companion device is paired and connected.", bundle: .main, comment: "User-facing text in CompanionWizardWindowController.")
            checkmarkImageView?.contentTintColor = .systemGreen
            setStatus("", color: .secondaryLabelColor)
        } else if controller.isListening {
            pairedInstructionsLabel?.stringValue = String(localized: "ui.swift.companion.companionwizardwindowcontroller.your_companion_device_is_paired_waiting_for_it.73cd1f9f", defaultValue: "Your companion device is paired. Waiting for it to connect.", bundle: .main, comment: "User-facing text in CompanionWizardWindowController.")
            checkmarkImageView?.contentTintColor = .tertiaryLabelColor
            setStatus("", color: .secondaryLabelColor)
        } else {
            pairedInstructionsLabel?.stringValue = String(localized: "ui.swift.companion.companionwizardwindowcontroller.your_companion_device_is_paired_but_iterm2_isn.3a3fed47", defaultValue: "Your companion device is paired but iTerm2 isn’t listening for it yet. Reconnecting…", bundle: .main, comment: "User-facing text in CompanionWizardWindowController.")
            checkmarkImageView?.contentTintColor = .systemYellow
            setStatus("", color: .systemYellow)
        }
    }

    @objc private func closePressed(_ sender: Any) {
        close()
    }

    // MARK: Link actions

    private func open(_ string: String) {
        if let url = URL(string: string) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openGetAPIKey(_ sender: Any) {
        if let urlString = apiKeyURL(forVendor: selectedVendorTag) {
            open(urlString)
        }
    }

    @objc private func providerChanged(_ sender: Any) {
        updateAPIKeyHelpButton()
    }

    /// The page where the selected provider issues API keys, or nil for a
    /// provider that has none (Llama), in which case the help button is disabled.
    private func apiKeyURL(forVendor tag: Int) -> String? {
        switch tag {
        case Int(iTermAIVendor.anthropic.rawValue): return "https://platform.claude.com/"
        case Int(iTermAIVendor.openAI.rawValue): return "https://platform.openai.com/api-keys"
        case Int(iTermAIVendor.gemini.rawValue): return "https://aistudio.google.com/app/api-keys"
        case Int(iTermAIVendor.deepSeek.rawValue): return "https://platform.deepseek.com/api_keys"
        default: return nil
        }
    }

    private func updateAPIKeyHelpButton() {
        apiKeyHelpButton?.isEnabled = apiKeyURL(forVendor: selectedVendorTag) != nil
    }

    @objc private func openDocs(_ sender: Any) { open("https://iterm2.com/companion-app.html") }
    @objc private func openTestFlightApp(_ sender: Any) { open("https://apps.apple.com/app/testflight/id899247664") }
    @objc private func openJoinBeta(_ sender: Any) { open("https://testflight.apple.com/join/hMsVghmx") }
    @objc private func openReleaseApp(_ sender: Any) { open(Self.companionAppStoreURL) }

    // MARK: Pairing controller callbacks

    private func installCallbacks() {
        // Every callback is gated on the wizard being visible. The controller has
        // a single shared callback slot, so once the wizard is hidden these must
        // be inert: a later reconnect must not fire onPaired -> goTo(.paired) on a
        // closed window (rebuilding subviews and scheduling a fresh timer), and if
        // the plain window is also open it may own the slot, so the wizard must
        // not act on its behalf either.
        controller.onStatus = { [weak self] status in
            // Status from the controller is relevant on the pairing screens; the
            // paired screen manages its own connection text.
            guard let self, self.isShowing,
                  self.currentScreen == .showCode || self.currentScreen == .sasEntry else { return }
            self.setStatus(status, color: .secondaryLabelColor)
        }
        controller.onFailed = { [weak self] message in
            guard let self, self.isShowing,
                  self.currentScreen == .showCode || self.currentScreen == .sasEntry else { return }
            self.setStatus(String(localized: "ui.swift.companion.companionwizardwindowcontroller.pairing_failed_0.ac70a54c", defaultValue: "Pairing failed: \(message)", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."), color: .systemRed)
        }
        controller.onPaired = { [weak self] in
            guard let self, self.isShowing else { return }
            self.goTo(.paired)
        }
        controller.onDisconnect = { [weak self] in
            guard let self, self.isShowing else { return }
            self.updatePairedConnectionText()
        }
        controller.onSASEntryNeeded = { [weak self] in
            // A phone scanned the code and the handshake reached confirmation.
            guard let self, self.isShowing else { return }
            self.goTo(.sasEntry)
        }
        controller.onSASEntryDismissed = { [weak self] accepted in
            guard let self, self.isShowing else { return }
            // Acceptance is handled by onPaired (which moves to the paired
            // screen). A non-acceptance means the code was mistyped past the
            // limit or pairing was declined: tell the user to go back and rescan.
            if !accepted, self.currentScreen == .sasEntry {
                self.setStatus(String(localized: "ui.swift.companion.companionwizardwindowcontroller.that_didn_t_work_tap_back_to_reveal.c9af5f2c", defaultValue: "That didn’t work. Tap Back to reveal a new code and scan again.", bundle: .main, comment: "User-facing text in CompanionWizardWindowController."),
                               color: .systemRed)
            }
        }
        controller.onPairingCodeChanged = { [weak self] code in
            guard let self, self.isShowing, self.currentScreen == .showCode else { return }
            self.qrImageView?.image = CompanionPairingController.qrImage(for: code.urlString(), pointSize: 240)
        }
    }

    private var isShowing: Bool {
        return window?.isVisible == true
    }

    // MARK: Window lifecycle

    func windowWillClose(_ notification: Notification) {
        relayStatusTimer?.invalidate()
        relayStatusTimer = nil
        // Cancel an install in flight so it cannot raise an admin prompt or write
        // defaults after the window is gone. The controller callbacks are NOT
        // cleared here: they are guarded on isShowing, so a hidden wizard is
        // already inert, and clearing the single shared slot could wipe the plain
        // window's callbacks when it is open at the same time.
        installTask?.cancel()
        installTask = nil
        if controller.hasPairedDevice {
            // A pairing happened: leave the background listener running so the
            // phone stays connected and can reconnect. (Same single-relay-slot
            // reasoning as the plain window: a stop/restart would displace the
            // live connection.)
            return
        }
        // Closed without pairing: stop advertising the QR.
        controller.stopAdvertising()
    }
}
