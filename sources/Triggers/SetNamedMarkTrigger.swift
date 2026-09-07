//
//  SetNamedMarkTrigger.swift
//  iTerm2
//
//  Created by George Nachman on 12/31/24.
//

@objc(iTermSetNamedMarkTrigger)
class SetNamedMarkTrigger: Trigger {
    override var description: String {
        return "Set Named Mark to \(self.param ?? "")"
    }

    override static var title: String {
        return String(localized: "ui.swift.triggers.setnamedmarktrigger.set_named_mark.58bf242c", defaultValue: "Set Named Mark", bundle: .main, comment: "User-facing text in SetNamedMarkTrigger.")
    }

    override func takesParameter() -> Bool {
        return true
    }

    override var allowedMatchTypes: Set<NSNumber> {
        var set: Set<NSNumber> = [NSNumber(value: iTermTriggerMatchType.regex.rawValue)]
        set.formUnion(EventTriggerMatchTypeHelper.allEventTypesSet)
        return set
    }

    override func triggerOptionalParameterPlaceholder(withInterpolation interpolation: Bool) -> String? {
        return String(localized: "ui.swift.triggers.setnamedmarktrigger.name_for_this_mark.4df3fc3e", defaultValue: "Name for this mark", bundle: .main, comment: "User-facing text in SetNamedMarkTrigger.")
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
                                        useInterpolation: useInterpolation).then { [weak self] message in
            scheduler.scheduleTriggerCallback {
                if let self {
                    session.triggerSession(self, addNamedMarkWithName: message as String, atAbsoluteLine: lineNumber)
                }
            }
        }
        return true
    }
}
