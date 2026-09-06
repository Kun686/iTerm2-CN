//
//  RemoteCommand.swift
//  iTerm2
//
//  Created by George Nachman on 8/18/25.
//
//  NOTE: This file is also compiled into the iTerm2 Companion iOS app. Keep it
//  platform-neutral (Foundation only); Mac-only code (safety checks,
//  preferences) lives in RemoteCommand+Mac.swift.
//

import Foundation

// External orchestration commands persist an English description for the
// model-facing safety transcript. Their user-facing description is rebuilt
// from the stable tool name and JSON arguments so it follows the current app
// language without changing the Codable shape.
enum ExternalRemoteCommandDescriptionFormatter {
    private struct Localization {
        let lookup: (_ key: String, _ defaultValue: String) -> String

        func localizedString(forKey key: String, defaultValue: String) -> String {
            lookup(key, defaultValue)
        }

        func formattedString(
            forKey key: String,
            defaultValue: String,
            _ arguments: CVarArg...
        ) -> String {
            String(format: localizedString(forKey: key, defaultValue: defaultValue),
                   arguments: arguments)
        }
    }

    static func localizedDescription(
        forToolName name: String,
        argsJSON: String,
        bundle: Bundle = .main
    ) -> String {
        description(
            forToolName: name,
            argsJSON: argsJSON,
            localizedString: { key, defaultValue in
                bundle.localizedString(forKey: key, value: defaultValue, table: nil)
            })
    }

    static func localizedDescription(
        forToolName name: String,
        args: [String: Any],
        bundle: Bundle = .main
    ) -> String {
        description(
            forToolName: name,
            args: args,
            localizedString: { key, defaultValue in
                bundle.localizedString(forKey: key, value: defaultValue, table: nil)
            })
    }

    static func englishDescription(forToolName name: String, argsJSON: String) -> String {
        description(
            forToolName: name,
            argsJSON: argsJSON,
            localizedString: { _, defaultValue in defaultValue })
    }

    static func englishDescription(forToolName name: String, args: [String: Any]) -> String {
        description(
            forToolName: name,
            args: args,
            localizedString: { _, defaultValue in defaultValue })
    }

    static func description(
        forToolName name: String,
        argsJSON: String,
        localizedString: @escaping (_ key: String, _ defaultValue: String) -> String
    ) -> String {
        let args: [String: Any]
        if let data = argsJSON.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data),
           let dictionary = object as? [String: Any] {
            args = dictionary
        } else {
            args = [:]
        }
        return description(forToolName: name,
                           args: args,
                           localizedString: localizedString)
    }

    static func description(
        forToolName name: String,
        args: [String: Any],
        localizedString: @escaping (_ key: String, _ defaultValue: String) -> String
    ) -> String {
        let localization = Localization(lookup: localizedString)
        switch name {
        case "list_workgroups":
            return localization.localizedString(
                forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.looking_up_workgroups.930498ff",
                defaultValue: "Looking up workgroups")
        case "get_state":
            return localization.formattedString(
                forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.checking_state_of_0.63059e1b",
                defaultValue: "Checking state of %1$@",
                sessionDescription(args: args, localization: localization))
        case "get_screen_contents":
            return localization.formattedString(
                forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.reading_screen_of_0.fb4a73ae",
                defaultValue: "Reading screen of %1$@",
                sessionDescription(args: args, localization: localization))
        case "scroll_wheel":
            let direction = (args["direction"] as? String) ?? "up"
            let what = direction == "down"
                ? localization.localizedString(
                    forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.newer.804f51f7",
                    defaultValue: "newer")
                : localization.localizedString(
                    forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.older.da925a30",
                    defaultValue: "older")
            return localization.formattedString(
                forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.scrolling_0_to_show_1_content.eab18caf",
                defaultValue: "Scrolling %1$@ to show %2$@ content",
                sessionDescription(args: args, localization: localization),
                what)
        case "list_workgroup_clippings":
            return localization.formattedString(
                forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.listing_clippings_in_0.418753eb",
                defaultValue: "Listing clippings in %1$@",
                workgroupDescription(args: args, localization: localization))
        case "send_text":
            let text = (args["text"] as? String) ?? ""
            return localization.formattedString(
                forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.typing_into_0_1.3d52c225",
                defaultValue: "Typing into %1$@: %2$@",
                sessionDescription(args: args, localization: localization),
                previewQuote(text))
        case "interrupt":
            return localization.formattedString(
                forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.interrupting_0.d434f515",
                defaultValue: "Interrupting %1$@",
                sessionDescription(args: args, localization: localization))
        case "add_workgroup_clipping":
            let title = (args["title"] as? String)
                ?? localization.localizedString(
                    forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.untitled.3bc7cc17",
                    defaultValue: "(untitled)")
            return localization.formattedString(
                forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.posting_clipping_0_to_1.7579d373",
                defaultValue: "Posting clipping “%1$@” to %2$@",
                title,
                workgroupDescription(args: args, localization: localization))
        case "start_session":
            if let command = args["command"] as? String, !command.isEmpty {
                return localization.formattedString(
                    forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.starting_new_session_0.b9ce079f",
                    defaultValue: "Starting new session: `%1$@`",
                    command)
            }
            return localization.localizedString(
                forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.starting_new_session.8b5e32e7",
                defaultValue: "Starting new session")
        case "start_code_review":
            let promptLabel: String
            if let promptName = args["prompt_name"] as? String, !promptName.isEmpty {
                promptLabel = localization.formattedString(
                    forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.with_saved_prompt_0.c816d736",
                    defaultValue: "with saved prompt “%1$@”",
                    promptName)
            } else if let customPrompt = args["custom_prompt"] as? String,
                      !customPrompt.isEmpty {
                promptLabel = localization.formattedString(
                    forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.with_0.95c9673f",
                    defaultValue: "with %1$@",
                    previewQuote(customPrompt))
            } else {
                promptLabel = localization.localizedString(
                    forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.with_the_default_prompt.be81d06a",
                    defaultValue: "with the default prompt")
            }
            return localization.formattedString(
                forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.kicking_off_code_review_on_0_1.7f141f85",
                defaultValue: "Kicking off Code Review on %1$@ %2$@",
                sessionDescription(args: args, localization: localization),
                promptLabel)
        case "register_watch":
            let hasGuid = (args["session_guid"] as? String).map { !$0.isEmpty } ?? false
            let target = hasGuid
                ? sessionDescription(args: args, localization: localization)
                : localization.localizedString(
                    forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.the_linked_session.3b4126e8",
                    defaultValue: "the linked session")
            if let condition = args["condition"] as? String, !condition.isEmpty {
                return localization.formattedString(
                    forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.will_notify_when_0_satisfies_1.eef69685",
                    defaultValue: "Will notify when %1$@ satisfies: %2$@",
                    target,
                    previewQuote(condition))
            }
            let state = (args["target_state"] as? String) ?? "?"
            return localization.formattedString(
                forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.will_notify_when_0_becomes_1.47f8d0a7",
                defaultValue: "Will notify when %1$@ becomes **%2$@**",
                target,
                state)
        case "unregister_watch":
            return localization.localizedString(
                forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.cancelling_a_watch.d10417ee",
                defaultValue: "Cancelling a watch")
        case "list_watches":
            return localization.localizedString(
                forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.listing_active_watches.1100d660",
                defaultValue: "Listing active watches")
        default:
            guard name.hasPrefix("session_") else {
                return prettifyToolName(name)
            }
            let raw = String(name.dropFirst("session_".count))
            if raw == "execute_command",
               let command = args["command"] as? String,
               !command.isEmpty {
                return localization.formattedString(
                    forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.executing_0.55882296",
                    defaultValue: "Executing `%1$@`",
                    command.escapedForMarkdownCode.truncatedWithTrailingEllipsis(to: 80))
            }
            return localization.formattedString(
                forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.0_in_1.f789d5d1",
                defaultValue: "%1$@ in %2$@",
                prettifyToolName(raw),
                sessionDescription(args: args, localization: localization))
        }
    }

    private static func prettifyToolName(_ name: String) -> String {
        let words = name.split(separator: "_").map(String.init)
        guard let first = words.first else { return name }
        let capitalized = first.prefix(1).uppercased() + first.dropFirst()
        return ([capitalized] + words.dropFirst()).joined(separator: " ")
    }

    private static func sessionDescription(
        args: [String: Any],
        localization: Localization
    ) -> String {
        guard let guid = args["session_guid"] as? String, !guid.isEmpty else {
            return localization.localizedString(
                forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.unknown_session.9a60b8e6",
                defaultValue: "_(unknown session)_")
        }
        return "@\(guid)"
    }

    private static func workgroupDescription(
        args: [String: Any],
        localization: Localization
    ) -> String {
        guard let workgroup = args["workgroup_id"] as? String, !workgroup.isEmpty else {
            return localization.localizedString(
                forKey: "ui.swift.claudecode.orchestration.orchestrationtoolprovider.unknown_workgroup.5bad03b6",
                defaultValue: "_unknown workgroup_")
        }
        return "@\(workgroup)"
    }

    private static func previewQuote(_ text: String) -> String {
        let oneLine = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        let maxLength = 80
        let snippet = oneLine.count <= maxLength
            ? oneLine
            : String(oneLine.prefix(maxLength)) + "…"
        return "“\(snippet)”"
    }
}

