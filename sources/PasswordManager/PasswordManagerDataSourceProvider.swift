//
//  PasswordManagerDataSourceProvider.swift
//  iTerm2SharedARC
//
//  Created by George Nachman on 3/19/22.
//

import Foundation
import LocalAuthentication

@objc(iTermPasswordManagerDataSourceProvider)
class PasswordManagerDataSourceProvider: NSObject {
    @objc static let forTerminal = PasswordManagerDataSourceProvider(browser: false)
    @objc static let forBrowser = PasswordManagerDataSourceProvider(browser: true)
    @objc private(set) var authenticated = false
    private var _dataSource: PasswordManagerDataSource? = nil
    private var dataSourceType: DataSource!
    private let _keychain: KeychainPasswordDataSource
    private var _onePassword: OnePasswordDataSource
    private var _lastPass: LastPassDataSource
    private var _keePassXC: AdapterPasswordDataSource
    private var _bitwarden: AdapterPasswordDataSource
    private var _keeper: AdapterPasswordDataSource
    #if ITERM_DEBUG
    private var _testAdapter: AdapterPasswordDataSource
    #endif
    private let browser: Bool
    private var dataSourceNameUserDefaultsKey: String {
        "NoSyncPasswordManagerDataSourceName" + (browser ? "Browser" : "")
    }

    enum DataSource: String {
        case keychain = "Keychain"
        case onePassword = "OnePassword"
        case lastPass = "LastPass"
        case keePassXC = "KeePassXC"
        case bitwarden = "Bitwarden"
        case keeper = "Keeper"
        #if ITERM_DEBUG
        case testAdapter = "TestAdapter"
        #endif

        static let defaultValue = DataSource.keychain
    }

    init(browser: Bool) {
        _keychain = KeychainPasswordDataSource(browser: browser)
        _onePassword = OnePasswordDataSource(browser: browser)
        _lastPass = LastPassDataSource(browser: browser)

        let keepassPath = Bundle(for: Self.self).path(forAuxiliaryExecutable: "iterm2-keepassxc-adapter")!
        _keePassXC = AdapterPasswordDataSource(browser: browser,
                                               adapterPath: keepassPath,
                                               identifier: "KeePassXC")

        let bitwardenPath = Bundle(for: Self.self).path(forAuxiliaryExecutable: "iterm2-bitwarden-adapter")!
        _bitwarden = AdapterPasswordDataSource(browser: browser,
                                               adapterPath: bitwardenPath,
                                               identifier: "Bitwarden")

        let keeperPath = Bundle(for: Self.self).path(forAuxiliaryExecutable: "iterm2-keeper-adapter")!
        _keeper = AdapterPasswordDataSource(browser: browser,
                                            adapterPath: keeperPath,
                                            identifier: "Keeper Security")
        #if ITERM_DEBUG
        let testAdapterPath = Bundle(for: Self.self).path(forAuxiliaryExecutable: "iterm2-test-adapter")!
        _testAdapter = AdapterPasswordDataSource(browser: browser,
                                                 adapterPath: testAdapterPath,
                                                 identifier: "Test Adapter")
        #endif

        self.browser = browser

        super.init()

        dataSourceType = preferredDataSource
    }

    var preferredDataSource: DataSource {
        get {
            let rawValue = iTermUserDefaults.userDefaults().string(forKey: dataSourceNameUserDefaultsKey) ?? ""
            return DataSource(rawValue: rawValue) ?? DataSource.defaultValue
        }
        set {
            iTermUserDefaults.userDefaults().set(newValue.rawValue, forKey: dataSourceNameUserDefaultsKey)
            _dataSource = nil
        }
    }

    @objc var dataSource: PasswordManagerDataSource? {
        guard authenticated else {
            return nil
        }
        guard let existing = _dataSource else {
            let fresh = { () -> PasswordManagerDataSource in
                switch preferredDataSource {
                case .keychain:
                    return keychain!
                case .onePassword:
                    return onePassword!
                case .lastPass:
                    return lastPass!
                case .keePassXC:
                    return keePassXC!
                case .bitwarden:
                    return bitwarden!
                case .keeper:
                    return keeper!
                #if ITERM_DEBUG
                case .testAdapter:
                    return testAdapter!
                #endif
                }
            }()
            _dataSource = fresh
            return fresh
        }
        return existing
    }

    @objc func enableKeePassXC() {
        preferredDataSource = .keePassXC
    }

    @objc var keePassXCEnabled: Bool {
        return preferredDataSource == .keePassXC
    }

    @objc func enableBitwarden() {
        preferredDataSource = .bitwarden
    }

    @objc var bitwardenEnabled: Bool {
        return preferredDataSource == .bitwarden
    }

    @objc func enableKeychain() {
        preferredDataSource = .keychain
    }

    @objc var keychainEnabled: Bool {
        return preferredDataSource == .keychain
    }

    @objc func enable1Password() {
        preferredDataSource = .onePassword
    }

    @objc var onePasswordEnabled: Bool {
        return preferredDataSource == .onePassword
    }

