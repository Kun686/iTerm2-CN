//
//  LastPassDataSource.swift
//  iTerm2SharedARC
//
//  Created by George Nachman on 3/20/22.
//

import Foundation
import UniformTypeIdentifiers

class LastPassDataSource: CommandLinePasswordDataSource {
    enum LPError: Error {
        case unusableCLI
        case runtime
        case badOutput
        case syncFailed
        case canceledByUser
        case timedOut
        case needsLogin
    }

    // This is a short-lived cache used to consolidate availability checks in a series of related
    // operations.
    enum Availability {
        case uncached
        case wantCache
        case cached(Bool)
    }
    private var available = Availability.uncached
    private let browser: Bool

    init(browser: Bool) {
        self.browser = browser
    }

    private struct ErrorHandler {
        var requestedAuthentication = false

        mutating func handleError(_ data: Data?) throws -> Data? {
            guard let data = data else {
                return nil
            }
            if let string = String(data: data, encoding: .utf8), string.contains("lpass login") {
                throw LPError.needsLogin
            }
            if requestedAuthentication {
                return nil
            }
            requestedAuthentication = true
            guard let password = ModalPasswordAlert(String(localized: "ui.swift.passwordmanager.lastpassdatasource.enter_your_lastpass_master_password.1ee10bf2", defaultValue: "Enter your LastPass master password:", bundle: .main, comment: "User-facing text in LastPassDataSource.")).run(window: nil) else {
                throw LPError.canceledByUser
            }
            return (password + "\n").data(using: .utf8)
        }
    }

    private struct LastPassBasicCommandRecipe<Inputs, Outputs>: Recipe {
        private let commandRecipe: CommandRecipe<Inputs, Outputs>
        init(_ args: [String],
             timeout: TimeInterval? = nil,
             outputTransformer: @escaping (Output) throws -> Outputs) {
            var errorHandler = ErrorHandler()
            commandRecipe = CommandRecipe { _ in
                var request = InteractiveCommandRequest(command: LastPassUtils.pathToCLI,
                                                        args: args,
                                                        env: LastPassUtils.basicEnvironment)
                request.callbacks = InteractiveCommandRequest.Callbacks(
                    callbackQueue: DispatchQueue.main,
                    handleStdout: nil,
                    handleStderr: { try errorHandler.handleError($0) },
                    handleTermination: nil,
                    didLaunch: nil)
                if let timeout = timeout {
                    request.deadline = Date(timeIntervalSinceNow: timeout)
                }
                return request
            } recovery: { error throws in
                try LastPassUtils.recover(error)
            } outputTransformer: { output throws in
                if output.timedOut {
                    throw LPError.timedOut
                }
                if output.returnCode != 0 {
                    throw LPError.runtime
                }
                return try outputTransformer(output)
            }
        }

        func transformAsync(context: RecipeExecutionContext,
                            inputs: Inputs,
                            completion: @escaping (Outputs?, Error?) -> ()) {
            commandRecipe.transformAsync(context: context, inputs: inputs, completion: completion)
        }
        private func handleError(_ data: Data) {

        }
    }

    private struct LastPassDynamicCommandRecipe<Inputs, Outputs>: Recipe {
        private let commandRecipe: CommandRecipe<Inputs, Outputs>

        init(inputTransformer: @escaping (Inputs) throws -> (CommandLinePasswordDataSourceExecutableCommand),
             outputTransformer: @escaping (Output) throws -> Outputs) {
            commandRecipe = CommandRecipe<Inputs, Outputs> { inputs throws -> CommandLinePasswordDataSourceExecutableCommand in
                return try inputTransformer(inputs)
            } recovery: { error throws in
                try LastPassUtils.recover(error)
            } outputTransformer: { output throws -> Outputs in
                if output.returnCode != 0 {
                    throw LPError.runtime
                }
                return try outputTransformer(output)
            }
        }

        func transformAsync(context: RecipeExecutionContext,
                            inputs: Inputs,
                            completion: @escaping (Outputs?, Error?) -> ()) {
            commandRecipe.transformAsync(context: context, inputs: inputs, completion: completion)
        }
    }