// Generic wrapper around "a remote command the LLM wants to run".
// Two flavors:
//   - .classic: session-bound mode's typed RemoteCommand. Its Content
//     enum drives permission checks, safety classification, markdown
//     rendering, and the per-tool argument shape known at compile time.
//   - .external: any other stack's tool call (today: the orchestration
//     mode's tool surface). Args travel as opaque JSON. Renders via
//     the wrapper's markdownDescription.
//
// Codable shape:
//   - .classic encodes as a bare RemoteCommand (no envelope) so existing
//     chat databases round-trip without migration.
//   - .external encodes with a "kind": "external" discriminator on the
//     same object level; init(from:) checks for it and routes
//     accordingly, falling back to the legacy classic shape.
enum RemoteCommandPayload {
    case classic(RemoteCommand)
    case external(ExternalRemoteCommand)

    var llmMessage: LLM.Message {
        switch self {
        case .classic(let rc): rc.llmMessage
        case .external(let ext): ext.llmMessage
        }
    }

    // Tool name as the LLM sees it. For .classic this is the typed
    // Content's functionName; for .external it's whatever the
    // orchestrator's tool definition registered.
    var name: String {
        switch self {
        case .classic(let rc): rc.content.functionName
        case .external(let ext): ext.name
        }
    }

    var markdownDescription: String {
        switch self {
        case .classic(let rc): rc.markdownDescription
        case .external(let ext): ext.displayMarkdownDescription
        }
    }

    // This text is sent to the safety model as part of its transcript. Keep it
    // independent of the app's display language so localization cannot alter
    // model-facing content or safety behavior.
    var safetyTranscriptDescription: String {
        switch self {
        case .classic(let rc): rc.safetyTranscriptDescription
        case .external(let ext): ext.markdownDescription
        }
    }

    // Convenience for AITerm-side readers that need typed Content
    // access (safety check, permission category, etc.). Returns nil
    // for external payloads — readers that don't have a sensible
    // fallback should treat that as "skip this message".
    var classic: RemoteCommand? {
        if case .classic(let rc) = self { return rc }
        return nil
    }
}

struct ExternalRemoteCommand: Codable {
    // Discriminator. Always "external"; used by RemoteCommandPayload's
    // custom decoder to tell this shape apart from a bare RemoteCommand.
    var kind: String = "external"
    var llmMessage: LLM.Message
    var name: String
    var argsJSON: String
    // Persisted, stable English. This field is part of the existing wire and
    // database shape and is used only for model-facing or diagnostic text.
    var markdownDescription: String

    var displayMarkdownDescription: String {
        ExternalRemoteCommandDescriptionFormatter.localizedDescription(
            forToolName: name,
            argsJSON: argsJSON)
    }
}

extension RemoteCommandPayload: Codable {
    private enum DiscriminatorKey: String, CodingKey {
        case kind
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: DiscriminatorKey.self),
           let kind = try? container.decode(String.self, forKey: .kind),
           kind == "external" {
            let ext = try ExternalRemoteCommand(from: decoder)
            self = .external(ext)
            return
        }
        let rc = try RemoteCommand(from: decoder)
        self = .classic(rc)
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .classic(let rc):
            try rc.encode(to: encoder)
        case .external(let ext):
            try ext.encode(to: encoder)
        }
    }
}

