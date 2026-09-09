// Uses actual provider-name/host checks, alert-name expression, and error text.
// Only the configured model/URL and vendor failure are synthetic; no requests.
import Foundation

let probeBundle: Bundle = {
    guard CommandLine.arguments.count == 2,
          let bundle = Bundle(path: CommandLine.arguments[1]) else { exit(2) }
    return bundle
}()

struct LLMMetadata {
    // PROVIDER-HOST-CHECKS
}

struct LLMProvider {
    struct Model { let name: String }
    let model: Model
    let endpoint: URL
    func url(apiKey: String, streaming: Bool) -> URL { endpoint }
    // PROVIDER-NAME-MEMBERS
}

enum AITermController {
    static var provider: LLMProvider?
}

func snapshot(_ llmProvider: LLMProvider?) -> [String: String] {
    AITermController.provider = llmProvider
    // PROVIDER-ALERT-NAME
    let error = "Synthetic vendor 原文"
    // PROVIDER-ERROR-NAME
    let message = /* PROVIDER-ERROR-TEXT */
    let reason = AIError(message)
    let event = /* PROVIDER-ERROR-EVENT */
    return ["name": provider, "alertName": providerName,
            "error": reason.description, "event": event,
            "nsError": (reason as NSError).localizedDescription]
}

let fixtures = [
    ("https://api.openai.com/v1", "model"),
    ("https://generativelanguage.googleapis.com/v1", "model"),
    ("https://example.azure.com/v1", "model"),
    ("https://api.deepseek.com/v1", "model"),
    ("https://api.anthropic.com/v1", "model"),
    ("https://example.invalid/v1", "llama-synthetic"),
    ("https://example.invalid/v1", "custom")
]
var snapshots = fixtures.map { endpoint, name in
    snapshot(LLMProvider(model: .init(name: name), endpoint: URL(string: endpoint)!))
}
snapshots.append(snapshot(nil))
do {
    let data = try JSONSerialization.data(withJSONObject: snapshots, options: [.sortedKeys])
    FileHandle.standardOutput.write(data)
} catch {
    FileHandle.standardError.write(Data("Cannot serialize provider probe result\n".utf8))
    exit(3)
}
