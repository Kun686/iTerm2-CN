// Actual toolbar help method; captures Markdown before the AppKit renderer.
import Foundation

let probeBundle: Bundle = {
    guard CommandLine.arguments.count == 2,
          let bundle = Bundle(path: CommandLine.arguments[1]) else { exit(2) }
    return bundle
}()

final class HelpReceiver {
    var messages: [String] = []
    func it_showInformativeMessage(withMarkdown message: String) {
        messages.append(message)
    }
}

final class ToolbarProbe {
    let devNullIndicator = HelpReceiver()
    // TOOLBAR-HELP-METHOD

    func capture() -> [String] {
        showDevNullInfoPopover()
        return devNullIndicator.messages
    }
}

let data = try JSONSerialization.data(withJSONObject: ToolbarProbe().capture())
FileHandle.standardOutput.write(data)
