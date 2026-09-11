// Actual error constructors and notification consumer; no browser or updater I/O.
import Foundation

let probeBundle: Bundle = {
    guard CommandLine.arguments.count == 3,
          let bundle = Bundle(path: CommandLine.arguments[1]) else { exit(2) }
    return bundle
}()
var producerLogs: [String] = []
var consumerLogs: [String] = []
func RLog(_ message: String) { producerLogs.append(message) }
func print(_ message: String) { consumerLogs.append(message) }

class iTermBrowserAdblockManager: NSObject {
    // ADBLOCK-ERROR-KEY
}

func makeErrors(urlString: String, daysSinceUpdate: Int) -> [NSError] {
    // ADBLOCK-ERROR-CONSTRUCTORS
}

func recordProducerFailure(_ error: Error) {
    // ADBLOCK-PRODUCER-LOG
}

class iTermBrowserManager: NSObject {
    var displayed: String?
    var success: Bool?

    // ADBLOCK-DISPLAY-HELPER

    // ADBLOCK-NOTIFICATION-CONSUMER

    func notifySettingsPageOfAdblockUpdate(success: Bool, error: String? = nil) {
        self.success = success
        displayed = error
    }

    func receive(_ error: Error?) {
        let fields: [String: Any] = error.map { [iTermBrowserAdblockManager.errorKey: $0] } ?? [:]
        adblockDidFail(Notification(name: .init("synthetic-adblock-error"), userInfo: fields))
    }
}

func snapshot(_ error: NSError, producerFailure: Bool = false) -> [String: Any] {
    producerLogs = []
    consumerLogs = []
    if producerFailure { recordProducerFailure(error) }
    let consumer = iTermBrowserManager()
    consumer.receive(error)
    return ["domain": error.domain, "code": error.code, "userInfo": error.userInfo,
            "raw": error.localizedDescription, "producerLog": producerLogs,
            "consumerLog": consumerLogs, "displayed": consumer.displayed as Any,
            "success": consumer.success as Any]
}

let errors = makeErrors(urlString: CommandLine.arguments[2], daysSinceUpdate: 14)
let known = errors.enumerated().map { snapshot($0.element, producerFailure: $0.offset < 3) }
let passthrough = [
    NSError(domain: "synthetic.external", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Failed to parse adblock list response"]),
    NSError(domain: "iTermBrowserAdblockManager", code: 99,
            userInfo: [NSLocalizedDescriptionKey: "Downloaded content is not valid JSON format"]),
    NSError(domain: "iTermBrowserAdblockManager", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Future URL error 用户"]),
    NSError(domain: "iTermBrowserAdblockManager", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Future response error 用户"]),
    NSError(domain: "iTermBrowserAdblockManager", code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Future JSON error 用户"]),
    NSError(domain: "iTermBrowserAdblockManager", code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Adblock rules haven't been updated for many days"]),
    NSError(domain: "iTermBrowserAdblockManager", code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Adblock rules haven't been updated for 014 days"]),
    NSError(domain: "iTermBrowserAdblockManager", code: 4, userInfo: [:]),
].map { snapshot($0) }
consumerLogs = []
let empty = iTermBrowserManager()
empty.receive(nil)
let data = try JSONSerialization.data(withJSONObject: [
    "known": known, "passthrough": passthrough,
    "missingError": ["displayed": empty.displayed as Any, "logs": consumerLogs]
])
FileHandle.standardOutput.write(data)
