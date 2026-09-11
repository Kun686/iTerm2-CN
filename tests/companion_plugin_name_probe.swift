// Actual plugin specs, verification errors and log expressions; no installer I/O.
import Foundation

let probeBundle: Bundle = {
    guard CommandLine.arguments.count == 2,
          let bundle = Bundle(path: CommandLine.arguments[1]) else { exit(2) }
    return bundle
}()
var logLines: [String] = []
func RLog(_ message: String) { logLines.append(message) }

// PLUGIN-ERROR-ENUM

enum CompanionPluginInstaller {
    // PLUGIN-SPECS

    static func snapshot(ai: Bool) -> [String: Any] {
        let spec = ai ? aiSpec : companionSpec
        let dest = URL(fileURLWithPath: "/synthetic/Plugins/Example.app")
        let status: Int32 = 0
        logLines = []
        // PLUGIN-LOG-CONSUMERS
        let error: CompanionPluginInstallerError
        if ai {
            // PLUGIN-AI-ERROR
        } else {
            // PLUGIN-COMPANION-ERROR
        }
        guard case .verificationFailed(let storedName) = error else { exit(3) }
        return ["name": spec.name, "url": spec.zipURL.absoluteString,
                "bundleID": spec.bundleID, "logs": logLines,
                "storedErrorName": storedName, "displayed": error.localizedDescription]
    }
}

let unknownNames = ["", "User plugin 用户 %@", "AI and companion plugins"]
let unknown = unknownNames.map { name in
    ["name": name, "displayed": CompanionPluginInstallerError.verificationFailed(name).localizedDescription]
}
let data = try JSONSerialization.data(withJSONObject: [
    "plugins": [CompanionPluginInstaller.snapshot(ai: true), CompanionPluginInstaller.snapshot(ai: false)],
    "unknown": unknown
])
FileHandle.standardOutput.write(data)
