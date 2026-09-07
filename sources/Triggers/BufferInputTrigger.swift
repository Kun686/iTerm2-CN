//
//  BufferInputTrigger.swift
//  iTerm2
//
//  Created by George Nachman on 12/12/25.
//


@objc(iTermBufferInputTrigger)
class BufferInputTrigger: Trigger {
    private enum Tag: Int {
        case start = 0
        case stop = 1
    }

    @objc var shouldBuffer: Bool {
        switch Tag(rawValue: (self.param as? NSNumber)?.intValue ?? 0) {
        case .none, .start:
            return true
        case .stop:
            return false
        }
    }
    override var description: String {
        if shouldBuffer {
            return "Buffer Input"
        } else {
            return "Stop Buffering Input"
        }
    }

    override static var title: String {
        return String(localized: "ui.swift.triggers.bufferinputtrigger.buffer_input.ecb7661d", defaultValue: "Buffer Input…", bundle: .main, comment: "User-facing text in BufferInputTrigger.")
    }

    override func takesParameter() -> Bool {
        return true
    }

    // Requires a live session to buffer input
    override var allowedMatchTypes: Set<NSNumber> {
        var set: Set<NSNumber> = [NSNumber(value: iTermTriggerMatchType.regex.rawValue)]
        set.formUnion(EventTriggerMatchTypeHelper.allEventTypesExceptSessionEndedSet)
        return set
    }

    override func paramIsPopupButton() -> Bool {
        true
    }

    override var isIdempotent: Bool {
        return true
    }

    override func index(for object: Any?) -> Int {
        return objectsSortedByValue(inDict: menuItemsForPoupupButton()!).firstIndex { obj in
            (obj as? NSNumber) == (object as? NSNumber)
        } ?? -1
    }

    override func object(at index: Int) -> Any? {
        let sorted = objectsSortedByValue(inDict: menuItemsForPoupupButton()!)
        return sorted[index]
    }

    override func menuItemsForPoupupButton() -> [AnyHashable : Any]? {
        [ NSNumber(value: Tag.start.rawValue): String(localized: "ui.swift.triggers.bufferinputtrigger.start_buffering_input.9e4cac20", defaultValue: "Start Buffering Input", bundle: .main, comment: "User-facing text in BufferInputTrigger."),
          NSNumber(value: Tag.stop.rawValue): String(localized: "ui.swift.triggers.bufferinputtrigger.stop_buffering_input.b1c5cfdb", defaultValue: "Stop Buffering Input", bundle: .main, comment: "User-facing text in BufferInputTrigger.") ]
    }

    override func performAction(withCapturedStrings strings: [String],
                                capturedRanges: UnsafePointer<NSRange>,
                                in session: iTermTriggerSession,
                                onString s: iTermStringLine,
                                atAbsoluteLineNumber lineNumber: Int64,
                                useInterpolation: Bool,
                                stop: UnsafeMutablePointer<ObjCBool>) -> Bool {
        session.triggerSetBufferInput(self, shouldBuffer: shouldBuffer)
        return false
    }

    override func paramAttributedString() -> NSAttributedString? {
        NSAttributedString(string: shouldBuffer ? String(localized: "ui.swift.triggers.bufferinputtrigger.start_buffering.f8706b96", defaultValue: "Start buffering", bundle: .main, comment: "User-facing text in BufferInputTrigger.") : String(localized: "ui.swift.triggers.bufferinputtrigger.stop_buffering.6d97a5ce", defaultValue: "Stop buffering", bundle: .main, comment: "User-facing text in BufferInputTrigger."),
                           attributes: regularAttributes())
    }
}
