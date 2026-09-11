//
//  AIConnectionTester.swift
//  iTerm2
//
//  Created by George Nachman on 8/2/26.
//

import AppKit

// Result of a test attempt. `.cancelled` means the user backed out of the
// API-key prompt; the caller should stay silent rather than show an alert.
@objc(iTermAIConnectionTestOutcome)
enum AIConnectionTestOutcome: Int {
    case success
    case failure
    case cancelled
}

// Drives a one-shot "does this configuration actually work?" probe for the
// manual AI model editor's Test button. Given the in-progress form values, it
// resolves the vendor exactly as request time would, obtains that vendor's
// stored API key (prompting for one via the normal registration sheet if none
// is configured), sends a minimal non-streaming completion through the same
// plugin path a real chat uses, and classifies the outcome into a
// success/failure message the caller shows in an alert.
@objc(iTermAIConnectionTester)
class AIConnectionTester: NSObject {
    // Sends the probe. `completion` is always called on the main thread.
    @objc(testModelName:url:api:functionCalling:supportsTemperature:customHeaders:inWindow:completion:)
    static func test(modelName: String,
                     url: String,
                     api: iTermAIAPI,
                     functionCalling: Bool,
                     supportsTemperature: Bool,
                     customHeaders: [[String: String]],
                     inWindow window: NSWindow,
                     completion: @escaping (AIConnectionTestOutcome, String) -> Void) {
        let vendor = LLMMetadata.objcManualVendor(api: api, url: url, modelName: modelName)
        // requestRegistration returns the stored key immediately when present,
        // otherwise presents the registration sheet on `window` and stores what
        // the user enters. A nil result means the user cancelled.
        AITermControllerRegistrationHelper.instance.requestRegistration(in: window, for: vendor) { registration in
            guard let registration else {
                completion(.cancelled, "")
                return
            }
            send(modelName: modelName,
                 url: url,
                 api: api,
                 functionCalling: functionCalling,
                 supportsTemperature: supportsTemperature,
                 customHeaders: customHeaders,
                 apiKey: registration.apiKey,
                 vendor: vendor,
                 completion: completion)
        }
    }

    private static func send(modelName: String,
                             url: String,
                             api: iTermAIAPI,
                             functionCalling: Bool,
                             supportsTemperature: Bool,
                             customHeaders: [[String: String]],
                             apiKey: String,
                             vendor: iTermAIVendor,
                             completion: @escaping (AIConnectionTestOutcome, String) -> Void) {
        // The reviewer placeholder key contacts no service, so a live probe would
        // fail. Report success and explain, matching the runtime short-circuit.
        if apiKey == AITermController.reviewPlaceholderAPIKey {
            completion(.success, String(localized: "ui.swift.aiterm.aiconnectiontester.placeholder_key_in_use_ai_responses_are_simulated.3a6ad74b", defaultValue: "Placeholder key in use: AI responses are simulated for App Review and no external service is contacted.", bundle: .main, comment: "User-facing text in AIConnectionTester."))
            return
        }
        var features = Set<AIMetadata.Model.Feature>()
        if functionCalling {
            features.insert(.functionCalling)
        }
        // Probe non-streaming with a tiny response cap: the whole point is to
        // confirm auth + endpoint reachability, not to exercise streaming.
        var model = AIMetadata.Model(name: modelName,
                                     contextWindowTokens: 8_192,
                                     maxResponseTokens: 64,
                                     url: url,
                                     api: api,
                                     features: features,
                                     vectorStoreConfig: .disabled,
                                     vendor: vendor)
        // Honor the editor's "Supports temperature" toggle so the probe omits
        // the temperature field for endpoints that 400 on it, matching what a
        // real chat request does for the saved model.
        model.supportsTemperature = supportsTemperature
        // Include the editor's custom headers so the probe carries the same
        // auth header a real request to the saved model would (issue 12975):
        // otherwise an endpoint gated by a custom Authorization header always
        // 401s the test even though real requests would succeed.
        model.customHeaders = customHeaders
        let provider = LLMProvider(model: model)
        guard provider.urlIsValid else {
            completion(.failure, String(localized: "ui.swift.aiterm.aiconnectiontester.the_url_is_not_valid.34088ca6", defaultValue: "The URL is not valid.", bundle: .main, comment: "User-facing text in AIConnectionTester."))
            return
        }
        let builder = LLMRequestBuilder(provider: provider,
                                        apiKey: apiKey,
                                        messages: [LLM.Message(role: .user, content: "Hi")],
                                        stream: false,
                                        hostedTools: HostedTools())
        let request: WebRequest
        do {
            request = try builder.webRequest()
        } catch {
            completion(.failure, String(localized: "ui.swift.aiterm.aiconnectiontester.could_not_build_a_request_0.20966816", defaultValue: "Could not build a request: \(error.localizedDescription)", bundle: .main, comment: "User-facing text in AIConnectionTester."))
            return
        }
        _ = iTermAIClient.instance.request(webRequest: request, stream: nil) { result in
            switch result {
            case .success(let response):
                let (result, message) = outcome(for: response, provider: provider)
                completion(result, message)
            case .failure(let error):
                completion(.failure, error.reason)
            }
        }
    }

    // Classifies a successful round-trip. The plugin reports transport failures
    // via WebResponse.error; a well-formed HTTP error from the vendor arrives as
    // a 200-to-us body that decodes into an error payload. Both are failures.
    private static func outcome(for response: WebResponse,
                                provider: LLMProvider) -> (AIConnectionTestOutcome, String) {
        if let error = response.error, !error.isEmpty {
            if let reason = LLMErrorParser.errorReason(data: response.data.lossyData), !reason.isEmpty {
                return (.failure, reason)
            }
            return (.failure, error)
        }
        if let reason = LLMErrorParser.errorReason(data: response.data.lossyData), !reason.isEmpty {
            return (.failure, reason)
        }
        var parser = provider.responseParser()
        do {
            _ = try parser.parse(data: response.data.lossyData)
            return (.success, String(localized: "ui.swift.aiterm.aiconnectiontester.the_connection_succeeded_the_model_responded_normally.7bf46371", defaultValue: "The connection succeeded. The model responded normally.", bundle: .main, comment: "User-facing text in AIConnectionTester."))
        } catch {
            return (.failure, String(localized: "ui.swift.aiterm.aiconnectiontester.the_server_responded_but_its_reply_could_not.42bdcd86", defaultValue: "The server responded but its reply could not be understood: \(error.localizedDescription)", bundle: .main, comment: "User-facing text in AIConnectionTester."))
        }
    }
}
