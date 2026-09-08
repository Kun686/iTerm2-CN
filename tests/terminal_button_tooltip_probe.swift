// Native excerpt probe: production tooltip expressions and NSViewToolTipOwner
// method, without terminal rendering, mouse events, preferences, or log files.
import AppKit
import Foundation

let probeBundle = Bundle(path: CommandLine.arguments[1])!
var capturedLog = ""
func DLog(_ value: @autoclosure () -> String) {
    capturedLog = value()
}

final class TerminalButton: NSObject {
    let tooltip: String
    init(tooltip: String) {
        self.tooltip = tooltip
    }
    override var description: String { "SyntheticTerminalButton" }
}

// TOOLTIP-OWNER-METHOD

// TOOLTIP-DISPLAY-LOOKUP

func snapshot(_ value: String) -> [String: String] {
    let button = TerminalButton(tooltip: value)
    let displayed = button.view(NSView(), stringForToolTip: 0, point: .zero, userData: nil)
    return ["stored": button.tooltip, "log": capturedLog, "displayed": displayed]
}

func snapshots() -> [[String: String]] {
    // TOOLTIP-CALL-SITES
}

let result = try JSONSerialization.data(withJSONObject: snapshots(), options: [.sortedKeys])
FileHandle.standardOutput.write(result)