    private var terminalGroups: Set<String> {
        if iTermAdvancedSettingsModel.lastpassGroups().isEmpty {
            let iterm = "iTerm2"
            return Set([iterm])
        } else {
            let illegalCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " ")).inverted
            return Set(iTermAdvancedSettingsModel.lastpassGroups().components(separatedBy: ",")).filter { name in
                name.rangeOfCharacter(from: illegalCharacters) == nil
            }
        }
    }

    private var listAccountsRecipe: AnyRecipe<Void, [Account]> {
        var args = ["ls", "--format=%ag\t%ai\t%an\t%au"]
        let requiredGroups: Set<String>?
        let groupsToExclude: Set<String>?
        if browser {
            requiredGroups = nil
            groupsToExclude = terminalGroups
        } else {
            requiredGroups = terminalGroups
            groupsToExclude = nil
        }
        if let requiredGroups, requiredGroups.count == 1, let name = requiredGroups.first {
            args.append(name)
        }
        let recipe = LastPassBasicCommandRecipe<Void, [Account]>(args, timeout: 5) { output in
            guard let string = String(data: output.stdout, encoding: .utf8) else {
                throw LPError.badOutput
            }
            let lines = string.components(separatedBy: "\n")
            return lines.compactMap { line -> Account? in
                let parts = line.components(separatedBy: "\t")
                guard parts.count == 4 else {
                    return nil
                }
                if parts[1] == "0" {
                    // Unsynced accounts are not safe because they don't have unique identifiers.
                    return nil
                }
                if let groupsToExclude, groupsToExclude.contains(parts[0]) {
                    return nil
                }
                if let requiredGroups, !requiredGroups.contains(parts[0]) {
                    return nil
                }
                return Account(identifier: AccountIdentifier(value: parts[1]),
                               userName: parts[3],
                               accountName: parts[2],
                               hasOTP: false,
                               sendOTP: false)
            }
        }
        return wrap(String(localized: "ui.swift.passwordmanager.lastpassdatasource.the_account_list_could_not_be_fetched.391ab746", defaultValue: "The account list could not be fetched.", bundle: .main, comment: "User-facing text in LastPassDataSource."), AnyRecipe(recipe))
    }

    private var getPasswordRecipe: AnyRecipe<AccountIdentifier, Password> {
        let recipe = LastPassDynamicCommandRecipe<AccountIdentifier, Password> {
            let args = ["show", "--password", $0.value]
            return InteractiveCommandRequest(command: LastPassUtils.pathToCLI,
                                             args: args,
                                             env: LastPassUtils.basicEnvironment)
        } outputTransformer: { output in
            if output.returnCode != 0 {
                throw LPError.runtime
            }
            guard let string = String(data: output.stdout, encoding: .utf8) else {
                throw LPError.badOutput
            }
            return Password(password: string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
        }
        return wrap(String(localized: "ui.swift.passwordmanager.lastpassdatasource.the_password_could_not_be_fetched.ce5e634b", defaultValue: "The password could not be fetched.", bundle: .main, comment: "User-facing text in LastPassDataSource."), AnyRecipe(recipe))
    }

    private var setPasswordRecipe: AnyRecipe<SetPasswordRequest, Void> {
        let recipe = LastPassDynamicCommandRecipe<SetPasswordRequest, Void> {
            let args = ["edit", "--non-interactive", "--password", $0.accountIdentifier.value]
            var commandRequest = InteractiveCommandRequest(
                command: LastPassUtils.pathToCLI,
                args: args,
                env: LastPassUtils.basicEnvironment)
            // A nil password means "leave unchanged" (name/user-only edit). LastPass cannot edit
            // in place and this command only sets the password, so writing "" here would blank
            // the stored secret. Fail loudly at the data layer instead of relying on the UI
            // guard (supportsInPlaceEdit) to keep this path unreached.
            guard let newPassword = $0.newPassword else {
                throw LPError.runtime
            }
            let dataToWrite = (newPassword + "\n").data(using: .utf8)!
            commandRequest.callbacks = InteractiveCommandRequest.Callbacks(
                callbackQueue: InteractiveCommandRequest.ioQueue,
                handleStdout: nil,
                handleStderr: nil,
                handleTermination: nil,
                didLaunch: { writing in
                    writing.write(dataToWrite) {
                        writing.closeForWriting()
                    }
                })
            return commandRequest
        } outputTransformer: { output in
            if output.returnCode != 0 {
                throw LPError.runtime
            }
        }
        return wrap(String(localized: "ui.swift.passwordmanager.lastpassdatasource.the_password_could_not_be_set.92809956", defaultValue: "The password could not be set.", bundle: .main, comment: "User-facing text in LastPassDataSource."), AnyRecipe(recipe))
    }

    private var deleteRecipe: AnyRecipe<AccountIdentifier, Void> {
        let recipe = LastPassDynamicCommandRecipe<AccountIdentifier, Void> {
            let args = ["rm", $0.value]
            return InteractiveCommandRequest(
                command: LastPassUtils.pathToCLI,
                args: args,
                env: LastPassUtils.basicEnvironment)
        } outputTransformer: { output in
            if output.returnCode != 0 {
                throw LPError.runtime
            }
        }
        return wrap(String(localized: "ui.swift.passwordmanager.lastpassdatasource.the_account_could_not_be_deleted.44536996", defaultValue: "The account could not be deleted", bundle: .main, comment: "User-facing text in LastPassDataSource."), AnyRecipe(recipe))
    }

    private var addAccountRecipe: AnyRecipe<AddRequest, AccountIdentifier> {
        let groupPrefix = (browser ? "" : "iTerm2/")
        let addRecipe = LastPassDynamicCommandRecipe<AddRequest, Void> {
            let args = ["add", groupPrefix + $0.accountName, "--non-interactive"]
            let input = "Username: \($0.userName)\nPassword: \($0.password)"
            var commandRequest = InteractiveCommandRequest(
                command: LastPassUtils.pathToCLI,
                args: args,
                env: LastPassUtils.basicEnvironment)
            let dataToWrite = input.data(using: .utf8)!
            commandRequest.callbacks = InteractiveCommandRequest.Callbacks(
                callbackQueue: InteractiveCommandRequest.ioQueue,
                handleStdout: nil,
                handleStderr: nil,
                handleTermination: nil,
                didLaunch: { writing in
                    writing.write(dataToWrite) {
                        writing.closeForWriting()
                    }
                })
            return commandRequest
        } outputTransformer: { output in
            if output.returnCode != 0 {
                throw LPError.runtime
            }
        }

        let syncRecipe = LastPassBasicCommandRecipe<(AddRequest, Void), Void>(["sync", "now"],
                                                                              timeout: 5) { _ in }

        let showRecipe = LastPassDynamicCommandRecipe<(AddRequest, Void), AccountIdentifier> { tuple in
            let args = ["show", "--id", groupPrefix + tuple.0.accountName]
            return InteractiveCommandRequest(command: LastPassUtils.pathToCLI,
                                             args: args,
                                             env: LastPassUtils.basicEnvironment)
        } outputTransformer: { output in
            if output.returnCode != 0 {
                throw LPError.runtime
            }
            guard let string = String(data: output.stdout, encoding: .utf8) else {
                throw LPError.badOutput
            }
            let lines = string.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
            guard lines.count >= 1 else {
                throw LPError.runtime
            }
            let idString = lines.last!
            guard idString != "0" else {
                throw LPError.syncFailed
            }
            return AccountIdentifier(value: idString)
        }

        let addSyncSequence:
        SequenceRecipe<
            LastPassDynamicCommandRecipe<AddRequest, Void>,
                LastPassBasicCommandRecipe<(AddRequest, Void), Void>> = SequenceRecipe(addRecipe, syncRecipe)
        let sequence = SequenceRecipe(addSyncSequence, showRecipe)
        return wrap(String(localized: "ui.swift.passwordmanager.lastpassdatasource.the_account_could_not_be_added.e4dbedd6", defaultValue: "The account could not be added.", bundle: .main, comment: "User-facing text in LastPassDataSource."), AnyRecipe(sequence))
    }

    func wrap<Inputs, Outputs>(_ message: String, _ recipe: AnyRecipe<Inputs, Outputs>) -> AnyRecipe<Inputs, Outputs> {
        return AnyRecipe(CatchRecipe(recipe, errorHandler: { (inputs, error) in
            if error as? LPError == LPError.timedOut {
                let alert = NSAlert()
                alert.messageText = String(localized: "ui.swift.passwordmanager.lastpassdatasource.timeout.70594d93", defaultValue: "Timeout", bundle: .main, comment: "User-facing text in LastPassDataSource.")
                alert.informativeText = String(localized: "ui.swift.passwordmanager.lastpassdatasource.the_lastpass_service_took_too_long_to_respond.bf2f9c55", defaultValue: "The LastPass service took too long to respond. \(message)", bundle: .main, comment: "User-facing text in LastPassDataSource.")
                alert.addButton(withTitle: String(localized: "ui.swift.passwordmanager.lastpassdatasource.ok.565339bc", defaultValue: "OK", bundle: .main, comment: "User-facing text in LastPassDataSource."))
                alert.runModal()
                return
            } else if error as? LPError == LPError.needsLogin {
                LastPassUtils.showNotLoggedInMessage()
            }
            NSLog("\(error)")
        }))
    }
    var configuration: Configuration {
        lazy var value = {
            Configuration(listAccountsRecipe: listAccountsRecipe,
                          getPasswordRecipe: getPasswordRecipe,
                          setPasswordRecipe: setPasswordRecipe,
                          deleteRecipe: deleteRecipe,
                          addAccountRecipe: addAccountRecipe)
        }()
        return value
    }
}