    @objc func enableLastPass() {
        preferredDataSource = .lastPass
    }

    @objc var lastPassEnabled: Bool {
        return preferredDataSource == .lastPass
    }

    @objc func enableKeeper() {
        preferredDataSource = .keeper
    }

    @objc var keeperEnabled: Bool {
        return preferredDataSource == .keeper
    }

    @objc var keychain: PasswordManagerDataSource? {
        if !authenticated {
            return nil
        }
        return _keychain
    }

    private var onePassword: OnePasswordDataSource? {
        if !authenticated {
            return nil
        }
        return _onePassword
    }

    private var lastPass: LastPassDataSource? {
        if !authenticated {
            return nil
        }
        return _lastPass
    }

    private var keePassXC: AdapterPasswordDataSource? {
        if !authenticated {
            return nil
        }
        return _keePassXC
    }

    private var bitwarden: AdapterPasswordDataSource? {
        if !authenticated {
            return nil
        }
        return _bitwarden
    }

    private var keeper: AdapterPasswordDataSource? {
        if !authenticated {
            return nil
        }
        return _keeper
    }
    #if ITERM_DEBUG
    private var testAdapter: AdapterPasswordDataSource? {
        if !authenticated {
            return nil
        }
        return _testAdapter
    }

    @objc func enableTestAdapter() {
        preferredDataSource = .testAdapter
    }

    @objc var testAdapterEnabled: Bool {
        return preferredDataSource == .testAdapter
    }
    #endif
    @objc func revokeAuthentication() {
        authenticated = false
    }

    @objc func requestAuthenticationIfNeeded(_ completion: @escaping (Bool) -> ()) {
        if authenticated {
            completion(true)
            return
        }
        if !SecureUserDefaults.instance.requireAuthToOpenPasswordmanager.value {
            authenticated = true
            completion(true)
            return
        }
        let context = LAContext()
        let policy = LAPolicy.deviceOwnerAuthentication
        var error: NSError? = nil
        if !context.canEvaluatePolicy(policy, error: &error) {
            RLog("Can't evaluate \(policy): \(error?.localizedDescription ?? "(nil)")")
            // Authentication is impossible here (no biometrics/passcode, MDM-restricted).
            // Report failure so callers don't hang or silently drop the requested action
            // waiting on a completion that would otherwise never fire.
            completion(false)
            return
        }
        iTermApplication.shared().localAuthenticationDialogOpen = true
        let reason = String(localized: "ui.swift.passwordmanager.passwordmanagerdatasourceprovider.open_the_password_manager.2694f46a", defaultValue: "open the password manager", bundle: .main, comment: "User-facing text in PasswordManagerDataSourceProvider.")
        context.evaluatePolicy(policy, localizedReason: reason) { success, error in
            RLog("Policy evaluation success=\(success) error=\(String(describing: error))")
            DispatchQueue.main.async {
                iTermApplication.shared().localAuthenticationDialogOpen = false
                if success {
                    self.authenticated = true
                    completion(true)
                } else {
                    self.authenticated = false
                    if let error = error as NSError?, (error.code != LAError.systemCancel.rawValue &&
                                                       error.code != LAError.appCancel.rawValue) {
                        self.showError(error)
                    }
                    completion(false)
                }
            }
        }
    }

    @objc func consolidateAvailabilityChecks(_ block: () -> ()) {
        if let dataSource = dataSource {
            dataSource.consolidateAvailabilityChecks(block)
            return
        }
        block()
    }

