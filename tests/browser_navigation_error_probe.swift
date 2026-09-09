// Actual NSError, navigation-log and error-page display excerpts. No WebKit I/O.
import Foundation

let probeBundle: Bundle = {
    guard (2...3).contains(CommandLine.arguments.count),
          let bundle = Bundle(path: CommandLine.arguments[1]) else { exit(2) }
    return bundle
}()
var logLines: [String] = []
var fileLogLines: [String] = []
func RLog(_ message: String) { logLines.append(message) }
func NSLog(_ message: String) { fileLogLines.append(message) }
let path = "/synthetic/用户 空格/100%.txt"
// BROWSER-SCHEME-DECLARATIONS

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
    fileLogLines = []
    let nsError = error
    // NAVIGATION-ERROR-LOG
    // LOCAL-PAGE-ERROR-LOG
    return ["domain": error.domain, "code": error.code, "userInfo": error.userInfo,
            "raw": error.localizedDescription, "log": logLines, "fileLog": fileLogLines,
            "displayed": iTermBrowserErrorHandler().display(error)]
}

let mode = CommandLine.arguments.dropFirst(2).first
let unknownErrors: [NSError] = mode == "onboarding" ? [
    NSError(domain: "external.synthetic", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to encode redirect HTML"]),
    NSError(domain: "iTermBrowserWelcomePageHandler", code: -99,
            userInfo: [NSLocalizedDescriptionKey: "Failed to encode redirect HTML"]),
    NSError(domain: "iTermBrowserWelcomePageHandler", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Future welcome error 用户"]),
    NSError(domain: "iTermBrowserOnboardingHandler", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to encode redirect HTML"]),
    NSError(domain: "iTermBrowserStaticPageHandler", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Future static error 用户"]),
    NSError(domain: "iTermBrowserStaticPageHandler", code: -1, userInfo: [:]),
] : mode == "local-pages" ? [
    NSError(domain: "external.synthetic", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "No path specified"]),
    NSError(domain: "iTermBrowserManager", code: -99,
            userInfo: [NSLocalizedDescriptionKey: "No path specified"]),
    NSError(domain: "iTermBrowserHistoryViewHandler", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Future history error 用户"]),
    NSError(domain: "iTermBrowserLocalPageManager", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Unknown external URL"]),
    NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError,
            userInfo: [NSLocalizedDescriptionKey: "Future file error 用户"]),
    NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError,
            userInfo: [NSLocalizedDescriptionKey: "File not found: "]),
    NSError(domain: NSCocoaErrorDomain, code: -99,
            userInfo: [NSLocalizedDescriptionKey: "File not found: \(path)"]),
    NSError(domain: "external.synthetic", code: NSFileNoSuchFileError,
            userInfo: [NSLocalizedDescriptionKey: "File not found: \(path)"]),
] : [
    NSError(domain: "external.synthetic", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]),
    NSError(domain: "iTermBrowserManager", code: -99,
            userInfo: [NSLocalizedDescriptionKey: "Unknown URL scheme"]),
    NSError(domain: "iTermBrowserManager", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Future error 用户"]),
    NSError(domain: "iTermBrowserBookmarkViewHandler", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]),
    NSError(domain: "iTermBrowserManager", code: -1, userInfo: [:]),
]
let data = try JSONSerialization.data(withJSONObject: [
    "known": makeErrors().map { snapshot($0) }, "unknown": unknownErrors.map { snapshot($0) }
])
FileHandle.standardOutput.write(data)
