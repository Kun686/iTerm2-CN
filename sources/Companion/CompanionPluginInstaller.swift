//
//  CompanionPluginInstaller.swift
//  iTerm2
//
//  Downloads, installs, and registers the optional AI and companion plugins for
//  the first-run onboarding wizard. Normally these plugins are signed .app
//  bundles the user installs by hand; the wizard removes that step by fetching
//  the zip, unpacking it into Application Support, registering the bundle with
//  LaunchServices (so the existing bundle-id lookup in AIPluginClient /
//  CompanionPlugin finds it with no change to the detection code), and verifying
//  the plugin then loads and signature-checks. Egress trust still comes from the
//  baked-in code signature the plugins verify at load, not from where the bundle
//  lives.
//

import Foundation
import CoreServices

enum CompanionPluginInstallerError: LocalizedError {
    case appSupportUnavailable
    case downloadFailed(String)
    case badResponse(Int)
    case unzipFailed(String)
    case bundleNotFound
    case verificationFailed(String)

    var errorDescription: String? {
        switch self {
        case .appSupportUnavailable:
            return String(localized: "ui.swift.companion.companionplugininstaller.could_not_find_iterm2_s_application_support_directory.067b7abf", defaultValue: "Could not find iTerm2’s Application Support directory.", bundle: .main, comment: "User-facing text in CompanionPluginInstaller.")
        case .downloadFailed(let reason):
            return String(localized: "ui.swift.companion.companionplugininstaller.download_failed_0.7f360187", defaultValue: "Download failed: \(reason)", bundle: .main, comment: "User-facing text in CompanionPluginInstaller.")
        case .badResponse(let code):
            return String(localized: "ui.swift.companion.companionplugininstaller.download_failed_with_http_status_0.d5b4ed3b", defaultValue: "Download failed with HTTP status \(code).", bundle: .main, comment: "User-facing text in CompanionPluginInstaller.")
        case .unzipFailed(let reason):
            return String(localized: "ui.swift.companion.companionplugininstaller.could_not_unpack_the_downloaded_plugin_0.95446eed", defaultValue: "Could not unpack the downloaded plugin: \(reason)", bundle: .main, comment: "User-facing text in CompanionPluginInstaller.")
        case .bundleNotFound:
            return String(localized: "ui.swift.companion.companionplugininstaller.the_downloaded_archive_did_not_contain_a_plugin.cf2b08e2", defaultValue: "The downloaded archive did not contain a plugin.", bundle: .main, comment: "User-facing text in CompanionPluginInstaller.")
        case .verificationFailed(let name):
            return String(localized: "ui.swift.companion.companionplugininstaller.the_0_did_not_load_after_installation.8d90e8e2", defaultValue: "The \(name) did not load after installation.", bundle: .main, comment: "User-facing text in CompanionPluginInstaller.")
        }
    }
}

enum CompanionPluginInstaller {
    private struct Spec {
        let name: String
        let zipURL: URL
        let bundleID: String
    }

    private static let aiSpec = Spec(
        name: String(localized: "ui.swift.companion.companionplugininstaller.ai_plugin.9412826a", defaultValue: "AI plugin", bundle: .main, comment: "User-facing text in CompanionPluginInstaller."),
        zipURL: URL(string: "https://iterm2.com/downloads/ai-plugin/iTermAI-1.1.zip")!,
        bundleID: "com.googlecode.iterm2.iTermAI")

    private static let companionSpec = Spec(
        name: String(localized: "ui.swift.companion.companionplugininstaller.companion_plugin.56041357", defaultValue: "companion plugin", bundle: .main, comment: "User-facing text in CompanionPluginInstaller."),
        zipURL: URL(string: "https://iterm2.com/downloads/companion-plugin/iTermCompanion-1.0.zip")!,
        bundleID: "com.googlecode.iterm2.iTermCompanion")

    /// Download, install, register, and verify the AI plugin. Throws on any
    /// failure (download, unpack, or the plugin not loading afterward).
    static func installAIPlugin() async throws {
        try await downloadUnzipRegister(aiSpec)
        let ok = await waitForSuccess(reload: { Plugin.reload() },
                                      check: { Plugin.instance().isSuccess })
        if !ok {
            throw CompanionPluginInstallerError.verificationFailed(aiSpec.name)
        }
    }

    /// Download, install, register, and verify the companion plugin.
    static func installCompanionPlugin() async throws {
        try await downloadUnzipRegister(companionSpec)
        let ok = await waitForSuccess(reload: { CompanionPlugin.reload() },
                                      check: { CompanionPlugin.instance().isSuccess })
        if !ok {
            throw CompanionPluginInstallerError.verificationFailed(companionSpec.name)
        }
    }