    private func showError(_ error: NSError) {
        let alert = NSAlert()
        let reason: String
        switch LAError.Code(rawValue: error.code) {
        case .authenticationFailed:
            reason = String(localized: "ui.swift.passwordmanager.passwordmanagerdatasourceprovider.valid_credentials_weren_t_supplied.0421cbfe", defaultValue: "valid credentials weren't supplied.", bundle: .main, comment: "User-facing text in PasswordManagerDataSourceProvider.");

        case .userCancel:
            reason = String(localized: "ui.swift.passwordmanager.passwordmanagerdatasourceprovider.password_entry_was_cancelled.b583c702", defaultValue: "password entry was cancelled.", bundle: .main, comment: "User-facing text in PasswordManagerDataSourceProvider.");

        case .userFallback:
            reason = String(localized: "ui.swift.passwordmanager.passwordmanagerdatasourceprovider.password_authentication_was_requested.19bddd18", defaultValue: "password authentication was requested.", bundle: .main, comment: "User-facing text in PasswordManagerDataSourceProvider.");

        case .systemCancel:
            reason = String(localized: "ui.swift.passwordmanager.passwordmanagerdatasourceprovider.the_system_cancelled_the_authentication_request.2d1207ce", defaultValue: "the system cancelled the authentication request.", bundle: .main, comment: "User-facing text in PasswordManagerDataSourceProvider.");

        case .passcodeNotSet:
            reason = String(localized: "ui.swift.passwordmanager.passwordmanagerdatasourceprovider.no_passcode_is_set.c7ebb79c", defaultValue: "no passcode is set.", bundle: .main, comment: "User-facing text in PasswordManagerDataSourceProvider.");

        case .touchIDNotAvailable:
            reason = String(localized: "ui.swift.passwordmanager.passwordmanagerdatasourceprovider.touch_id_is_not_available.82d3a6a9", defaultValue: "touch ID is not available.", bundle: .main, comment: "User-facing text in PasswordManagerDataSourceProvider.");

        case .biometryNotEnrolled:
            reason = String(localized: "ui.swift.passwordmanager.passwordmanagerdatasourceprovider.touch_id_doesn_t_have_any_fingers_enrolled.7b0ecfa6", defaultValue: "touch ID doesn't have any fingers enrolled.", bundle: .main, comment: "User-facing text in PasswordManagerDataSourceProvider.");

        case .biometryLockout:
            reason = String(localized: "ui.swift.passwordmanager.passwordmanagerdatasourceprovider.there_were_too_many_failed_touch_id_attempts.e52e18cc", defaultValue: "there were too many failed Touch ID attempts.", bundle: .main, comment: "User-facing text in PasswordManagerDataSourceProvider.");

        case .appCancel:
            reason = String(localized: "ui.swift.passwordmanager.passwordmanagerdatasourceprovider.authentication_was_cancelled_by_iterm2.1f051b75", defaultValue: "authentication was cancelled by iTerm2.", bundle: .main, comment: "User-facing text in PasswordManagerDataSourceProvider.");

        case .invalidContext:
            reason = String(localized: "ui.swift.passwordmanager.passwordmanagerdatasourceprovider.the_context_is_invalid_this_is_a_bug.db20b08c", defaultValue: "the context is invalid. This is a bug in iTerm2. Please report it.", bundle: .main, comment: "User-facing text in PasswordManagerDataSourceProvider.");

        case .none:
            reason = error.localizedDescription

        case .touchIDNotEnrolled:
            reason = String(localized: "ui.swift.passwordmanager.passwordmanagerdatasourceprovider.touch_id_is_not_enrolled.cb3e2e58", defaultValue: "touch ID is not enrolled.", bundle: .main, comment: "User-facing text in PasswordManagerDataSourceProvider.")

        case .touchIDLockout:
            reason = String(localized: "ui.swift.passwordmanager.passwordmanagerdatasourceprovider.touch_id_is_locked_out.53eadca4", defaultValue: "touch ID is locked out.", bundle: .main, comment: "User-facing text in PasswordManagerDataSourceProvider.")

        case .notInteractive:
            reason = String(localized: "ui.swift.passwordmanager.passwordmanagerdatasourceprovider.the_required_user_interface_could_not_be_displayed.c1d23780", defaultValue: "the required user interface could not be displayed.", bundle: .main, comment: "User-facing text in PasswordManagerDataSourceProvider.")

        case .watchNotAvailable:
            reason = String(localized: "ui.swift.passwordmanager.passwordmanagerdatasourceprovider.watch_is_not_available.8f6e939e", defaultValue: "watch is not available.", bundle: .main, comment: "User-facing text in PasswordManagerDataSourceProvider.")

        case .biometryNotPaired:
            reason = String(localized: "ui.swift.passwordmanager.passwordmanagerdatasourceprovider.biometry_is_not_paired.057a660b", defaultValue: "biometry is not paired.", bundle: .main, comment: "User-facing text in PasswordManagerDataSourceProvider.")

        case .biometryDisconnected:
            reason = String(localized: "ui.swift.passwordmanager.passwordmanagerdatasourceprovider.biometry_is_disconnected.195e5881", defaultValue: "biometry is disconnected.", bundle: .main, comment: "User-facing text in PasswordManagerDataSourceProvider.")

        case .invalidDimensions:
            reason = String(localized: "ui.swift.passwordmanager.passwordmanagerdatasourceprovider.invalid_dimensions_given.3ff2dba1", defaultValue: "invalid dimensions given.", bundle: .main, comment: "User-facing text in PasswordManagerDataSourceProvider.")

        @unknown default:
            reason = error.localizedDescription
        }
        alert.messageText = String(localized: "ui.swift.passwordmanager.passwordmanagerdatasourceprovider.authentication_failed.1a195253", defaultValue: "Authentication Failed", bundle: .main, comment: "User-facing text in PasswordManagerDataSourceProvider.")
        alert.informativeText = String(localized: "ui.swift.passwordmanager.passwordmanagerdatasourceprovider.authentication_failed_because_0.30527adf", defaultValue: "Authentication failed because \(reason)", bundle: .main, comment: "User-facing text in PasswordManagerDataSourceProvider.")
        alert.addButton(withTitle: String(localized: "ui.swift.passwordmanager.passwordmanagerdatasourceprovider.ok.565339bc", defaultValue: "OK", bundle: .main, comment: "User-facing text in PasswordManagerDataSourceProvider."))
        alert.runModal()
    }
}