struct RemoteCommand: Codable {
    struct IsAtPrompt: Codable {}
    struct ExecuteCommand: Codable { var command: String = "" }
    struct GetLastExitStatus: Codable {}

    struct GetCommandHistory: Codable { var limit: Int = 100 }
    struct GetLastCommand: Codable {}
    struct GetCommandBeforeCursor: Codable {}
    struct SearchCommandHistory: Codable { var query: String = "" }
    struct GetCommandOutput: Codable { var id: String = "" }
    struct GetScreenContents: Codable { var lines: Int = 0 }

    struct GetTerminalSize: Codable {}
    struct GetShellType: Codable {}
    struct DetectSSHSession: Codable {}
    struct GetRemoteHostname: Codable {}
    struct GetUserIdentity: Codable {}
    struct GetCurrentDirectory: Codable {}

    struct SetClipboard: Codable { var text: String = "" }
    struct InsertTextAtCursor: Codable { var text: String = "" }
    struct DeleteCurrentLine: Codable {}
    struct GetManPage: Codable { var cmd: String = "" }
    struct CreateFile: Codable {
        var filename: String=""
        var content: String=""
    }
    struct SearchBrowser: Codable { var query: String = "" }
    struct LoadURL: Codable { var url: String = "" }
    struct WebSearch: Codable { var query: String = "" }
    struct GetURL: Codable {}
    struct ReadWebPage: Codable {
        var startingLineNumber: Int = 0
        var numberOfLines: Int = 0
    }
    struct RestartSession: Codable {}
    enum Content: Codable, CaseIterable {
        static var allCases: [RemoteCommand.Content] {
            return [.isAtPrompt(IsAtPrompt()),
                    .executeCommand(ExecuteCommand()),
                    .getLastExitStatus(GetLastExitStatus()),
                    .getCommandHistory(GetCommandHistory()),
                    .getLastCommand(GetLastCommand()),
                    .getCommandBeforeCursor(GetCommandBeforeCursor()),
                    .searchCommandHistory(SearchCommandHistory()),
                    .getCommandOutput(GetCommandOutput()),
                    .getScreenContents(GetScreenContents()),
                    .getTerminalSize(GetTerminalSize()),
                    .getShellType(GetShellType()),
                    .detectSSHSession(DetectSSHSession()),
                    .getRemoteHostname(GetRemoteHostname()),
                    .getUserIdentity(GetUserIdentity()),
                    .getCurrentDirectory(GetCurrentDirectory()),
                    .setClipboard(SetClipboard()),
                    .insertTextAtCursor(InsertTextAtCursor()),
                    .deleteCurrentLine(DeleteCurrentLine()),
                    .getManPage(GetManPage()),
                    .createFile(CreateFile()),
                    .searchBrowser(SearchBrowser()),
                    .loadURL(LoadURL()),
                    .webSearch(WebSearch()),
                    .getURL(GetURL()),
                    .readWebPage(ReadWebPage()),
                    .restartSession(RestartSession())
            ]
        }

        case isAtPrompt(IsAtPrompt)
        case executeCommand(ExecuteCommand)
        case getLastExitStatus(GetLastExitStatus)
        case getCommandHistory(GetCommandHistory)
        case getLastCommand(GetLastCommand)
        case getCommandBeforeCursor(GetCommandBeforeCursor)
        case searchCommandHistory(SearchCommandHistory)
        case getCommandOutput(GetCommandOutput)
        case getScreenContents(GetScreenContents)
        case getTerminalSize(GetTerminalSize)
        case getShellType(GetShellType)
        case detectSSHSession(DetectSSHSession)
        case getRemoteHostname(GetRemoteHostname)
        case getUserIdentity(GetUserIdentity)
        case getCurrentDirectory(GetCurrentDirectory)
        case setClipboard(SetClipboard)
        case insertTextAtCursor(InsertTextAtCursor)
        case deleteCurrentLine(DeleteCurrentLine)
        case getManPage(GetManPage)
        case createFile(CreateFile)
        case searchBrowser(SearchBrowser)
        case loadURL(LoadURL)
        case webSearch(WebSearch)
        case getURL(GetURL)
        case readWebPage(ReadWebPage)
        case restartSession(RestartSession)
        // When adding a new command be sure to update allCases.

        enum PermissionCategory: String, Codable, CaseIterable {
            case checkTerminalState = "Check Terminal State"
            case runCommands = "Run Commands"
            case viewContents = "View Contents"
            case writeToClipboard = "Write to the Clipboard"
            case controlTerminal = "Control Terminal"
            case viewManpages = "View Manpages"
            case writeToFilesystem = "Write to the File System"
            case actInWebBrowser = "Act in Web Browser"

            // Persisted per-chat permissions encode the category by rawValue, and the
            // whole [Key: Permission] blob fails to decode if any single category is
            // unknown (losing every category's grant for that chat). "View History"
            // was renamed to "View Contents"; accept the legacy string so existing
            // grants survive the rename.
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                let raw = try container.decode(String.self)
                if raw == "View History" {
                    self = .viewContents
                    return
                }
                // "Type for You" was renamed to "Control Terminal"; accept the
                // legacy string so existing per-chat grants survive the rename.
                if raw == "Type for You" {
                    self = .controlTerminal
                    return
                }
                guard let value = PermissionCategory(rawValue: raw) else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Unknown permission category \(raw)")
                }
                self = value
            }

            var isBrowserSpecific: Bool {
                switch self {
                case .checkTerminalState, .runCommands, .viewContents, .writeToClipboard,
                        .controlTerminal, .viewManpages, .writeToFilesystem:
                    false
                case .actInWebBrowser:
                    true
                }
            }

