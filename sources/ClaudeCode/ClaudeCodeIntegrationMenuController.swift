//
//  ClaudeCodeIntegrationMenuController.swift
//  iTerm2SharedARC
//

import AppKit

// Owns the iTerm2 menu's Install/Uninstall Claude Code Integration
// items: their actions, mutual visibility, and the multi-step flow
// behind the uninstall confirmation. Lives outside the app delegate
// to keep that monster file from absorbing more responsibility —
// the app delegate just forwards its IBActions and validateMenuItem
// cases through here.
@objc(iTermClaudeCodeIntegrationMenuController)
final class ClaudeCodeIntegrationMenuController: NSObject {
    @objc static let shared = ClaudeCodeIntegrationMenuController()

    private override init() {
        super.init()
    }

    // MARK: - Menu Actions

    @objc func install(_ sender: Any?) {
        ClaudeCodeOnboarding.show()
    }

    // Same code path as install — the onboarding is idempotent and
    // pre-marks completed steps. The reason this is a separate menu
    // item is the menu validation (see validateInstallMenuItem):
    // once the integration has previously been set up, Install is
    // hidden, so without a Reinstall entry the user has no way to
    // add a missing piece (Try-It-Now-only users who never installed
    // the hook, triggers-only users who never entered the workgroup)
    // or to repair a broken install (Claude Code stripped the hook,
    // hand edits, etc.) — Uninstall would be their only option.
    @objc func reinstall(_ sender: Any?) {
        ClaudeCodeOnboarding.show()
    }

    @objc func uninstall(_ sender: Any?) {
        let confirm = NSAlert()
        confirm.messageText = String(localized: "ui.swift.claudecode.claudecodeintegrationmenucontroller.uninstall_claude_code_integration.bb98cf97", defaultValue: "Uninstall Claude Code Integration?", bundle: .main, comment: "User-facing text in ClaudeCodeIntegrationMenuController.")
        confirm.informativeText = String(localized: "ui.swift.claudecode.claudecodeintegrationmenucontroller.this_removes_the_cc_status_hook_from_claude.4226d9b8", defaultValue: "This removes the cc-status hook from ~/.claude/settings.json, the Claude Code workgroup from your settings, and the Enter/Exit Workgroup triggers from every profile. You can reinstall any time using iTerm2 > Install Claude Code Integration.", bundle: .main, comment: "User-facing text in ClaudeCodeIntegrationMenuController.")
        confirm.alertStyle = .warning
        confirm.addButton(withTitle: String(localized: "ui.swift.claudecode.claudecodeintegrationmenucontroller.uninstall.fe199528", defaultValue: "Uninstall", bundle: .main, comment: "User-facing text in ClaudeCodeIntegrationMenuController."))
        confirm.addButton(withTitle: String(localized: "ui.swift.claudecode.claudecodeintegrationmenucontroller.cancel.19766ed6", defaultValue: "Cancel", bundle: .main, comment: "User-facing text in ClaudeCodeIntegrationMenuController."))
        guard confirm.runModal() == .alertFirstButtonReturn else { return }

        // Hooks first — they're the only step that can fail (disk).
        // If the hook removal fails, ask before touching the rest:
        // the user may want to bail out and fix the underlying
        // problem (nothing removed, retryable), or push through and
        // clean up the iTerm-side state anyway (cc-status will keep
        // firing until they fix ~/.claude/settings.json by hand).
        let hookResult = ClaudeCodeOnboarding.uninstallHooks()
        if hookResult != .success {
            let detail: String
            switch hookResult {
            case .unreadable:
                detail = String(localized: "ui.swift.claudecode.claudecodeintegrationmenucontroller.could_not_read_claude_settings_json_check_the.787bff90", defaultValue: "Could not read ~/.claude/settings.json — check the file’s permissions.", bundle: .main, comment: "User-facing text in ClaudeCodeIntegrationMenuController.")
            case .malformed:
                detail = String(localized: "ui.swift.claudecode.claudecodeintegrationmenucontroller.claude_settings_json_couldn_t_be_parsed_as.b6b30bdd", defaultValue: "~/.claude/settings.json couldn’t be parsed as JSON. Open it in a text editor and check it for syntax errors.", bundle: .main, comment: "User-facing text in ClaudeCodeIntegrationMenuController.")
            case .writeFailed:
                detail = String(localized: "ui.swift.claudecode.claudecodeintegrationmenucontroller.could_not_write_to_claude_settings_json_check.8931206d", defaultValue: "Could not write to ~/.claude/settings.json — check the file’s permissions.", bundle: .main, comment: "User-facing text in ClaudeCodeIntegrationMenuController.")
            case .success:
                detail = ""  // unreachable; covered by outer guard
            @unknown default:
                detail = ""
            }
            let failure = NSAlert()
            failure.messageText = String(localized: "ui.swift.claudecode.claudecodeintegrationmenucontroller.couldn_t_remove_hooks.a676ac9d", defaultValue: "Couldn\u{2019}t Remove Hooks", bundle: .main, comment: "User-facing text in ClaudeCodeIntegrationMenuController.")
            failure.informativeText = String(localized: "ui.swift.claudecode.claudecodeintegrationmenucontroller.0_continue_removing_the_workgroup_and_triggers_anyway.a9eccd35", defaultValue: "\(detail) Continue removing the workgroup and triggers anyway? cc-status will keep running until you fix the underlying issue and try again.", bundle: .main, comment: "User-facing text in ClaudeCodeIntegrationMenuController.")
            failure.alertStyle = .warning
            failure.addButton(withTitle: String(localized: "ui.swift.claudecode.claudecodeintegrationmenucontroller.continue.31fbef16", defaultValue: "Continue", bundle: .main, comment: "User-facing text in ClaudeCodeIntegrationMenuController."))
            failure.addButton(withTitle: String(localized: "ui.swift.claudecode.claudecodeintegrationmenucontroller.cancel.19766ed6", defaultValue: "Cancel", bundle: .main, comment: "User-facing text in ClaudeCodeIntegrationMenuController."))
            guard failure.runModal() == .alertFirstButtonReturn else { return }
        }

        ClaudeCodeOnboarding.uninstallWorkgroup()
        ClaudeCodeOnboarding.uninstallTriggers()

        // Clear the "user once completed setup" sticky flag so the
        // broken-install nag doesn't fire after an explicit uninstall.
        // Set again on the next successful install.
        iTermUserDefaults.claudeCodeIntegrationCompleted = false

        // The installer turned the Python API on, but the user might
        // rely on it for unrelated scripts/AI integrations now.
        // Don't flip it off behind their back — ask. Skip the prompt
        // entirely if the API is already off (uninstall has nothing
        // to offer).
        if iTermAPIHelper.isEnabled() {
            let apiAlert = NSAlert()
            apiAlert.messageText = String(localized: "ui.swift.claudecode.claudecodeintegrationmenucontroller.disable_the_python_api.ef671576", defaultValue: "Disable the Python API?", bundle: .main, comment: "User-facing text in ClaudeCodeIntegrationMenuController.")
            apiAlert.informativeText = String(localized: "ui.swift.claudecode.claudecodeintegrationmenucontroller.the_installer_enabled_iterm2_s_python_api_other.1840cf46", defaultValue: "The installer enabled iTerm2’s Python API. Other scripts or integrations may be using it now. Leave it enabled, or turn it off?", bundle: .main, comment: "User-facing text in ClaudeCodeIntegrationMenuController.")
            apiAlert.addButton(withTitle: String(localized: "ui.swift.claudecode.claudecodeintegrationmenucontroller.leave_enabled.2350465f", defaultValue: "Leave Enabled", bundle: .main, comment: "User-facing text in ClaudeCodeIntegrationMenuController."))
            apiAlert.addButton(withTitle: String(localized: "ui.swift.claudecode.claudecodeintegrationmenucontroller.disable.b7e3e4aa", defaultValue: "Disable", bundle: .main, comment: "User-facing text in ClaudeCodeIntegrationMenuController."))
            if apiAlert.runModal() == .alertSecondButtonReturn {
                iTermAPIHelper.setEnabled(false)
            }
        }
    }