extension LastPassDataSource: PasswordManagerDataSource {
    @objc var name: String { "LastPass" }
    @objc var canResetConfiguration: Bool { false }
    @objc func resetConfiguration() { }

    var hasOTP: Bool { false }
    var sendOTP: Bool { false }

    func toggleShouldSendOTP(context: RecipeExecutionContext,
                             account: any PasswordManagerAccount,
                             completion: @escaping (PasswordManagerAccount?, Error?) -> ()) {
        it_fatalError()
    }

    func fetchAccounts(context: RecipeExecutionContext, completion: @escaping ([PasswordManagerAccount]) -> ()) {
        standardAccounts(context: context, configuration: configuration) { result, _ in
            completion(result ?? [])
        }
    }

    var addAccountToggleDescriptions: [[String: Any]]? { nil }
    var supportsInPlaceEdit: Bool { false }
    var canEditPassword: Bool { true }
    var requiresPasswordForAdd: Bool { false }
    func prepareAvailability(_ completion: @escaping () -> ()) { completion() }

    @objc(addUserName:accountName:password:flags:context:completion:)
    func add(userName: String,
             accountName: String,
             password: String,
             flags: [String: Bool],
             context: RecipeExecutionContext,
             completion: @escaping (PasswordManagerAccount?, Error?) -> ()) {
        // LastPass has no Add Account toggles, so flags is ignored.
        standardAdd(configuration,
                    userName: userName,
                    accountName: accountName,
                    password: password,
                    context: context,
                    completion: completion)
    }

