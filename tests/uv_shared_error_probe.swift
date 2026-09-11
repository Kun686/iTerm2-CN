// Actual uv error factories and shared log consumers, with synthetic inputs.
// No network, installation, disk logs or application preferences are used.
import Foundation

let probeBundle = Bundle(path: CommandLine.arguments[1])!
var capturedLog = ""
func RLog(_ value: String) { capturedLog = value }

class iTermUvProvisioner: NSObject {
    // UV-PRODUCTION-MEMBERS
}

extension iTermUvProvisioner {
    static func snapshot(_ error: NSError) -> [String: Any] {
        let minor = "3.12"
        // UV-PRODUCTION-LOG
        return ["domain": error.domain, "code": error.code, "userInfo": error.userInfo,
                "objc": UVImportSnapshot(error), "swiftLog": capturedLog]
    }
}

var errors = [NSError]()
let manifests = ["not json", "[]", CommandLine.arguments[2], CommandLine.arguments[3],
                 CommandLine.arguments[4]]
for manifest in manifests {
    switch iTermUvProvisioner.selectedEntry(fromManifestData: Data(manifest.utf8),
                                           runningMacOSVersion: "14.0.0") {
    case .failure(let error): errors.append(error as NSError)
    case .success: exit(3)
    }
}
errors.append(iTermUvProvisioner.cancelError())
errors.append(NSError(domain: "external.synthetic", code: 42,
                      userInfo: [NSLocalizedDescriptionKey: "External 原文",
                                 NSDebugDescriptionErrorKey: "Different diagnostic detail"]))
func upgradeMessages() -> [String] {
    let version = "0.12.0"
    let from = "0.12.0"
    let to = "0.13.0"
    // UV-UPGRADE-MESSAGES
}
let result: [String: Any] = ["errors": errors.map(iTermUvProvisioner.snapshot),
                            "updates": upgradeMessages().map { UVUpgradeMessageSnapshot($0) }]
let output = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
FileHandle.standardOutput.write(output)
