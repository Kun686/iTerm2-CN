//
//  InjectTrigger.swift
//  iTerm2SharedARC
//
//  Created by George Nachman on 6/26/21.
//

import Foundation

@objc(iTermInjectTrigger)
class InjectTrigger: Trigger {
    override var description: String {
        return String(localized: "ui.swift.triggers.injecttrigger.inject_data_0.93f402b9", defaultValue: "Inject Data “\(String(describing: self.param ?? ""))”", bundle: .main, comment: "User-facing text in InjectTrigger.")
    }

    override static var title: String {
        return String(localized: "ui.swift.triggers.injecttrigger.inject_data.d0cb440a", defaultValue: "Inject Data…", bundle: .main, comment: "User-facing text in InjectTrigger.")
    }

    override func takesParameter() -> Bool {
        return true
    }

    // Requires a live session to inject data
    override var allowedMatchTypes: Set<NSNumber> {
        var set: Set<NSNumber> = [NSNumber(value: iTermTriggerMatchType.regex.rawValue)]
        set.formUnion(EventTriggerMatchTypeHelper.allEventTypesExceptSessionEndedSet)
        return set
    }

    override func triggerOptionalParameterPlaceholder(withInterpolation interpolation: Bool) -> String? {
        return String(localized: "ui.swift.triggers.injecttrigger.use_e_for_esc_a_for_g.ce3aeb9f", defaultValue: "Use \\e for esc, \\a for ^G.", bundle: .main, comment: "User-facing text in InjectTrigger.")
    }

    override func performAction(withCapturedStrings strings: [String],
                                capturedRanges: UnsafePointer<NSRange>,
                                in session: iTermTriggerSession,
                                onString s: iTermStringLine,
                                atAbsoluteLineNumber lineNumber: Int64,
                                useInterpolation: Bool,
                                stop: UnsafeMutablePointer<ObjCBool>) -> Bool {
        let scopeProvider = session.triggerSessionVariableScopeProvider(self)
        let scheduler = scopeProvider.triggerCallbackScheduler()
        paramWithBackreferencesReplaced(withValues: strings,
                                        absLine: lineNumber,
                                        scope: scopeProvider,
                                        useInterpolation: useInterpolation).then { message in
            if let data = (message as String).data(using: .utf8) {
                scheduler.scheduleTriggerCallback {
                    session.triggerSession(self, inject: data);
                }
            }
        }
        return false
    }
}