    var autogeneratedPasswordsOnly: Bool {
        false
    }

    func checkAvailability() -> Bool {
        if case let .cached(value) = available {
            return value
        }
        let value = _checkAvailability()
        if case .wantCache = available {
            available = .cached(value)
        }
        return value
    }

    private func _checkAvailability() -> Bool {
        do {
            let request = InteractiveCommandRequest(command: LastPassUtils.pathToCLI,
                                                    args: ["status", "--color=never"],
                                                    env: LastPassUtils.basicEnvironment)
            let output = try request.exec()
            if output.returnCode == 0 {
                return true
            }
            if String(data: output.stdout, encoding: .utf8)?.hasPrefix("Not logged in") ?? false {
                do {
                    try LastPassUtils.showLoginUI()
                    return true
                } catch {
                    return false
                }
            }
            return false
        } catch {
            return false
        }
    }

    func resetErrors() {
    }

    func reload(_ completion: () -> ()) {
        completion()
    }

    func consolidateAvailabilityChecks(_ block: () -> ()) {
        let saved = available
        defer {
            available = saved
        }
        available = .wantCache
        block()
    }
    var supportsMultipleAccounts: Bool {
        false
    }

    func switchAccount(completion: @escaping () -> ()) {
        completion()
    }
}

class LastPassUtils {
    static let basicEnvironment = ["HOME": NSHomeDirectory(),
                                   "LPASS_ASKPASS": pathToAskpass]
    static var pathToAskpass: String {
        return Bundle.main.path(forResource: "askpass", ofType: "sh")!
    }

