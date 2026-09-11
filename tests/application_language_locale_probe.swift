import Foundation

// Non-locale application dependencies only. No locale or encoding calculation
// is mocked; iTermLocaleGuesser.swift and the host's setlocale run unchanged.
enum AppSignatureValidator {
    static func warn(reason: String) {
        fputs(reason + "\n", stderr)
    }
}

func it_fatalError(_ message: String) -> Never {
    fputs(message + "\n", stderr)
    exit(90)
}

func it_assert(_ condition: Bool, _ message: String) {
    if !condition { it_fatalError(message) }
}

func RLog(_ message: String) {}
func DLog(_ message: String) {}

enum iTermAdvancedSettingsModel {
    static func fallbackLCCType() -> String? { nil }
    static func doNotSetCtype() -> Bool { false }
}

// Only used by the locale display-title API, which this probe does not invoke.
struct LocaleComponents {
    let title: String
    init(_ value: String) { title = value }
}

@main
struct LocaleInputProbe {
    static func main() {
        let arguments = CommandLine.arguments
        guard arguments.count >= 4, let encoding = UInt(arguments[3]) else {
            exit(2)
        }
        let environmentBefore = ProcessInfo.processInfo.environment
        guard PrepareLocaleProbe(arguments[1], arguments[2]) else {
            _ = FinishLocaleProbe()
            exit(3)
        }
        // This is the exact convenience initializer used by PTYSession.
        let guesser = iTermLocaleGuesser(encoding: encoding)
        let result: [String: Any] = [
            "lang": guesser.valueForLanguageEnvironmentVariable() as Any? ?? NSNull(),
            "ctype": guesser.dictionaryWithLC_CTYPE() ?? [:],
            "localized": Bundle.main.localizedString(forKey: "probe", value: "MISSING", table: nil),
            "environmentUnchanged": environmentBefore == ProcessInfo.processInfo.environment,
            "globalUnchanged": FinishLocaleProbe()
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
        } catch {
            fputs("Could not encode locale probe result\n", stderr)
            exit(4)
        }
    }
}
