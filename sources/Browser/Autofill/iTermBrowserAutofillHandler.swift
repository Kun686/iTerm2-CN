import Foundation
import WebKit

@MainActor
protocol iTermBrowserAutofillHandlerDelegate: AnyObject {
    func autoFillHandler(_ handler: iTermBrowserAutofillHandler,
                         requestAutofillForHost host: String,
                         fields: [[String: Any]])
}

@MainActor
class iTermBrowserAutofillHandler {
    static let messageHandlerName = "iTermAutofillHandler"
    
    weak var delegate: iTermBrowserAutofillHandlerDelegate?
    
    private let sessionSecret: String
    private var pendingAutofillWebView: iTermBrowserWebView?
    private let contactSource = iTermBrowserAutofillContactSource()
    
    init?() {
        guard let secret = String.makeSecureHexString() else {
            return nil
        }
        self.sessionSecret = secret
    }
    
    var javascript: String {
        return iTermBrowserTemplateLoader.loadTemplate(
            named: "autofill-detector",
            type: "js",
            substitutions: [
                "SECRET": sessionSecret,
                "AUTOFILL_ACTION_FORMAT_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.script.autofill.action_format", defaultValue: "Autofill %1$@"),
                "AUTOFILL_FIELD_GENERIC_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.script.autofill.field.generic", defaultValue: "field"),
                "AUTOFILL_FIELD_FIRST_NAME_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.script.autofill.field.first_name", defaultValue: "first name"),
                "AUTOFILL_FIELD_LAST_NAME_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.script.autofill.field.last_name", defaultValue: "last name"),
                "AUTOFILL_FIELD_FULL_NAME_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.script.autofill.field.full_name", defaultValue: "full name"),
                "AUTOFILL_FIELD_EMAIL_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.script.autofill.field.email", defaultValue: "email address"),
                "AUTOFILL_FIELD_PHONE_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.script.autofill.field.phone", defaultValue: "phone number"),
                "AUTOFILL_FIELD_ADDRESS1_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.script.autofill.field.address1", defaultValue: "street address"),
                "AUTOFILL_FIELD_ADDRESS2_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.script.autofill.field.address2", defaultValue: "address line 2"),
                "AUTOFILL_FIELD_CITY_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.script.autofill.field.city", defaultValue: "city"),
                "AUTOFILL_FIELD_STATE_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.script.autofill.field.state", defaultValue: "state or province"),
                "AUTOFILL_FIELD_ZIP_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.script.autofill.field.zip", defaultValue: "postal code"),
                "AUTOFILL_FIELD_COUNTRY_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.script.autofill.field.country", defaultValue: "country or region"),
                "AUTOFILL_FIELD_COMPANY_JSON": iTermBrowserTemplateLoader.localizedJavaScriptStringLiteral("ui.browser.script.autofill.field.company", defaultValue: "company")
            ])
    }
    
    enum AutofillAction: String {
        case autofillRequest
    }
    
    func handleMessage(webView: iTermBrowserWebView, message: WKScriptMessage) -> AutofillAction? {
        guard let body = message.body as? [String: Any],
              let secret = body["sessionSecret"] as? String,
              secret == sessionSecret,
              let typeString = body["type"] as? String,
              let action = AutofillAction(rawValue: typeString) else {
            return nil
        }
        
        switch action {
        case .autofillRequest:
            handleAutofillRequest(webView: webView, body: body)
        }
        
        return action
    }
    
    private func handleAutofillRequest(webView: iTermBrowserWebView, body: [String: Any]) {
        guard body["activeField"] as? [String: Any] != nil,
              let fields = body["fields"] as? [[String: Any]] else {
            return
        }
        
        pendingAutofillWebView = webView
        
        let host = webView.url?.host ?? "unknown"
        delegate?.autoFillHandler(self,
                                  requestAutofillForHost: host,
                                  fields: fields)
    }
    
    func fillFields(_ fields: [[String: String]]) async {
        guard let webView = pendingAutofillWebView else { return }
        
        let writer = iTermBrowserAutofillWriter(webView: webView)
        await writer.fillFields(fields)
    }

    func fillAll(webView: iTermBrowserWebView) async {
        DLog("fillAll() method called")
        
        // Create JavaScript that rediscovers autofillable fields and fills them all
        let js = iTermBrowserTemplateLoader.loadTemplate(
            named: "autofill-fill-all",
            type: "js", 
            substitutions: ["SECRET": sessionSecret])
        
        DLog("fillAll() loaded JavaScript template, length: \(js.count)")
        
        do {
            let result = try await webView.safelyEvaluateJavaScript(js, contentWorld: .defaultClient)
            if let resultDict = result as? [String: Any],
               let success = resultDict["success"] as? Bool,
               let fieldsFound = resultDict["fieldsFound"] as? Int {
                if success {
                    RLog("fillAll successfully found and triggered autofill for \(fieldsFound) fields")
                } else {
                    RLog("fillAll failed - authentication or other error")
                }
            }
        } catch {
            RLog("fillAll failed: \(error)")
        }
    }
}