    private static var _customPathToCLI: String? = nil
    private(set) static var usable: Bool? = nil

    static var pathToCLI: String {
        if let customPath = _customPathToCLI {
            return customPath
        }
        let normalPaths = ["/opt/local/bin/lpass", "/opt/homebrew/bin/lpass"]
        lazy var existingNormalPath = {
            normalPaths.first { checkUsability($0) }
        }()
        if let normalPath = existingNormalPath {
            usable = true
            return normalPath
        }
        while showCannotFindCLIMessage() {
            _customPathToCLI = askUserToFindCLI()
            guard let path = _customPathToCLI else {
                break
            }
            usable = checkUsability(path)
            if usable == true {
                break
            }
        }
        return _customPathToCLI ?? normalPaths[0]
    }

    static func throwIfUnusable() throws {
        _ = pathToCLI
        if usable == false {
            throw LastPassDataSource.LPError.unusableCLI
        }
    }

    static func resetErrors() {
        if usable == false {
            usable = nil
            _customPathToCLI = nil
        }
    }
    static func checkUsability() -> Bool {
        return checkUsability(pathToCLI)
    }

    private static func checkUsability(_ path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }

    static func recover(_ error: Error) throws {
        if error as? LastPassDataSource.LPError == LastPassDataSource.LPError.needsLogin {
            try showLoginUI()
        }
        throw error
    }

    private static let usernameUserDefaultsKey = "LastPassUserName"

    static func showLoginUI() throws {
        let alert = ModalPasswordAlert(String(localized: "ui.swift.passwordmanager.lastpassdatasource.please_log_in_to_lastpass.ad381002", defaultValue: "Please log in to LastPass", bundle: .main, comment: "User-facing text in LastPassDataSource."))
        alert.username = iTermUserDefaults.userDefaults().string(forKey: usernameUserDefaultsKey) ?? ""
        if let password = alert.run(window: nil), let username = alert.username {
            iTermUserDefaults.userDefaults().set(alert.username, forKey: usernameUserDefaultsKey)
            var request = CommandLinePasswordDataSource.InteractiveCommandRequest(command: pathToCLI,
                                                                                  args: ["login", "--color=never", username],
                                                                                  env: basicEnvironment)
            request.callbacks = .init(callbackQueue: CommandLinePasswordDataSource.InteractiveCommandRequest.ioQueue,
                                      handleStdout: nil,
                                      handleStderr: nil,
                                      handleTermination: nil,
                                      didLaunch: { writing in
                writing.write(password.data(using: .utf8)!) {
                    writing.closeForWriting()
                }
            })
            let output = try request.exec()
            if output.returnCode != 0 {
                NSLog("\(String(data: output.stderr, encoding: .utf8) ?? "(bad output)")")
                showNotLoggedInMessage()
                throw LastPassDataSource.LPError.needsLogin
            }
        } else {
            throw LastPassDataSource.LPError.runtime
        }
    }