            var localizedDisplayName: String {
                switch self {
                case .checkTerminalState:
                    String(localized: "ui.swift.aiterm.remotecommand.check_terminal_state.71aeb145", defaultValue: "Check Terminal State", bundle: .main, comment: "User-facing text in RemoteCommand.")
                case .runCommands:
                    String(localized: "ui.swift.aiterm.remotecommand.run_commands.19f26589", defaultValue: "Run Commands", bundle: .main, comment: "User-facing text in RemoteCommand.")
                case .viewContents:
                    String(localized: "ui.swift.aiterm.remotecommand.view_contents.e71a1882", defaultValue: "View Contents", bundle: .main, comment: "User-facing text in RemoteCommand.")
                case .writeToClipboard:
                    String(localized: "ui.swift.aiterm.remotecommand.write_to_the_clipboard.57ebfebe", defaultValue: "Write to the Clipboard", bundle: .main, comment: "User-facing text in RemoteCommand.")
                case .controlTerminal:
                    String(localized: "ui.swift.aiterm.remotecommand.control_terminal.ce3629c0", defaultValue: "Control Terminal", bundle: .main, comment: "User-facing text in RemoteCommand.")
                case .viewManpages:
                    String(localized: "ui.swift.aiterm.remotecommand.view_manpages.347c2b56", defaultValue: "View Manpages", bundle: .main, comment: "User-facing text in RemoteCommand.")
                case .writeToFilesystem:
                    String(localized: "ui.swift.aiterm.remotecommand.write_to_the_file_system.0e9e5390", defaultValue: "Write to the File System", bundle: .main, comment: "User-facing text in RemoteCommand.")
                case .actInWebBrowser:
                    String(localized: "ui.swift.aiterm.remotecommand.act_in_web_browser.b7b20534", defaultValue: "Act in Web Browser", bundle: .main, comment: "User-facing text in RemoteCommand.")
                }
            }

            var autopopulationTitle: String? {
                switch self {
                case .checkTerminalState:
                    String(localized: "ui.swift.aiterm.remotecommand.provide_terminal_state_automatically.432955e8", defaultValue: "Provide Terminal State Automatically", bundle: .main, comment: "User-facing text in RemoteCommand.")
                case .viewContents:
                    String(localized: "ui.swift.aiterm.remotecommand.provide_screen_contents_automatically.6698aebf", defaultValue: "Provide Screen Contents Automatically", bundle: .main, comment: "User-facing text in RemoteCommand.")
                case .runCommands, .writeToClipboard, .controlTerminal, .viewManpages,
                        .writeToFilesystem, .actInWebBrowser:
                    nil
                }
            }

            var autopopulationWarningText: String? {
                switch self {
                case .checkTerminalState:
                    String(localized: "ui.swift.aiterm.remotecommand.by_setting_this_permission_to_always_allow_terminal.9a2a1ecd", defaultValue: "By setting this permission to “Always Allow”, terminal state will be sent automatically on every message you send in this chat.\nThis includes:\n • The current or last command and its exit status\n •The window size\n • Your shell\n • The current working directory, username, and hostname.", bundle: .main, comment: "User-facing text in RemoteCommand.")
                case .viewContents:
                    String(localized: "ui.swift.aiterm.remotecommand.by_setting_this_permission_to_always_allow_the.054babf1", defaultValue: "By setting this permission to “Always Allow”, the current visible screen of your terminal session will be sent automatically on every message you send in this chat.", bundle: .main, comment: "User-facing text in RemoteCommand.")
                case .runCommands, .writeToClipboard, .controlTerminal, .viewManpages,
                        .writeToFilesystem, .actInWebBrowser:
                    nil
                }
            }

            var regularTitle: String {
                switch self {
                case .checkTerminalState:
                    String(localized: "ui.swift.aiterm.remotecommand.ai_can_check_terminal_state", defaultValue: "AI can Check Terminal State", bundle: .main, comment: "Permission menu item for checking terminal state.")
                case .runCommands:
                    String(localized: "ui.swift.aiterm.remotecommand.ai_can_run_commands", defaultValue: "AI can Run Commands", bundle: .main, comment: "Permission menu item for running commands.")
                case .viewContents:
                    String(localized: "ui.swift.aiterm.remotecommand.ai_can_view_contents", defaultValue: "AI can View Contents", bundle: .main, comment: "Permission menu item for viewing terminal contents.")
                case .writeToClipboard:
                    String(localized: "ui.swift.aiterm.remotecommand.ai_can_write_to_clipboard", defaultValue: "AI can Write to the Clipboard", bundle: .main, comment: "Permission menu item for writing to the clipboard.")
                case .controlTerminal:
                    String(localized: "ui.swift.aiterm.remotecommand.ai_can_control_terminal", defaultValue: "AI can Control Terminal", bundle: .main, comment: "Permission menu item for controlling the terminal.")
                case .viewManpages:
                    String(localized: "ui.swift.aiterm.remotecommand.ai_can_view_manpages", defaultValue: "AI can View Manpages", bundle: .main, comment: "Permission menu item for viewing manpages.")
                case .writeToFilesystem:
                    String(localized: "ui.swift.aiterm.remotecommand.ai_can_write_to_filesystem", defaultValue: "AI can Write to the File System", bundle: .main, comment: "Permission menu item for writing to the file system.")
                case .actInWebBrowser:
                    String(localized: "ui.swift.aiterm.remotecommand.ai_can_act_in_web_browser", defaultValue: "AI can Act in Web Browser", bundle: .main, comment: "Permission menu item for acting in the web browser.")
                }
            }

            var autopopulatedWhenAlways: Bool {
                switch self {
                case .checkTerminalState, .viewContents:
                    true
                case .runCommands, .writeToClipboard, .controlTerminal, .viewManpages,
                        .writeToFilesystem, .actInWebBrowser:
                    false
                }
            }