    // MARK: - Menu Validation

    // The three Claude Code menu items partition by install state:
    // never set up → only Install is visible; previously set up
    // → Reinstall and Uninstall are both visible (Install is hidden).
    //
    // The "previously set up" predicate is OR-of-two-signals:
    // (a) live artifacts on disk (hooks / workgroup / triggers),
    // (b) the sticky claudeCodeIntegrationCompleted flag.
    //
    // (b) matters because the wholesale-strip case — Claude Code
    // rewriting ~/.claude/settings.json and removing the cc-status
    // entry — leaves (a) false. A user in that state isn't doing
    // a fresh Install; they're recovering. Reinstall is the right
    // label, and Uninstall stays available so the user can clear
    // the sticky flag and silence the broken-install prompt
    // permanently if they no longer want the integration.
    @objc func validateInstallMenuItem(_ item: NSMenuItem) -> Bool {
        item.isHidden = integrationKnownToHaveExisted
        return true
    }

    @objc func validateReinstallMenuItem(_ item: NSMenuItem) -> Bool {
        item.isHidden = !integrationKnownToHaveExisted
        return true
    }

    @objc func validateUninstallMenuItem(_ item: NSMenuItem) -> Bool {
        item.isHidden = !integrationKnownToHaveExisted
        return true
    }

    private var integrationKnownToHaveExisted: Bool {
        return anyArtifactInstalled
            || iTermUserDefaults.claudeCodeIntegrationCompleted
    }

    private var anyArtifactInstalled: Bool {
        return ClaudeCodeOnboarding.hooksAlreadyInstalled()
            || ClaudeCodeOnboarding.workgroupAlreadyInstalled()
            || ClaudeCodeOnboarding.triggersAlreadyInstalled()
    }
}
