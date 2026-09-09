// Actual NSError, navigation-log and error-page display excerpts. No WebKit I/O.
import Foundation

let probeBundle: Bundle = {
    guard CommandLine.arguments.count == 2,
          let bundle = Bundle(path: CommandLine.arguments[1]) else { exit(2) }
    return bundle
}()
var logLines: [String] = []
func RLog(_ message: String) { logLines.append(message) }

func makeErrors() -> [NSError] {
    // SCHEME-ERROR-CONSTRUCTORS
}

class iTermBrowserErrorHandler: NSObject {
    // NAVIGATION-DISPLAY-HELPER

    func display(_ error: Error) -> String {
        // NAVIGATION-DISPLAY-CALL
    }
}

func snapshot(_ error: NSError) -> [String: Any] {
    logLines = []
    let nsError = error
    // NAVIGATION-ERROR-LOG
    return ["domain": error.domain, "code": error.code, "userInfo": error.userInfo,
            "raw": error.localizedDescription, "log": logLines,
            "displayed": iTermBrowserErrorHandler().display(error)]
}

let unknown = [
    NSError(domain: "external.synthetic", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]),
    NSError(domain: "iTermBrowserManager", code: -99,
            userInfo: [NSLocalizedDescriptionKey: "Unknown URL scheme"]),
    NSError(domain: "iTermBrowserManager", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Future error 用户"]),
    NSError(domain: "iTermBrowserBookmarkViewHandler", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]),
    NSError(domain: "iTermBrowserManager", code: -1, userInfo: [:]),
].map { snapshot($0) }
let data = try JSONSerialization.data(withJSONObject: [
    "known": makeErrors().map { snapshot($0) }, "unknown": unknown
])
FileHandle.standardOutput.write(data)