            // Whether "Provided automatically" also hides the on-request tools. Check
            // Terminal State does: its autopopulated state fully replaces the state
            // queries. View Contents does NOT: the autopopulated visible screen only
            // covers the current grid, while the history tools reach off-screen
            // content (command history, an earlier command's full output, the
            // partially-typed command), so they stay available on request.
            var suppressesOnRequestToolsWhenAlways: Bool {
                switch self {
                case .checkTerminalState:
                    true
                case .viewContents, .runCommands, .writeToClipboard, .controlTerminal,
                        .viewManpages, .writeToFilesystem, .actInWebBrowser:
                    false
                }
            }
        }

        var permissionCategory: PermissionCategory {
            switch self {
            case .isAtPrompt, .getLastExitStatus, .getTerminalSize, .getShellType,
                    .detectSSHSession, .getRemoteHostname, .getUserIdentity, .getCurrentDirectory:
                    .checkTerminalState
            case .executeCommand:
                    .runCommands
            case .getCommandHistory, .getLastCommand, .getCommandBeforeCursor,
                    .searchCommandHistory, .getCommandOutput, .getScreenContents:
                    .viewContents
            case .setClipboard:
                    .writeToClipboard
            case .insertTextAtCursor, .deleteCurrentLine, .restartSession:
                    .controlTerminal
            case .getManPage:
                    .viewManpages
            case .createFile:
                    .writeToFilesystem
            case .searchBrowser, .loadURL, .webSearch, .getURL, .readWebPage:
                    .actInWebBrowser
            }
        }

        var args: Any {
            switch self {
            case .isAtPrompt(let args): args
            case .executeCommand(let args): args
            case .getLastExitStatus(let args): args
            case .getCommandHistory(let args): args
            case .getLastCommand(let args): args
            case .getCommandBeforeCursor(let args): args
            case .searchCommandHistory(let args): args
            case .getCommandOutput(let args): args
            case .getScreenContents(let args): args
            case .getTerminalSize(let args): args
            case .getShellType(let args): args
            case .detectSSHSession(let args): args
            case .getRemoteHostname(let args): args
            case .getUserIdentity(let args): args
            case .getCurrentDirectory(let args): args
            case .setClipboard(let args): args
            case .insertTextAtCursor(let args): args
            case .deleteCurrentLine(let args): args
            case .getManPage(let args): args
            case .createFile(let args): args
            case .searchBrowser(let args): args
            case .loadURL(let args): args
            case .webSearch(let args): args
            case .getURL(let args): args
            case .readWebPage(let args): args
            case .restartSession(let args): args
            }
        }
    }


    var llmMessage: LLM.Message
    var content: Content

    var needsSafetyCheck: Bool {
        // NOTE: .createFile is deliberately NOT checked here. A session-bound
        // file write surfaces in the chat UI where the user sees it before it
        // lands. The ORCHESTRATOR, which runs autonomously, does classify its
        // own create_file (OrchestratorDispatcher.handleSessionToolCall). Don't
        // "fix" this asymmetry by flipping .createFile without also revisiting
        // that autonomy distinction.
        switch content {
        case .isAtPrompt, .getLastExitStatus, .getCommandHistory, .getLastCommand,
                .getCommandBeforeCursor, .searchCommandHistory, .getCommandOutput,
                .getScreenContents,
                .getTerminalSize, .getShellType, .detectSSHSession, .getRemoteHostname,
                .getUserIdentity, .getCurrentDirectory, .setClipboard,
                .deleteCurrentLine, .getManPage, .createFile, .searchBrowser,
                .loadURL, .webSearch, .getURL, .readWebPage, .insertTextAtCursor,
                .restartSession:
            return false
        case .executeCommand:
            return true
        }
    }

    var markdownDescription: String {
        switch content {
        case .isAtPrompt:
            String(localized: "ui.swift.aiterm.remotecommand.checking_if_you_re_at_a_shell_prompt.63c128fa", defaultValue: "Checking if you're at a shell prompt", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case let .executeCommand(args):
            String(localized: "ui.swift.aiterm.remotecommand.executing_0.55882296", defaultValue: "Executing `\(args.command.escapedForMarkdownCode.truncatedWithTrailingEllipsis(to: 32))`", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getLastExitStatus:
            String(localized: "ui.swift.aiterm.remotecommand.checking_the_exit_status_of_the_last_command.f19ec4f6", defaultValue: "Checking the exit status of the last command", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getCommandHistory:
            String(localized: "ui.swift.aiterm.remotecommand.reviewing_the_history_of_commands_you_have_run.9be3f1f7", defaultValue: "Reviewing the history of commands you have run in this session", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getLastCommand:
            String(localized: "ui.swift.aiterm.remotecommand.viewing_the_last_command_you_ran_in_this.55ac3d8b", defaultValue: "Viewing the last command you ran in this session", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getCommandBeforeCursor:
            String(localized: "ui.swift.aiterm.remotecommand.reading_your_current_command_prompt.68cd605a", defaultValue: "Reading your current command prompt", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .searchCommandHistory:
            String(localized: "ui.swift.aiterm.remotecommand.searching_the_history_of_commands_you_have_run.4ce312c5", defaultValue: "Searching the history of commands you have run in this session", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getCommandOutput:
            String(localized: "ui.swift.aiterm.remotecommand.fetching_the_output_of_a_previously_run_command.f8461343", defaultValue: "Fetching the output of a previously run command", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getScreenContents:
            String(localized: "ui.swift.aiterm.remotecommand.reading_the_visible_screen.a7ff13e6", defaultValue: "Reading the visible screen", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getTerminalSize:
            String(localized: "ui.swift.aiterm.remotecommand.querying_the_size_of_your_terminal_window.cb20c42e", defaultValue: "Querying the size of your terminal window", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getShellType:
            String(localized: "ui.swift.aiterm.remotecommand.determining_which_shell_you_use.f866a6fa", defaultValue: "Determining which shell you use", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .detectSSHSession:
            String(localized: "ui.swift.aiterm.remotecommand.checking_if_you_are_using_ssh.40f27888", defaultValue: "Checking if you are using SSH", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getRemoteHostname:
            String(localized: "ui.swift.aiterm.remotecommand.getting_the_current_host_name_of_this_terminal.c5202af4", defaultValue: "Getting the current host name of this terminal session", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getUserIdentity:
            String(localized: "ui.swift.aiterm.remotecommand.checking_your_username.7b59dcf0", defaultValue: "Checking your username", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getCurrentDirectory:
            String(localized: "ui.swift.aiterm.remotecommand.discovering_your_current_directory.17a96e5b", defaultValue: "Discovering your current directory", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .setClipboard:
            String(localized: "ui.swift.aiterm.remotecommand.pasting_to_the_clipboard.89c26b75", defaultValue: "Pasting to the clipboard", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case let .insertTextAtCursor(args):
            String(localized: "ui.swift.aiterm.remotecommand.typing_0_into_the_current_session.49827839", defaultValue: "Typing `\(args.text.escapedForMarkdownCode.truncatedWithTrailingEllipsis(to: 32))` into the current session", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .deleteCurrentLine:
            String(localized: "ui.swift.aiterm.remotecommand.erasing_the_current_command_line.a0452212", defaultValue: "Erasing the current command line", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case let .getManPage(args):
            String(localized: "ui.swift.aiterm.remotecommand.checking_the_manpage_for_0.cf6372e2", defaultValue: "Checking the manpage for `\(args.cmd.escapedForMarkdownCode.truncatedWithTrailingEllipsis(to: 32))`", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case let .createFile(args):
            String(localized: "ui.swift.aiterm.remotecommand.creating_0.e86a9dc7", defaultValue: "Creating \(args.filename)", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case let .searchBrowser(args):
            String(localized: "ui.swift.aiterm.remotecommand.search_in_browser_for_0.4337dcac", defaultValue: "Search in browser for \(args.query)", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case let .loadURL(args):
            String(localized: "ui.swift.aiterm.remotecommand.navigate_to_0.ad407e9c", defaultValue: "Navigate to \(args.url)", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case let .webSearch(args):
            String(localized: "ui.swift.aiterm.remotecommand.search_the_web_for_0.6583f7f4", defaultValue: "Search the web for “\(args.query)”", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getURL:
            String(localized: "ui.swift.aiterm.remotecommand.get_the_current_url.f820440f", defaultValue: "Get the current URL", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .readWebPage:
            String(localized: "ui.swift.aiterm.remotecommand.view_the_current_web_page.cd69b1fb", defaultValue: "View the current web page", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .restartSession:
            String(localized: "ui.swift.aiterm.remotecommand.restarting_this_session.4cef6688", defaultValue: "Restarting this session", bundle: .main, comment: "User-facing text in RemoteCommand.")
        }
    }

    // Model-facing counterpart of markdownDescription. These strings are the
    // pre-localization values and are intentionally not looked up in a bundle.
    var safetyTranscriptDescription: String {
        switch content {
        case .isAtPrompt:
            "Checking if you're at a shell prompt"
        case let .executeCommand(args):
            "Executing `\(args.command.escapedForMarkdownCode.truncatedWithTrailingEllipsis(to: 32))`"
        case .getLastExitStatus:
            "Checking the exit status of the last command"
        case .getCommandHistory:
            "Reviewing the history of commands you have run in this session"
        case .getLastCommand:
            "Viewing the last command you ran in this session"
        case .getCommandBeforeCursor:
            "Reading your current command prompt"
        case .searchCommandHistory:
            "Searching the history of commands you have run in this session"
        case .getCommandOutput:
            "Fetching the output of a previously run command"
        case .getScreenContents:
            "Reading the visible screen"
        case .getTerminalSize:
            "Querying the size of your terminal window"
        case .getShellType:
            "Determining which shell you use"
        case .detectSSHSession:
            "Checking if you are using SSH"
        case .getRemoteHostname:
            "Getting the current host name of this terminal session"
        case .getUserIdentity:
            "Checking your username"
        case .getCurrentDirectory:
            "Discovering your current directory"
        case .setClipboard:
            "Pasting to the clipboard"
        case let .insertTextAtCursor(args):
            "Typing `\(args.text.escapedForMarkdownCode.truncatedWithTrailingEllipsis(to: 32))` into the current session"
        case .deleteCurrentLine:
            "Erasing the current command line"
        case let .getManPage(args):
            "Checking the manpage for `\(args.cmd.escapedForMarkdownCode.truncatedWithTrailingEllipsis(to: 32))`"
        case let .createFile(args):
            "Creating \(args.filename)"
        case let .searchBrowser(args):
            "Search in browser for \(args.query)"
        case let .loadURL(args):
            "Navigate to \(args.url)"
        case let .webSearch(args):
            "Search the web for “\(args.query)”"
        case .getURL:
            "Get the current URL"
        case .readWebPage:
            "View the current web page"
        case .restartSession:
            "Restarting this session"
        }
    }

    var permissionDescription: String {
        switch content {
        case .isAtPrompt:
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_check_if.96cffa24", defaultValue: "The AI Agent would like to check if you're at a shell prompt", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case let .executeCommand(args):
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_execute_0.b31faa87", defaultValue: "The AI Agent would like to execute `\(args.command.escapedForMarkdownCode)`", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getLastExitStatus:
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_check_the.9c790e3b", defaultValue: "The AI Agent would like to check the exit status of the last command", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getCommandHistory:
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_review_the.d7e7bd06", defaultValue: "The AI Agent would like to review the history of commands you have run in this session", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getLastCommand:
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_view_the.f02520c1", defaultValue: "The AI Agent would like to view the last command you ran in this session", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getCommandBeforeCursor:
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_read_your.f24141bf", defaultValue: "The AI Agent would like to read your current command prompt", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .searchCommandHistory:
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_search_the.b992d96c", defaultValue: "The AI Agent would like to search the history of commands you have run in this session", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getCommandOutput:
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_fetch_the.5c04f44b", defaultValue: "The AI Agent would like to fetch the output of a previously run command", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getScreenContents:
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_read_the.6d277182", defaultValue: "The AI Agent would like to read the visible screen of your terminal session", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getTerminalSize:
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_query_the.a9731890", defaultValue: "The AI Agent would like to query the size of your terminal window", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getShellType:
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_determine_which.3355bb27", defaultValue: "The AI Agent would like to determine which shell you use", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .detectSSHSession:
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_check_if.00451475", defaultValue: "The AI Agent would like to check if you are using SSH", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getRemoteHostname:
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_get_the.bb6396a8", defaultValue: "The AI Agent would like to get the current host name of this terminal session", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getUserIdentity:
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_check_your.6b6c54f1", defaultValue: "The AI Agent would like to check your username", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getCurrentDirectory:
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_know_your.a6a231ca", defaultValue: "The AI Agent would like to know your current directory", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .setClipboard:
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_paste_to.c6f6c27d", defaultValue: "The AI Agent would like to paste to the clipboard", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case let .insertTextAtCursor(args):
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_type_0.b541acec", defaultValue: "The AI Agent would like to type `\(args.text.escapedForMarkdownCode.truncatedWithTrailingEllipsis(to: 32))` into the current session", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .deleteCurrentLine:
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_erase_the.46751a8e", defaultValue: "The AI Agent would like to erase the current command line", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case let .getManPage(args):
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_check_the.fd92d4b8", defaultValue: "The AI Agent would like to check the manpage for `\(args.cmd.escapedForMarkdownCode)`", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case let .createFile(args):
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_create_a.7bb1119e", defaultValue: "The AI Agent would like to create a file named `\(args.filename)`", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case let .searchBrowser(args):
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_search_the.29e118d1", defaultValue: "The AI agent would like to search the current web page for “\(args.query)”", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case let .loadURL(args):
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_navigate_to.21b53e83", defaultValue: "The AI agent would like to navigate to \(args.url)", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case let .webSearch(args):
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_write_to.442ecdf4", defaultValue: "The AI agent would like to write to search the web for “\(args.query)”", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .getURL:
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_write_to.b046fb29", defaultValue: "The AI agent would like to write to get the current URL", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .readWebPage:
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_write_to.910b1970", defaultValue: "The AI agent would like to write to view the current web page", bundle: .main, comment: "User-facing text in RemoteCommand.")
        case .restartSession:
            String(localized: "ui.swift.aiterm.remotecommand.the_ai_agent_would_like_to_restart_this.e0d6447d", defaultValue: "The AI Agent would like to restart this session, which kills any running jobs", bundle: .main, comment: "User-facing text in RemoteCommand.")
        }
    }

    var shouldPublishNotice: Bool {
        switch content {
        case .executeCommand:
            false
        case .isAtPrompt, .getLastExitStatus, .getCommandHistory, .getLastCommand,
                .getCommandBeforeCursor, .searchCommandHistory, .getCommandOutput,
                .getScreenContents, .getTerminalSize,
                .getShellType, .detectSSHSession, .getRemoteHostname, .getUserIdentity,
                .getCurrentDirectory, .setClipboard, .insertTextAtCursor, .deleteCurrentLine,
                .getManPage, .createFile, .searchBrowser, .loadURL,
                .webSearch, .getURL, .readWebPage, .restartSession:
            true
        }
    }
}

extension RemoteCommand.Content {
    var functionName: String {
        switch self {
        case .isAtPrompt:
            "is_at_prompt"
        case .executeCommand:
            "execute_command"
        case .getLastExitStatus:
            "get_last_exit_status"
        case .getCommandHistory:
            "get_command_history"
        case .getLastCommand:
            "get_last_command"
        case .getCommandBeforeCursor:
            "get_command_before_cursor"
        case .searchCommandHistory:
            "search_command_history"
        case .getCommandOutput:
            "get_command_output"
        case .getScreenContents:
            "get_screen_contents"
        case .getTerminalSize:
            "get_terminal_size"
        case .getShellType:
            "get_shell_type"
        case .detectSSHSession:
            "detect_ssh_session"
        case .getRemoteHostname:
            "get_remote_hostname"
        case .getUserIdentity:
            "get_user_identity"
        case .getCurrentDirectory:
            "get_current_directory"
        case .setClipboard:
            "set_clipboard"
        case .insertTextAtCursor:
            "insert_text_at_cursor"
        case .deleteCurrentLine:
            "delete_current_line"
        case .getManPage:
            "get_man_page"
        case .createFile:
            "create_file"
        case .searchBrowser:
            "find_on_page"
        case .loadURL:
            "load_url"
        case .webSearch:
            "web_search_in_browser"
        case .getURL:
            "get_current_url"
        case .readWebPage:
            "read_web_page_section"
        case .restartSession:
            "restart_session"
        }
    }

    var argDescriptions: [String: String] {
        return switch self {
        case .isAtPrompt(_):
            [:]
        case .executeCommand(_):
            ["command": "The command to run"]
        case .getLastExitStatus(_):
            [:]
        case .getCommandHistory(_):
            ["limit": "Maximum number of history items to return."]
        case .getLastCommand(_):
            [:]
        case .getCommandBeforeCursor(_):
            [:]
        case .searchCommandHistory(_):
            ["query": "Search query for filtering command history."]
        case .getCommandOutput(_):
            ["id": "Unique identifier of the command whose output is requested."]
        case .getScreenContents(_):
            ["lines": "Number of trailing lines to return when the visible screen is a normal shell (the primary screen). Use 0 for the default of 100. Ignored for a full-screen application, where only the current screen is available."]
        case .getTerminalSize(_):
            [:]
        case .getShellType(_):
            [:]
        case .detectSSHSession(_):
            [:]
        case .getRemoteHostname(_):
            [:]
        case .getUserIdentity(_):
            [:]
        case .getCurrentDirectory(_):
            [:]
        case .setClipboard(_):
            ["text": "The text to copy to the clipboard."]
        case .insertTextAtCursor(_):
            ["text": "The text to insert at the cursor position. Supports a small backslash-escape vocabulary so you can send control keys and special characters: \\\\ for a literal backslash, \\n for newline, \\r for carriage return, \\t for tab, and \\uXXXX (four hex digits, JSON-style) for any Unicode scalar. Examples: \\u0004 for Ctrl-D / EOF, \\u001a for Ctrl-Z, \\u000c for Ctrl-L, \\u001b for Escape. Consider whether execute_command would be a better choice, especially when running a command at the shell prompt since insert_text_at_cursor does not return the output to you."]
        case .deleteCurrentLine(_):
            [:]
        case .getManPage(_):
            ["cmd": "The command whose man page content is requested."]
        case .createFile:
            ["filename": "The name of the file you wish to create. It will be replaced if it already exists.",
             "content": "The content that will be written to the file."]
        case .searchBrowser(_):
            ["query": "The text to search for on the current page. Ensure you know which web page is currently loaded before using this."]
        case .loadURL(_):
            ["url": "The URL to load. Must use https scheme."]
        case .webSearch(_):
            ["query": "The web search query"]
        case .getURL(_):
            [:]
        case .readWebPage(_):
            ["startingLineNumber": "The line number to start reading at.",
             "numberOfLines": "The number of lines to return."]
        case .restartSession(_):
            [:]
        }
    }

    var functionDescription: String {
        switch self {
        case .isAtPrompt(_):
            "Returns true if the terminal is at the command prompt, allowing safe command injection."
        case .executeCommand(_):
            "Runs a shell command and returns its output once the command finishes. "
            + "Do NOT use it for interactive or full-screen (TUI) programs (for example "
            + "vim, less, top, an ssh session, a REPL, or claude): it blocks until the "
            + "command exits, so an interactive or long-running program never returns. To "
            + "launch or drive a TUI from the command line, use insert_text_at_cursor instead."
        case .getLastExitStatus(_):
            "Retrieves the exit status of the last executed command."
        case .getCommandHistory(_):
            "Returns the recent command history."
        case .getLastCommand(_):
            "Retrieves the most recent command."
        case .getCommandBeforeCursor(_):
            "Returns the current partially typed command before the cursor."
        case .searchCommandHistory(_):
            "Searches history for commands matching a query."
        case .getCommandOutput(_):
            "Returns the output of a previous command by its unique identifier."
        case .getScreenContents(_):
            "Returns the visible contents of this terminal session. For a normal shell the text is linear scrollback (real history; ask for more `lines` to see further back). For a full-screen application (vim, less, htop, a REPL, etc.) the text is only the current rendered screen: there is no scrollback or history beyond what is displayed. The result reports a `kind` field and an `is_snapshot` flag (true means do not assume any history is present) alongside the raw `text`. The text uses a few markup tokens (the angle brackets are U+27E8/U+27E9 and effectively never occur in real terminal output): \u{27E8}dim\u{27E9}\u{2026}\u{27E8}/dim\u{27E9} wraps faint/dimmed text (how shells and TUIs render inline suggestions and ghost completions); \u{27E8}cursor\u{27E9} marks the text cursor's position; \u{27E8}image\u{27E9} stands in for an inline image. These tokens are inserted by iTerm2 and are not literally present on the screen."
        case .getTerminalSize(_):
            "Returns (columns, rows) of the terminal window."
        case .getShellType(_):
            "Detects the shell in use (e.g., bash, fish, xonsh, zsh)."
        case .detectSSHSession(_):
            "Returns true if the user is SSH’ed into a remote host."
        case .getRemoteHostname(_):
            "Returns the remote hostname if in an SSH session."
        case .getUserIdentity(_):
            "Returns the logged-in user’s username."
        case .getCurrentDirectory(_):
            "Returns the current directory."
        case .setClipboard(_):
            "Copies text to the clipboard."
        case .insertTextAtCursor(_):
            "Inserts text into the terminal input at the cursor position, as if typed; "
            + "end with a newline to submit it. Use this to launch and interact with "
            + "interactive or full-screen (TUI) programs - start one from the command "
            + "prompt (type the command plus a newline), choose a menu option, or send "
            + "keystrokes to a running app - since unlike execute_command it does not wait "
            + "for the program to finish."
        case .deleteCurrentLine(_):
            "Clears the current command line input (only at the prompt)."
        case .getManPage(_):
            "Returns the content of a command's man page."
        case .createFile:
            "Creates a file containing a specified string on the user's computer and then reveals it in Finder."
        case .loadURL:
            "Loads the specified URL in the associated web browser"
        case .webSearch:
            "Performs a web search using the currently configured search engine in the associated web browser"
        case .getURL:
            "Returns the current URL of the associated web browser"
        case .readWebPage:
            "Returns some of the content (in markdown format) of the page visible in the associated web browser."
        case .searchBrowser(_):
            "Searches the current web page in the associated web browser (after converting to markdown format) for a substring."
        case .restartSession(_):
            "Restarts this terminal session: terminates any running jobs and relaunches the session’s command, equivalent to the Session > Restart Session menu item. Use this to recover a hung or misconfigured session. This is disruptive - every running process in the session is killed - so only use it when the user has asked to restart or when the session is unusable."
        }
    }

    func withValue(_ value: Any) -> RemoteCommand.Content {
        switch self {
        case .isAtPrompt: .isAtPrompt(value as! RemoteCommand.IsAtPrompt)
        case .executeCommand: .executeCommand(value as! RemoteCommand.ExecuteCommand)
        case .getLastExitStatus: .getLastExitStatus(value as! RemoteCommand.GetLastExitStatus)
        case .getCommandHistory: .getCommandHistory(value as! RemoteCommand.GetCommandHistory)
        case .getLastCommand: .getLastCommand(value as! RemoteCommand.GetLastCommand)
        case .getCommandBeforeCursor: .getCommandBeforeCursor(value as! RemoteCommand.GetCommandBeforeCursor)
        case .searchCommandHistory: .searchCommandHistory(value as! RemoteCommand.SearchCommandHistory)
        case .getCommandOutput: .getCommandOutput(value as! RemoteCommand.GetCommandOutput)
        case .getScreenContents: .getScreenContents(value as! RemoteCommand.GetScreenContents)
        case .getTerminalSize: .getTerminalSize(value as! RemoteCommand.GetTerminalSize)
        case .getShellType: .getShellType(value as! RemoteCommand.GetShellType)
        case .detectSSHSession: .detectSSHSession(value as! RemoteCommand.DetectSSHSession)
        case .getRemoteHostname: .getRemoteHostname(value as! RemoteCommand.GetRemoteHostname)
        case .getUserIdentity: .getUserIdentity(value as! RemoteCommand.GetUserIdentity)
        case .getCurrentDirectory: .getCurrentDirectory(value as! RemoteCommand.GetCurrentDirectory)
        case .setClipboard: .setClipboard(value as! RemoteCommand.SetClipboard)
        case .insertTextAtCursor: .insertTextAtCursor(value as! RemoteCommand.InsertTextAtCursor)
        case .deleteCurrentLine: .deleteCurrentLine(value as! RemoteCommand.DeleteCurrentLine)
        case .getManPage: .getManPage(value as! RemoteCommand.GetManPage)
        case .createFile: .createFile(value as! RemoteCommand.CreateFile)
        case .searchBrowser: .searchBrowser(value as! RemoteCommand.SearchBrowser)
        case .loadURL: .loadURL(value as! RemoteCommand.LoadURL)
        case .webSearch: .webSearch(value as! RemoteCommand.WebSearch)
        case .getURL: .getURL(value as! RemoteCommand.GetURL)
        case .readWebPage: .readWebPage(value as! RemoteCommand.ReadWebPage)
        case .restartSession: .restartSession(value as! RemoteCommand.RestartSession)
        }
    }
}
