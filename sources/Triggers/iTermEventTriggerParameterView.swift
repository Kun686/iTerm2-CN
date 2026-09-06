//
//  iTermEventTriggerParameterView.swift
//  iTerm2SharedARC
//
//  Created by George Nachman on 3/1/26.
//

import AppKit

/// View for configuring event-specific trigger parameters
@objc(iTermEventTriggerParameterView)
class EventTriggerParameterView: NSView, NSTextFieldDelegate {

    // MARK: - Properties

    private var stackView: NSStackView!
    private var currentMatchType: iTermTriggerMatchType = .eventPromptDetected

    /// The current event parameters
    @objc var eventParams: [String: Any] {
        get {
            return collectParams()
        }
        set {
            applyParams(newValue)
        }
    }

    /// Callback when parameters change
    @objc var onParametersChanged: (() -> Void)?

    // UI elements for different event types
    private var exitCodeFilterPopup: NSPopUpButton?
    private var exitCodeTextField: NSTextField?
    private var timeoutTextField: NSTextField?
    private var thresholdTextField: NSTextField?
    private var sequenceIdTextField: NSTextField?
    private var directoryRegexTextField: NSTextField?
    private var hostRegexTextField: NSTextField?
    private var userRegexTextField: NSTextField?
    private var commandRegexTextField: NSTextField?
    private var notificationMessageRegexTextField: NSTextField?
    private var progressBarFilterPopup: NSPopUpButton?
    private var jobNameTextField: NSTextField?
    private var variableNameTextField: NSTextField?
    private var variableValueRegexTextField: NSTextField?

    // Completion support for the variable-name field. Mirrors the auto-
    // complete behavior of iTermFunctionCallTextFieldDelegate but for a bare
    // variable path (not an interpolated string).
    private let variablePathSource = iTermVariableHistory.pathSource(for: .session)
    private var isAutocompleting = false
    private var suppressAutocomplete = false

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Make sure we don't expand beyond our content
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    override var intrinsicContentSize: NSSize {
        return stackView.fittingSize
    }

    override var firstBaselineAnchor: NSLayoutYAxisAnchor {
        // Return the first baseline of the stackView, which will be the first row's baseline
        return stackView.firstBaselineAnchor
    }

    // MARK: - Public Methods

    /// Configure the view for a specific event type
    @objc func configure(forMatchType matchType: iTermTriggerMatchType) {
        currentMatchType = matchType

        // Clear existing views
        for view in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        // Reset UI element references
        exitCodeFilterPopup = nil
        exitCodeTextField = nil
        timeoutTextField = nil
        thresholdTextField = nil
        sequenceIdTextField = nil
        directoryRegexTextField = nil
        hostRegexTextField = nil
        userRegexTextField = nil
        commandRegexTextField = nil
        notificationMessageRegexTextField = nil
        progressBarFilterPopup = nil
        jobNameTextField = nil
        variableNameTextField = nil
        variableValueRegexTextField = nil

        // Add appropriate UI for this event type
        switch matchType {
        case .eventCommandFinished:
            addExitCodeFilterUI()
        case .eventDirectoryChanged:
            addDirectoryRegexUI()
        case .eventHostChanged:
            addHostRegexUI()
        case .eventUserChanged:
            addUserRegexUI()
        case .eventIdle, .eventActivityAfterIdle:
            addTimeoutUI()
        case .eventLongRunningCommand:
            addLongRunningCommandUI()
        case .eventCustomEscapeSequence:
            addSequenceIdUI()
        case .eventNotificationPosted:
            addNotificationMessageRegexUI()
        case .eventProgressBarChanged:
            addProgressBarFilterUI()
        case .eventJobStarted, .eventJobEnded:
            addJobNameUI()
        case .eventVariableChanged:
            addVariableChangedUI()
        default:
            // No parameters needed for other event types
            addNoParametersLabel()
        }

        // Tell the layout system our size changed
        invalidateIntrinsicContentSize()
        superview?.needsLayout = true
    }

    // MARK: - UI Construction

