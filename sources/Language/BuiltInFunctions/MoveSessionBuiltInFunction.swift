//
//  MoveSessionBuiltInFunction.swift
//  iTerm2SharedARC
//
//  Created by George Nachman on 7/9/23.
//

import Foundation

class MoveSessionBuiltInFunction: iTermBuiltInFunction {
    @objc static func registerBuiltInFunction() {
        let f = iTermBuiltInFunction(name: "move_session",
                                        arguments: ["session": NSString.self,
                                                    "destination": NSString.self,
                                                    "vertical": NSNumber.self,
                                                    "before": NSNumber.self],
                                        optionalArguments: Set(),
                                        defaultValues: [:],
                                     context: .session,
                                     sideEffectsPlaceholder: "[move_session]") { parameters, completion in
            do {
                guard let session = parameters["session"] as? String,
                      let destination = parameters["destination"] as? String,
                      let vertical = parameters["vertical"] as? Bool,
                      let before = parameters["before"] as? Bool else {
                    completion(nil, NSError(domain: "com.iterm2.move-session",
                                            code: 1,
                                            userInfo: [NSLocalizedDescriptionKey: String(localized: "ui.swift.language.builtinfunctions.movesessionbuiltinfunction.invalid_argument.d66ea613", defaultValue: "Invalid argument", bundle: .main, comment: "Error shown when move_session receives an invalid argument.")]))
                    return
                }
                do {
                    try moveSession(session: session,
                                    destination: destination,
                                    vertical: vertical,
                                    before: before)
                    completion(nil, nil)
                } catch {
                    completion(nil, error)
                }
            }
        }
        iTermBuiltInFunctions.sharedInstance().register(f, namespace: "iterm2")
    }

    private static func moveSession(session sourceID: String, destination destinationID: String, vertical: Bool, before: Bool) throws {
        guard let source = iTermController.sharedInstance().session(withGUID: sourceID),
              let destination = iTermController.sharedInstance().session(withGUID: destinationID) else {
            throw NSError(domain: "com.iterm2.move-session",
                          code: 2,
                          userInfo: [NSLocalizedDescriptionKey: String(localized: "ui.swift.language.builtinfunctions.movesessionbuiltinfunction.invalid_session_id.2aa56153", defaultValue: "Invalid session ID", bundle: .main, comment: "Error shown when move_session receives an invalid session identifier.")])
        }
        if !source.is(compatibleWith: destination) {
            throw NSError(domain: "com.iterm2.move-session",
                          code: 3,
                          userInfo: [NSLocalizedDescriptionKey: String(localized: "ui.swift.language.builtinfunctions.movesessionbuiltinfunction.sessions_are_not_compatible.ea3c5f1c", defaultValue: "Sessions are not compatible", bundle: .main, comment: "Error shown when move_session cannot combine two sessions.")])
        }
        guard let sourceTab = source.delegate as? PTYTab, let destinationTab = destination.delegate as? PTYTab else {
            throw NSError(domain: "com.iterm2.move-session",
                          code: 5,
                          userInfo: [NSLocalizedDescriptionKey: String(localized: "ui.swift.language.builtinfunctions.movesessionbuiltinfunction.session_has_no_tab.22312377", defaultValue: "Session has no tab", bundle: .main, comment: "Error shown when move_session finds a session without a tab.")])
        }
        if sourceTab.lockedSession == source || destinationTab.lockedSession == destination {
            throw NSError(domain: "com.iterm2.move-session",
                          code: 6,
                          userInfo: [NSLocalizedDescriptionKey: String(localized: "ui.swift.language.builtinfunctions.movesessionbuiltinfunction.can_t_move_locked_session.ff90d933", defaultValue: "Can't move locked session", bundle: .main, comment: "Error shown when move_session is asked to move a locked session.")])
        }
        if destinationTab.hasMaximizedPane() {
            destinationTab.unmaximize()
        }
        if sourceTab.hasMaximizedPane() {
            sourceTab.unmaximize()
        }
        let half: SplitSessionHalf = {
            switch (vertical, before) {
            case (false, false):
                return .northHalf
            case (false, true):
                return .southHalf
            case (true, false):
                return .eastHalf
            case (true, true):
                return .westHalf
            }
        }()
        MovePaneController.sharedInstance().movePane(source)
        MovePaneController.sharedInstance().didSelectDestinationSession(destination, half: half)
    }
}
