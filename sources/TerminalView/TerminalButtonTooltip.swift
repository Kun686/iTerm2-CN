import Foundation

// The stored tooltip is also a diagnostic value. Translate only the text
// returned to AppKit; do not reinterpret unknown or user-defined strings.
enum TerminalButtonTooltip {
    static func localized(_ diagnosticTooltip: String) -> String {
        switch diagnosticTooltip {
        case "Reveal embedded command":
            return String(localized: "ui.swift.terminalview.terminalbutton.reveal_embedded_command.9595f2da", defaultValue: "Reveal embedded command", bundle: .main, comment: "User-facing text in TerminalButton.")
        case "Unfold block":
            return String(localized: "ui.swift.terminalview.terminalbutton.unfold_block.9376de0d", defaultValue: "Unfold block", bundle: .main, comment: "User-facing text in TerminalButton.")
        case "Fold block":
            return String(localized: "ui.swift.terminalview.terminalbutton.fold_block.0908eff3", defaultValue: "Fold block", bundle: .main, comment: "User-facing text in TerminalButton.")
        case "Copy command to clipboard":
            return String(localized: "ui.swift.terminalview.terminalbutton.copy_command_to_clipboard.334c24c1", defaultValue: "Copy command to clipboard", bundle: .main, comment: "User-facing text in TerminalButton.")
        case "Toggle named mark":
            return String(localized: "ui.swift.terminalview.terminalbutton.toggle_named_mark.92a55bcf", defaultValue: "Toggle named mark", bundle: .main, comment: "User-facing text in TerminalButton.")
        case "Share command…":
            return String(localized: "ui.swift.terminalview.terminalbutton.share_command.cb90afe1", defaultValue: "Share command…", bundle: .main, comment: "User-facing text in TerminalButton.")
        case "Open Command Info…":
            return String(localized: "ui.swift.terminalview.terminalbutton.open_command_info.732e6e54", defaultValue: "Open Command Info…", bundle: .main, comment: "User-facing text in TerminalButton.")
        case "Fold command":
            return String(localized: "ui.swift.terminalview.terminalbutton.fold_command.af663c4c", defaultValue: "Fold command", bundle: .main, comment: "User-facing text in TerminalButton.")
        case "Unfold command":
            return String(localized: "ui.swift.terminalview.terminalbutton.unfold_command.83f2162b", defaultValue: "Unfold command", bundle: .main, comment: "User-facing text in TerminalButton.")
        case "Command Settings…":
            return String(localized: "ui.swift.terminalview.terminalbutton.command_settings.529786b4", defaultValue: "Command Settings…", bundle: .main, comment: "User-facing text in TerminalButton.")
        default:
            return diagnosticTooltip
        }
    }
}