    private func addExitCodeFilterUI() {
        let row = createRow(label: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.exit_code.115a0020", defaultValue: "Exit Code:", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))

        let popup = NSPopUpButton()
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.addItems(withTitles: [String(localized: "ui.swift.triggers.itermeventtriggerparameterview.any.2b505597", defaultValue: "Any", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."), String(localized: "ui.swift.triggers.itermeventtriggerparameterview.zero_success.b3562491", defaultValue: "Zero (Success)", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."), String(localized: "ui.swift.triggers.itermeventtriggerparameterview.non_zero_failure.10dd442f", defaultValue: "Non-Zero (Failure)", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."), String(localized: "ui.swift.triggers.itermeventtriggerparameterview.specific_value.50cd3ec5", defaultValue: "Specific Value…", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")])
        popup.target = self
        popup.action = #selector(exitCodeFilterChanged(_:))
        exitCodeFilterPopup = popup

        let textField = NSTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholderString = String(localized: "ui.swift.triggers.itermeventtriggerparameterview.exit_code.ccc6eb1c", defaultValue: "Exit code", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        textField.isHidden = true
        textField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        textField.delegate = self
        textField.formatter = iTermSaneNumberFormatter()
        exitCodeTextField = textField

        row.addArrangedSubview(popup)
        row.addArrangedSubview(textField)
        stackView.addArrangedSubview(row)
    }

    private func addJobNameUI() {
        let row = createRow(label: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.job.34b0e24b", defaultValue: "Job:", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))

        let textField = NSTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholderString = "claude"
        textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        textField.delegate = self
        jobNameTextField = textField

        row.addArrangedSubview(textField)
        stackView.addArrangedSubview(row)

        let helpLabel = NSTextField(labelWithString: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.process_name_to_match_in_the_foreground_job.32753a43", defaultValue: "Process name to match in the foreground-job ancestry chain (case-insensitive)", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        helpLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        helpLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(helpLabel)
    }

    private func addVariableChangedUI() {
        // Variable name row (with completion).
        let nameRow = createRow(label: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.variable.d61edd88", defaultValue: "Variable:", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))

        let nameField = NSTextField()
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.placeholderString = "user.myVar"
        nameField.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        nameField.delegate = self
        variableNameTextField = nameField

        nameRow.addArrangedSubview(nameField)
        stackView.addArrangedSubview(nameRow)

        let nameHelp = NSTextField(labelWithString: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.name_of_the_session_variable_to_watch.e897d8f2", defaultValue: "Name of the session variable to watch", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))
        nameHelp.translatesAutoresizingMaskIntoConstraints = false
        nameHelp.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        nameHelp.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(nameHelp)

        // Value regex row.
        let valueRow = createRow(label: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.value.224a3369", defaultValue: "Value:", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))

        let valueField = NSTextField()
        valueField.translatesAutoresizingMaskIntoConstraints = false
        valueField.placeholderString = ".*"
        valueField.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        valueField.delegate = self
        variableValueRegexTextField = valueField

        valueRow.addArrangedSubview(valueField)
        stackView.addArrangedSubview(valueRow)

        let valueHelp = NSTextField(labelWithString: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.regular_expression_the_new_value_must_match_leave.8dec65a7", defaultValue: "Regular expression the new value must match (leave blank to match any change)", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))
        valueHelp.translatesAutoresizingMaskIntoConstraints = false
        valueHelp.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        valueHelp.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(valueHelp)
    }

    private func addDirectoryRegexUI() {
        let row = createRow(label: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.directory.8b948460", defaultValue: "Directory:", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))

        let textField = NSTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholderString = ".*"
        textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        textField.delegate = self
        directoryRegexTextField = textField

        row.addArrangedSubview(textField)
        stackView.addArrangedSubview(row)

        let helpLabel = NSTextField(labelWithString: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.regular_expression_to_match_the_directory_path.32b3ad05", defaultValue: "Regular expression to match the directory path", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        helpLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        helpLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(helpLabel)
    }

    private func addTimeoutUI() {
        let row = createRow(label: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.timeout.3cfe9e96", defaultValue: "Timeout:", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))

        let textField = NSTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholderString = "30"
        textField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        textField.delegate = self
        textField.formatter = iTermSaneNumberFormatter()
        timeoutTextField = textField

        let unitsLabel = NSTextField(labelWithString: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.seconds.59f006d6", defaultValue: "seconds", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))
        unitsLabel.translatesAutoresizingMaskIntoConstraints = false

        row.addArrangedSubview(textField)
        row.addArrangedSubview(unitsLabel)
        stackView.addArrangedSubview(row)
    }

    private func addSequenceIdUI() {
        let row = createRow(label: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.sequence_id.e89d2160", defaultValue: "Sequence ID:", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))

        let textField = NSTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholderString = ".*"
        textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        textField.delegate = self
        sequenceIdTextField = textField

        row.addArrangedSubview(textField)
        stackView.addArrangedSubview(row)

        let helpLabel = NSTextField(labelWithString: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.regular_expression_to_match_the_sequence_identifier.84f8cf6e", defaultValue: "Regular expression to match the sequence identifier", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        helpLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        helpLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(helpLabel)
    }

    private func addNotificationMessageRegexUI() {
        let row = createRow(label: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.message.f5394f72", defaultValue: "Message:", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))

        let textField = NSTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholderString = ".*"
        textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        textField.delegate = self
        notificationMessageRegexTextField = textField

        row.addArrangedSubview(textField)
        stackView.addArrangedSubview(row)

        let helpLabel = NSTextField(labelWithString: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.regular_expression_to_match_the_notification_message.1c9554a2", defaultValue: "Regular expression to match the notification message", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        helpLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        helpLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(helpLabel)
    }

    private func addHostRegexUI() {
        let row = createRow(label: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.host.95695f07", defaultValue: "Host:", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))

        let textField = NSTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholderString = ".*"
        textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        textField.delegate = self
        hostRegexTextField = textField

        row.addArrangedSubview(textField)
        stackView.addArrangedSubview(row)

        let helpLabel = NSTextField(labelWithString: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.regular_expression_to_match_the_hostname.87317704", defaultValue: "Regular expression to match the hostname", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        helpLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        helpLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(helpLabel)
    }

    private func addUserRegexUI() {
        let row = createRow(label: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.user.93d6b3e9", defaultValue: "User:", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))

        let textField = NSTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholderString = ".*"
        textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        textField.delegate = self
        userRegexTextField = textField

        row.addArrangedSubview(textField)
        stackView.addArrangedSubview(row)

        let helpLabel = NSTextField(labelWithString: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.regular_expression_to_match_the_username.4bede70c", defaultValue: "Regular expression to match the username", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        helpLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        helpLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(helpLabel)
    }

    private func addLongRunningCommandUI() {
        // Threshold row
        let thresholdRow = createRow(label: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.threshold.fdc8fae6", defaultValue: "Threshold:", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))

        let thresholdField = NSTextField()
        thresholdField.translatesAutoresizingMaskIntoConstraints = false
        thresholdField.placeholderString = "60"
        thresholdField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        thresholdField.delegate = self
        thresholdField.formatter = iTermSaneNumberFormatter()
        thresholdTextField = thresholdField

        let unitsLabel = NSTextField(labelWithString: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.seconds.59f006d6", defaultValue: "seconds", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))
        unitsLabel.translatesAutoresizingMaskIntoConstraints = false

        thresholdRow.addArrangedSubview(thresholdField)
        thresholdRow.addArrangedSubview(unitsLabel)
        stackView.addArrangedSubview(thresholdRow)

        // Command regex row
        let commandRow = createRow(label: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.command.a7a9c915", defaultValue: "Command:", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))

        let commandField = NSTextField()
        commandField.translatesAutoresizingMaskIntoConstraints = false
        commandField.placeholderString = ".*"
        commandField.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        commandField.delegate = self
        commandRegexTextField = commandField

        commandRow.addArrangedSubview(commandField)
        stackView.addArrangedSubview(commandRow)

        let helpLabel = NSTextField(labelWithString: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.regular_expression_to_match_the_command_line.5ce3c752", defaultValue: "Regular expression to match the command line", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        helpLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        helpLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(helpLabel)
    }

    private func addProgressBarFilterUI() {
        let row = createRow(label: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.fire_when.27d787ae", defaultValue: "Fire When:", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))

        let popup = NSPopUpButton()
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.addItems(withTitles: [String(localized: "ui.swift.triggers.itermeventtriggerparameterview.appears_or_disappears.a2b9cf44", defaultValue: "Appears or Disappears", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."), String(localized: "ui.swift.triggers.itermeventtriggerparameterview.appears.6fdf019c", defaultValue: "Appears", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."), String(localized: "ui.swift.triggers.itermeventtriggerparameterview.disappears.72d4b91c", defaultValue: "Disappears", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")])
        popup.target = self
        popup.action = #selector(progressBarFilterChanged(_:))
        progressBarFilterPopup = popup

        row.addArrangedSubview(popup)
        stackView.addArrangedSubview(row)
    }

    private func addNoParametersLabel() {
        let label = NSTextField(labelWithString: String(localized: "ui.swift.triggers.itermeventtriggerparameterview.no_additional_parameters_required.23b42202", defaultValue: "No additional parameters required.", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView."))
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(label)
    }

    private func createRow(label: String) -> NSStackView {
        let row = NSStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 6

        let labelView = NSTextField(labelWithString: label)
        labelView.translatesAutoresizingMaskIntoConstraints = false
        labelView.widthAnchor.constraint(equalToConstant: 80).isActive = true
        labelView.alignment = .right
        row.addArrangedSubview(labelView)

        return row
    }

    // MARK: - Actions

    @objc private func exitCodeFilterChanged(_ sender: NSPopUpButton) {
        let isSpecific = sender.indexOfSelectedItem == 3
        exitCodeTextField?.isHidden = !isSpecific
        onParametersChanged?()
    }

    @objc private func progressBarFilterChanged(_ sender: NSPopUpButton) {
        onParametersChanged?()
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        // Filter non-digit characters from numeric fields
        if let textField = obj.object as? NSTextField {
            if textField === exitCodeTextField ||
               textField === timeoutTextField ||
               textField === thresholdTextField {
                let digitsOnly = textField.stringValue.filter { $0.isNumber }
                if digitsOnly != textField.stringValue {
                    textField.stringValue = digitsOnly
                }
            } else if textField === variableNameTextField,
                      let fieldEditor = obj.userInfo?["NSFieldEditor"] as? NSTextView {
                // Offer variable-name completions as the user types, but not
                // while deleting (it's disruptive to re-suggest on backspace).
                if !isAutocompleting && !suppressAutocomplete {
                    isAutocompleting = true
                    fieldEditor.complete(nil)
                    isAutocompleting = false
                }
                suppressAutocomplete = false
            }
        }
        onParametersChanged?()
    }

    func control(_ control: NSControl,
                 textView: NSTextView,
                 completions words: [String],
                 forPartialWordRange charRange: NSRange,
                 indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String] {
        guard control === variableNameTextField else {
            return words
        }
        // Don't preselect; preselection causes pathological behavior when
        // typing a period.
        index.pointee = -1

        let full = textView.string as NSString
        // We can't sensibly complete in the middle of the value.
        guard NSMaxRange(charRange) == full.length else {
            return []
        }
        // pathSource wants the full path typed so far (including any leading
        // components like "user."), not just the partial word after the last
        // dot, which is what charRange covers.
        let typed = full.substring(to: NSMaxRange(charRange))
        let matches = variablePathSource(typed)
        let completions = matches.map { (path: String) -> String in
            (path as NSString).substring(from: charRange.location)
        }
        return completions.sorted()
    }

    func control(_ control: NSControl,
                 textView: NSTextView,
                 doCommandBy commandSelector: Selector) -> Bool {
        if control === variableNameTextField &&
            (commandSelector == #selector(NSResponder.deleteBackward(_:)) ||
             commandSelector == #selector(NSResponder.deleteForward(_:)) ||
             commandSelector == #selector(NSResponder.deleteWordBackward(_:)) ||
             commandSelector == #selector(NSResponder.deleteWordForward(_:))) {
            suppressAutocomplete = true
        }
        return false
    }

    // MARK: - Parameter Collection

    private func collectParams() -> [String: Any] {
        var params: [String: Any] = [:]

        switch currentMatchType {
        case .eventCommandFinished:
            if let popup = exitCodeFilterPopup {
                switch popup.indexOfSelectedItem {
                case 0:
                    params["exitCodeFilter"] = "*"
                case 1:
                    params["exitCodeFilter"] = "0"
                case 2:
                    params["exitCodeFilter"] = "!0"
                case 3:
                    params["exitCodeFilter"] = exitCodeTextField?.stringValue ?? "*"
                default:
                    params["exitCodeFilter"] = "*"
                }
            }

        case .eventIdle, .eventActivityAfterIdle:
            if let text = timeoutTextField?.stringValue, let timeout = Double(text) {
                params["timeout"] = NSNumber(value: timeout)
            } else {
                params["timeout"] = NSNumber(value: 30.0)
            }

        case .eventLongRunningCommand:
            if let text = thresholdTextField?.stringValue, let threshold = Double(text) {
                params["threshold"] = NSNumber(value: threshold)
            } else {
                params["threshold"] = NSNumber(value: 60.0)
            }
            let commandRegex = commandRegexTextField?.stringValue ?? ""
            if !commandRegex.isEmpty {
                params["commandRegex"] = commandRegex
            }

        case .eventCustomEscapeSequence:
            params["sequenceId"] = sequenceIdTextField?.stringValue ?? ""

        case .eventNotificationPosted:
            let regex = notificationMessageRegexTextField?.stringValue ?? ""
            if !regex.isEmpty {
                params["messageRegex"] = regex
            }

        case .eventDirectoryChanged:
            let regex = directoryRegexTextField?.stringValue ?? ""
            if !regex.isEmpty {
                params["directoryRegex"] = regex
            }

        case .eventHostChanged:
            let regex = hostRegexTextField?.stringValue ?? ""
            if !regex.isEmpty {
                params["hostRegex"] = regex
            }

        case .eventUserChanged:
            let regex = userRegexTextField?.stringValue ?? ""
            if !regex.isEmpty {
                params["userRegex"] = regex
            }

        case .eventProgressBarChanged:
            if let popup = progressBarFilterPopup {
                switch popup.indexOfSelectedItem {
                case 0:
                    params["progressBarFilter"] = "*"
                case 1:
                    params["progressBarFilter"] = "appeared"
                case 2:
                    params["progressBarFilter"] = "disappeared"
                default:
                    params["progressBarFilter"] = "*"
                }
            }

        case .eventJobStarted, .eventJobEnded:
            let jobName = jobNameTextField?.stringValue ?? ""
            if !jobName.isEmpty {
                params["jobName"] = jobName
            }

        case .eventVariableChanged:
            let variableName = variableNameTextField?.stringValue ?? ""
            if !variableName.isEmpty {
                params[kTriggerVariableNameKey] = variableName
            }
            let valueRegex = variableValueRegexTextField?.stringValue ?? ""
            if !valueRegex.isEmpty {
                params[kTriggerVariableValueRegexKey] = valueRegex
            }

        default:
            break
        }

        return params
    }

    private func applyParams(_ params: [String: Any]) {
        switch currentMatchType {
        case .eventCommandFinished:
            if let filter = params["exitCodeFilter"] as? String {
                switch filter {
                case "*", "":
                    exitCodeFilterPopup?.selectItem(at: 0)
                    exitCodeTextField?.isHidden = true
                case "0":
                    exitCodeFilterPopup?.selectItem(at: 1)
                    exitCodeTextField?.isHidden = true
                case "!0":
                    exitCodeFilterPopup?.selectItem(at: 2)
                    exitCodeTextField?.isHidden = true
                default:
                    exitCodeFilterPopup?.selectItem(at: 3)
                    exitCodeTextField?.stringValue = filter
                    exitCodeTextField?.isHidden = false
                }
            }

        case .eventIdle, .eventActivityAfterIdle:
            if let timeout = params["timeout"] as? NSNumber {
                timeoutTextField?.stringValue = "\(timeout.intValue)"
            }

        case .eventLongRunningCommand:
            if let threshold = params["threshold"] as? NSNumber {
                thresholdTextField?.stringValue = "\(threshold.intValue)"
            }
            if let regex = params["commandRegex"] as? String {
                commandRegexTextField?.stringValue = regex
            }

        case .eventCustomEscapeSequence:
            if let sequenceId = params["sequenceId"] as? String {
                sequenceIdTextField?.stringValue = sequenceId
            }

        case .eventNotificationPosted:
            if let regex = params["messageRegex"] as? String {
                notificationMessageRegexTextField?.stringValue = regex
            }

        case .eventDirectoryChanged:
            if let regex = params["directoryRegex"] as? String {
                directoryRegexTextField?.stringValue = regex
            }

        case .eventHostChanged:
            if let regex = params["hostRegex"] as? String {
                hostRegexTextField?.stringValue = regex
            }

        case .eventUserChanged:
            if let regex = params["userRegex"] as? String {
                userRegexTextField?.stringValue = regex
            }

        case .eventProgressBarChanged:
            if let filter = params["progressBarFilter"] as? String {
                switch filter {
                case "*", "":
                    progressBarFilterPopup?.selectItem(at: 0)
                case "appeared":
                    progressBarFilterPopup?.selectItem(at: 1)
                case "disappeared":
                    progressBarFilterPopup?.selectItem(at: 2)
                default:
                    progressBarFilterPopup?.selectItem(at: 0)
                }
            }

        case .eventJobStarted, .eventJobEnded:
            if let jobName = params["jobName"] as? String {
                jobNameTextField?.stringValue = jobName
            }

        case .eventVariableChanged:
            if let variableName = params[kTriggerVariableNameKey] as? String {
                variableNameTextField?.stringValue = variableName
            }
            if let valueRegex = params[kTriggerVariableValueRegexKey] as? String {
                variableValueRegexTextField?.stringValue = valueRegex
            }

        default:
            break
        }
    }
}

// MARK: - Event Type Display Names

@objc(iTermEventTriggerMatchTypeHelper)
class EventTriggerMatchTypeHelper: NSObject {

    /// Get a human-readable name for an event match type
    @objc static func displayName(for matchType: iTermTriggerMatchType) -> String {
        switch matchType {
        case .eventPromptDetected:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.prompt_detected.138fc2a1", defaultValue: "Prompt Detected", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventCommandFinished:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.command_finished.ec70c38b", defaultValue: "Command Finished", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventDirectoryChanged:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.directory_changed.dde8d641", defaultValue: "Directory Changed", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventHostChanged:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.host_changed.904360b2", defaultValue: "Host Changed", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventUserChanged:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.user_changed.00481517", defaultValue: "User Changed", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventIdle:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.idle_silence.50ca45f7", defaultValue: "Idle (Silence)", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventActivityAfterIdle:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.activity_after_idle.285e5198", defaultValue: "Activity After Idle", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventSessionEnded:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.session_ended.3387d3e8", defaultValue: "Session Ended", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventBellReceived:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.bell_received.bb3440c2", defaultValue: "Bell Received", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventLongRunningCommand:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.long_running_command.b943caf4", defaultValue: "Long-Running Command", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventCustomEscapeSequence:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.custom_escape_sequence.07884d74", defaultValue: "Custom Escape Sequence", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventNotificationPosted:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.notification_posted.594c15bc", defaultValue: "Notification Posted", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventProgressBarChanged:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.progress_bar_changed.467f513d", defaultValue: "Progress Bar Changed", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventJobStarted:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.job_started.8d5b30de", defaultValue: "Job Started", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventJobEnded:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.job_ended.0fb54d33", defaultValue: "Job Ended", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventVariableChanged:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.variable_changed.951f8324", defaultValue: "Variable Changed", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        default:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.unknown_event.2078f36c", defaultValue: "Unknown Event", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        }
    }

    /// Get a description/help text for an event match type
    @objc static func helpText(for matchType: iTermTriggerMatchType) -> String {
        switch matchType {
        case .eventPromptDetected:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.fires_when_shell_integration_detects_a_new_prompt.d5c88fa8", defaultValue: "Fires when shell integration detects a new prompt.", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventCommandFinished:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.fires_when_a_command_exits_requires_shell_integration.5038c8ac", defaultValue: "Fires when a command exits. Requires shell integration.", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventDirectoryChanged:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.fires_when_the_working_directory_changes.13587c9e", defaultValue: "Fires when the working directory changes.", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventHostChanged:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.fires_when_connecting_to_a_different_host_via.77af4932", defaultValue: "Fires when connecting to a different host via SSH.", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventUserChanged:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.fires_when_the_current_user_changes_su_sudo.e69b83a4", defaultValue: "Fires when the current user changes (su/sudo).", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventIdle:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.fires_when_no_output_is_received_for_the.64d92d1b", defaultValue: "Fires when no output is received for the specified duration.", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventActivityAfterIdle:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.fires_when_output_resumes_after_being_idle.3be03ffc", defaultValue: "Fires when output resumes after being idle.", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventSessionEnded:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.fires_when_the_session_terminates.7f06f1a7", defaultValue: "Fires when the session terminates.", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventBellReceived:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.fires_when_a_terminal_bell_a_is_received.1ba063a4", defaultValue: "Fires when a terminal bell (\\a) is received.", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventLongRunningCommand:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.fires_when_a_command_runs_longer_than_the.1012696d", defaultValue: "Fires when a command runs longer than the threshold.", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventCustomEscapeSequence:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.fires_when_a_specific_osc_escape_sequence_is.3f7a9dcb", defaultValue: "Fires when a specific OSC escape sequence is received.", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventNotificationPosted:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.fires_when_a_notification_is_posted_by_a.1f02e308", defaultValue: "Fires when a notification is posted by a control sequence (OSC 9).", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventProgressBarChanged:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.fires_when_a_progress_bar_appears_or_disappears.ce9a2f74", defaultValue: "Fires when a progress bar appears or disappears.", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventJobStarted:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.fires_when_a_process_matching_the_job_filter.940f387c", defaultValue: "Fires when a process matching the job filter enters the foreground-job ancestry chain.", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventJobEnded:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.fires_when_a_process_matching_the_job_filter.e2f9508c", defaultValue: "Fires when a process matching the job filter leaves the foreground-job ancestry chain.", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        case .eventVariableChanged:
            return String(localized: "ui.swift.triggers.itermeventtriggerparameterview.fires_when_a_session_variable_changes_to_a.6759573b", defaultValue: "Fires when a session variable changes to a value matching the regex.", bundle: .main, comment: "User-facing text in iTermEventTriggerParameterView.")
        default:
            return ""
        }
    }

    /// Get all event match types
    @objc static var allEventTypes: [NSNumber] {
        return [
            NSNumber(value: iTermTriggerMatchType.eventPromptDetected.rawValue),
            NSNumber(value: iTermTriggerMatchType.eventCommandFinished.rawValue),
            NSNumber(value: iTermTriggerMatchType.eventDirectoryChanged.rawValue),
            NSNumber(value: iTermTriggerMatchType.eventHostChanged.rawValue),
            NSNumber(value: iTermTriggerMatchType.eventUserChanged.rawValue),
            NSNumber(value: iTermTriggerMatchType.eventIdle.rawValue),
            NSNumber(value: iTermTriggerMatchType.eventActivityAfterIdle.rawValue),
            NSNumber(value: iTermTriggerMatchType.eventSessionEnded.rawValue),
            NSNumber(value: iTermTriggerMatchType.eventBellReceived.rawValue),
            NSNumber(value: iTermTriggerMatchType.eventLongRunningCommand.rawValue),
            NSNumber(value: iTermTriggerMatchType.eventCustomEscapeSequence.rawValue),
            NSNumber(value: iTermTriggerMatchType.eventNotificationPosted.rawValue),
            NSNumber(value: iTermTriggerMatchType.eventProgressBarChanged.rawValue),
            NSNumber(value: iTermTriggerMatchType.eventJobStarted.rawValue),
            NSNumber(value: iTermTriggerMatchType.eventJobEnded.rawValue),
            NSNumber(value: iTermTriggerMatchType.eventVariableChanged.rawValue)
        ]
    }

    /// Get all event match types except session ended (for triggers that need a live session)
    @objc static var allEventTypesExceptSessionEnded: [NSNumber] {
        let sessionEndedValue = NSNumber(value: iTermTriggerMatchType.eventSessionEnded.rawValue)
        return allEventTypes.filter { $0 != sessionEndedValue }
    }

    /// Get the set of all event match types as NSSet<NSNumber *>
    @objc static var allEventTypesSet: Set<NSNumber> {
        return Set(allEventTypes)
    }

    /// Get the set of all event match types except session ended as NSSet<NSNumber *>
    @objc static var allEventTypesExceptSessionEndedSet: Set<NSNumber> {
        return Set(allEventTypesExceptSessionEnded)
    }
}
