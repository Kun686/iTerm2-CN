// Compiles the real property-list writer and export catch block. All input and
// output files are synthetic and temporary; no settings, Keychain, or UI access.
import Foundation

let probeBundle: Bundle = {
    guard CommandLine.arguments.count == 3,
          let bundle = Bundle(path: CommandLine.arguments[1]) else { exit(2) }
    return bundle
}()

private var capturedLogs: [String] = []
private func RLog(_ message: String) { capturedLogs.append(message) }

// EXPORT-ERROR-ENUM
// PROPERTY-LIST-WRITER

private enum ExportProbe {
    // EXPORT-OUTCOME

    static func perform(_ operation: () throws -> Void) -> ExportOutcome {
        do {
            try operation()
            return .success
        }
        // EXPORT-CATCH
    }
}

private func snapshot(_ name: String, operation: () throws -> Void) -> [String: Any] {
    capturedLogs = []
    let outcome = ExportProbe.perform(operation)
    switch outcome {
    case .success:
        return ["name": name, "outcome": "success", "logs": capturedLogs]
    case .cancelled:
        return ["name": name, "outcome": "cancelled", "logs": capturedLogs]
    case .failure(let message):
        return ["name": name, "outcome": "failure", "message": message, "logs": capturedLogs]
    }
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let valid: [String: Any] = ["original-key": "原文", "number": 42, "enabled": true]
let invalid: [String: Any] = ["unsupported": NSObject()]
var rows = [
    snapshot("valid") {
        try valid.saveAsPropertyList(to: outputDirectory.appendingPathComponent("valid.plist"))
    },
    snapshot("invalid") {
        try invalid.saveAsPropertyList(to: outputDirectory.appendingPathComponent("invalid.plist"))
    },
    snapshot("write-failure") {
        try valid.saveAsPropertyList(to: outputDirectory.appendingPathComponent("absent/file.plist"))
    },
    snapshot("unknown-bug") { throw ImportExportError.bug("Synthetic 原文") }
]
do {
    let data = try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])
    FileHandle.standardOutput.write(data)
} catch {
    FileHandle.standardError.write(Data("Cannot serialize export probe result\n".utf8))
    exit(3)
}
