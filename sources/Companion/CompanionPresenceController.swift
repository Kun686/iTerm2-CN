//
//  CompanionPresenceController.swift
//  iTerm2
//
//  Surfaces companion-device presence: a menu bar status item that appears only
//  while a device is paired (and reflects whether it is connected right now),
//  plus a centered toast when the device connects or disconnects. Both are
//  driven by CompanionPairingController.presenceDidChange. macOS user
//  notifications are deliberately avoided (unreliable delivery).
//

import AppKit

@MainActor
@objc(iTermCompanionPresenceController)
final class CompanionPresenceController: NSObject {
    @objc static let shared = CompanionPresenceController()

    private var statusItem: NSStatusItem?
    private var observer: (any NSObjectProtocol)?
    private var settingsObserver: (any NSObjectProtocol)?
    /// Whether a "connected" toast is currently showing for the live connection,
    /// so the matching "disconnected" toast fires only if connect did. A
    /// solicited NSE fetch never sets this, so it produces neither toast.
    private var connectToastShown = false
    private var controller: CompanionPairingController { .shared }

    /// Begin observing presence changes and create the status item if a device
    /// is already paired. Call once, at app launch.
    @objc func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: CompanionPairingController.presenceDidChange,
            object: nil,
            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh(animated: true)
            }
        }
        // The admin/feature-flag gate can hide the whole feature; track it so the
        // status item appears and disappears with it (no toast for a flag flip).
        settingsObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name(iTermAdvancedSettingsDidChange),
            object: nil,
            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh(animated: false)
            }
        }
        connectToastShown = interactivelyPresent(paired: paired)
        // animated: false so launching with a device already connected does not
        // pop a toast for a connection that did not just happen.
        refresh(animated: false)
    }

    /// Whether there is a pairing to show presence for. Companion pairing being
    /// disabled means no presence even if a stale pairing from before it was
    /// disabled still exists. Single definition of the gating expression so the
    /// call sites can't drift.
    private var paired: Bool {
        controller.hasPairedDevice && iTermAdvancedSettingsModel.companionPairingAllowed()
    }

    /// True only for a real/unexpected connection (an interactive app session or
    /// an unclassified one past its grace window) - NOT a solicited NSE fetch or
    /// one still being classified. This is what the toast and the lit status-item
    /// glyph reflect, so a background push fetch neither toasts nor flickers the
    /// menu bar. Takes `paired` so a caller that already computed it doesn't
    /// re-evaluate the gating expression.
    private func interactivelyPresent(paired: Bool) -> Bool {
        paired && controller.connectionPresence == .interactive
    }

    private func refresh(animated: Bool) {
        let paired = self.paired
        let present = interactivelyPresent(paired: paired)

        if paired {
            updateStatusItem(connected: present)
        } else {
            removeStatusItem()
        }

        if animated {
            if present, !connectToastShown {
                CompanionToast.show(message: String(localized: "ui.swift.companion.companionpresencecontroller.iterm2_buddy_connected.22edfa6f", defaultValue: "iTerm2 Buddy connected", bundle: .main, comment: "User-facing text in CompanionPresenceController."),
                                    symbolName: SFSymbol.laptopcomputerAndIphone.rawValue,
                                    tint: .systemGreen)
            } else if !present, connectToastShown, paired {
                CompanionToast.show(message: String(localized: "ui.swift.companion.companionpresencecontroller.iterm2_buddy_disconnected.c12a5a3c", defaultValue: "iTerm2 Buddy disconnected", bundle: .main, comment: "User-facing text in CompanionPresenceController."),
                                    symbolName: SFSymbol.laptopcomputerAndIphone.rawValue,
                                    tint: .secondaryLabelColor)
            }
        }
        connectToastShown = present
    }

    private func updateStatusItem(connected: Bool) {
        let item = statusItem ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        if let button = item.button {
            let image = NSImage(systemSymbolName: SFSymbol.laptopcomputerAndIphone.rawValue,
                                accessibilityDescription: "iTerm2 Buddy")
            image?.isTemplate = true
            button.image = image
            // Dim the glyph when paired but not currently connected.
            button.alphaValue = connected ? 1.0 : 0.5
            button.toolTip = connected
                ? String(localized: "ui.swift.companion.companionpresencecontroller.companion_device_connected.78923efb", defaultValue: "Companion device connected", bundle: .main, comment: "User-facing text in CompanionPresenceController.")
                : String(localized: "ui.swift.companion.companionpresencecontroller.companion_device_paired_not_connected.7c44d0ec", defaultValue: "Companion device paired (not connected)", bundle: .main, comment: "User-facing text in CompanionPresenceController.")
        }
        item.menu = makeMenu(connected: connected)
    }

    private func removeStatusItem() {
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    private func makeMenu(connected: Bool) -> NSMenu {
        let menu = NSMenu()
        let header = NSMenuItem(title: connected
                                ? String(localized: "ui.swift.companion.companionpresencecontroller.companion_device_connected.78923efb", defaultValue: "Companion device connected", bundle: .main, comment: "User-facing text in CompanionPresenceController.")
                                : String(localized: "ui.swift.companion.companionpresencecontroller.companion_device_paired_not_connected.7c44d0ec", defaultValue: "Companion device paired (not connected)", bundle: .main, comment: "User-facing text in CompanionPresenceController."),
                                action: nil,
                                keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: String(localized: "ui.swift.companion.companionpresencecontroller.companion_device_settings.431cb081", defaultValue: "Companion Device Settings…", bundle: .main, comment: "User-facing text in CompanionPresenceController."),
                                  action: #selector(openSettings),
                                  keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        return menu
    }

    @objc private func openSettings() {
        CompanionOnboardingRouter.openSettingsOrWizard()
    }
}