    private static func downloadUnzipRegister(_ spec: Spec) async throws {
        RLog("Companion installer: downloading \(spec.name) from \(spec.zipURL)")
        let tempZip: URL
        let response: URLResponse
        do {
            (tempZip, response) = try await URLSession.shared.download(from: spec.zipURL)
        } catch {
            throw CompanionPluginInstallerError.downloadFailed(error.localizedDescription)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw CompanionPluginInstallerError.badResponse(http.statusCode)
        }

        let fm = FileManager.default
        guard let appSupportString = fm.applicationSupportDirectory() else {
            throw CompanionPluginInstallerError.appSupportUnavailable
        }

        // Move the download out of its auto-purged temporary slot, unpack it into
        // a scratch directory, then locate the .app inside.
        guard let workPath = fm.it_temporaryDirectory() else {
            throw CompanionPluginInstallerError.unzipFailed("no temporary directory")
        }
        let workDir = URL(fileURLWithPath: workPath)
        let zipDest = workDir.appendingPathComponent("plugin.zip")
        let unzipDir = workDir.appendingPathComponent("unzipped")
        do {
            try fm.moveItem(at: tempZip, to: zipDest)
            try fm.createDirectory(at: unzipDir, withIntermediateDirectories: true)
        } catch {
            throw CompanionPluginInstallerError.unzipFailed(error.localizedDescription)
        }
        try await unzip(zipDest, to: unzipDir)

        guard let appURL = findApp(in: unzipDir, fileManager: fm) else {
            throw CompanionPluginInstallerError.bundleNotFound
        }

        // Install into Application Support/Plugins, replacing any prior copy.
        let pluginsDir = URL(fileURLWithPath: appSupportString).appendingPathComponent("Plugins")
        let dest = pluginsDir.appendingPathComponent(appURL.lastPathComponent)
        do {
            try fm.createDirectory(at: pluginsDir, withIntermediateDirectories: true)
            if fm.fileExists(atPath: dest.path) {
                try fm.removeItem(at: dest)
            }
            try fm.moveItem(at: appURL, to: dest)
        } catch {
            throw CompanionPluginInstallerError.unzipFailed(error.localizedDescription)
        }

        // The download carries a quarantine flag; the plugins are never launched
        // as processes (their JS is loaded and signature-checked in-process), but
        // strip it anyway so LaunchServices registration is not second-guessed.
        stripQuarantine(dest)

        // Register the installed copy so NSWorkspace.urlForApplication(bundleID)
        // resolves it. This is what lets the unchanged detection code in the
        // plugin clients find a bundle that lives in Application Support.
        let status = LSRegisterURL(dest as CFURL, true)
        RLog("Companion installer: installed \(spec.name) at \(dest.path); LSRegisterURL status \(status)")
    }

    private static func unzip(_ zip: URL, to destination: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            iTermCommandRunner.unzipURL(zip,
                                        withArguments: ["-q"],
                                        destination: destination.path,
                                        callbackQueue: DispatchQueue.global()) { error in
                if let error {
                    continuation.resume(throwing: CompanionPluginInstallerError.unzipFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Find the first .app bundle within `directory` (top level first, then one
    /// level down, skipping the __MACOSX metadata folder zip writes alongside).
    private static func findApp(in directory: URL, fileManager fm: FileManager) -> URL? {
        let topLevel = (try? fm.contentsOfDirectory(at: directory,
                                                    includingPropertiesForKeys: nil)) ?? []
        if let app = topLevel.first(where: { $0.pathExtension == "app" }) {
            return app
        }
        for child in topLevel where child.lastPathComponent != "__MACOSX" {
            let grandchildren = (try? fm.contentsOfDirectory(at: child,
                                                             includingPropertiesForKeys: nil)) ?? []
            if let app = grandchildren.first(where: { $0.pathExtension == "app" }) {
                return app
            }
        }
        return nil
    }

    private static func stripQuarantine(_ url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-dr", "com.apple.quarantine", url.path]
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            RLog("Companion installer: could not strip quarantine from \(url.path): \(error)")
        }
    }

    /// LaunchServices may not surface a freshly registered bundle immediately, so
    /// re-probe the plugin a few times before declaring failure. The plugin
    /// detection caches a success, so reload() is needed each time to re-probe.
    private static func waitForSuccess(reload: () -> Void, check: () -> Bool) async -> Bool {
        for _ in 0..<10 {
            reload()
            if check() {
                return true
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return false
    }
}