    static func showNotLoggedInMessage() {
        let alert = NSAlert()
        let email = iTermUserDefaults.userDefaults().string(forKey: usernameUserDefaultsKey) ?? "your@email.address"
        alert.messageText = String(localized: "ui.swift.passwordmanager.lastpassdatasource.authentication_failed.1a195253", defaultValue: "Authentication Failed", bundle: .main, comment: "User-facing text in LastPassDataSource.")
        alert.informativeText = String(localized: "ui.swift.passwordmanager.lastpassdatasource.you_can_also_try_opening_a_terminal_window.53766ee2", defaultValue: "You can also try opening a terminal window and running `lpass login \(email)`.", bundle: .main, comment: "User-facing text in LastPassDataSource.")
        alert.addButton(withTitle: String(localized: "ui.swift.passwordmanager.lastpassdatasource.open_terminal_window.cf871ed5", defaultValue: "Open Terminal Window", bundle: .main, comment: "User-facing text in LastPassDataSource."))
        alert.addButton(withTitle: String(localized: "ui.swift.passwordmanager.lastpassdatasource.copy_command.3bdd0fd9", defaultValue: "Copy Command", bundle: .main, comment: "User-facing text in LastPassDataSource."))
        alert.addButton(withTitle: String(localized: "ui.swift.passwordmanager.lastpassdatasource.cancel.19766ed6", defaultValue: "Cancel", bundle: .main, comment: "User-facing text in LastPassDataSource."))
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            let window = iTermController.sharedInstance().openSingleUseLoginWindowAndWrite("lpass login \(email)".data(using: .utf8)!) { session in
                session?.addExpectation("^Success: Logged in as",
                                        after: nil,
                                        deadline: nil,
                                        willExpect: nil) { _ in
                    let alert = NSAlert()
                    alert.messageText = String(localized: "ui.swift.passwordmanager.lastpassdatasource.login_successful.5c7b7f11", defaultValue: "Login Successful", bundle: .main, comment: "User-facing text in LastPassDataSource.")
                    alert.informativeText = String(localized: "ui.swift.passwordmanager.lastpassdatasource.please_retry_your_action_in_the_password_manager.edb778a7", defaultValue: "Please retry your action in the password manager.", bundle: .main, comment: "User-facing text in LastPassDataSource.")
                    alert.addButton(withTitle: String(localized: "ui.swift.passwordmanager.lastpassdatasource.ok.565339bc", defaultValue: "OK", bundle: .main, comment: "User-facing text in LastPassDataSource."))
                    alert.runModal()
                    session?.close()
                }
            }
            Timer.scheduledTimer(withTimeInterval: 0, repeats: false) { _ in
                window?.makeKeyAndOrderFront(nil)
            }
        case .alertSecondButtonReturn:
            NSPasteboard.general.declareTypes([.string], owner: self)
            NSPasteboard.general.setString("lpass login \(email)", forType: .string)
        default:
            break
        }
    }

    // Returns true to show an open panel to locate it.
    private static func showCannotFindCLIMessage() -> Bool {
        let alert = NSAlert()
        alert.messageText = String(localized: "ui.swift.passwordmanager.lastpassdatasource.can_t_find_lastpass_cli.dd5b75de", defaultValue: "Can’t Find LastPass CLI", bundle: .main, comment: "User-facing text in LastPassDataSource.")
        alert.informativeText = String(localized: "ui.swift.passwordmanager.lastpassdatasource.in_order_to_use_the_lastpass_integration_iterm2.4872659e", defaultValue: "In order to use the LastPass integration, iTerm2 needs to know where to find the CLI app named “lpass”. Select Locate to provide its location.", bundle: .main, comment: "User-facing text in LastPassDataSource.")
        alert.addButton(withTitle: String(localized: "ui.swift.passwordmanager.lastpassdatasource.locate.ee867dc4", defaultValue: "Locate", bundle: .main, comment: "User-facing text in LastPassDataSource."))
        alert.addButton(withTitle: String(localized: "ui.swift.passwordmanager.lastpassdatasource.cancel.19766ed6", defaultValue: "Cancel", bundle: .main, comment: "User-facing text in LastPassDataSource."))
        alert.addButton(withTitle: String(localized: "ui.swift.passwordmanager.lastpassdatasource.help.b79cac92", defaultValue: "Help", bundle: .main, comment: "User-facing text in LastPassDataSource."))
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return true
        case .alertSecondButtonReturn:
            return false
        case .alertThirdButtonReturn:
            NSWorkspace.shared.open(URL(string: "https://iterm2.com/lastpass-cli")!)
            return false
        default:
            return false
        }
    }

    private static func askUserToFindCLI() -> String? {
        class LastPassCLIFinderOpenPanelDelegate: NSObject, NSOpenSavePanelDelegate {
            func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
                if FileManager.default.itemIsDirectory(url.path) {
                    return true
                }
                return url.lastPathComponent == "lpass"
            }
        }
        let panel = NSOpenPanel()
        let defaultPath = ["/opt/homebrew/bin", "/opt/local/bin"].first { FileManager.default.fileExists(atPath: $0) } ?? "/usr/local/bin"
        panel.directoryURL = URL(fileURLWithPath: defaultPath)
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [ UTType.unixExecutable ]
        let delegate = LastPassCLIFinderOpenPanelDelegate()
        return withExtendedLifetime(delegate) {
            panel.delegate = delegate
            if panel.runModal() == .OK,
                let url = panel.url,
                url.lastPathComponent == "lpass" {
                return url.path
            }
            return nil
        }
    }
}
