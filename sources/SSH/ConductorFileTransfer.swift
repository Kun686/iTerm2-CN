//
//  ConductorFileTransfer.swift
//  iTerm2SharedARC
//
//  Created by George Nachman on 2/2/23.
//

import Foundation

@MainActor
protocol ConductorFileTransferDelegate: AnyObject {
    func beginDownload(fileTransfer: ConductorFileTransfer)
    func beginUpload(fileTransfer: ConductorFileTransfer)
}

@MainActor
@objc
class ConductorFileTransfer: TransferrableFile {
    @objc var path: SCPPath
    weak var delegate: ConductorFileTransferDelegate?
    private var _error = ""
    private var _localPath: String?
    let data: Data?

    private enum State {
        case idle
        case downloading
        case uploading
        case downloadComplete
        case uploadComplete
        case failed
    }
    private var state = State.idle

    init(path: SCPPath,
         localPath: String?,
         data: Data?,
         delegate: ConductorFileTransferDelegate) {
        self.path = path
        self.data = data
        self._localPath = localPath
        self.delegate = delegate
    }

    override func displayName() -> String? {
        let username = path.username ?? String(localized: "ui.swift.ssh.conductorfiletransfer.unknown.8fe7794d", defaultValue: "(unknown)", bundle: .main, comment: "Fallback user name in the file-transfer summary.")
        return String(localized: "ui.swift.ssh.conductorfiletransfer.iterm2_ssh_integration_protocol_user_name_0_host.169107a6", defaultValue: """
        iTerm2 SSH Integration Protocol
        User name: \(username)")
        Host: \(path.hostname!)
        File: \(path.path!)"
        """, bundle: .main, comment: "User-facing SSH Integration file-transfer summary.")
    }

    override func shortName() -> String? {
        return path.path.lastPathComponent
    }

    override func subheading() -> String? {
        String(localized: "ui.swift.ssh.conductorfiletransfer.0_via_ssh_integration.8acd2af9", defaultValue: "\(path.hostname!) via SSH Integration", bundle: .main, comment: "User-facing file-transfer subheading.")
    }

    override func authRequestor() -> String? {
        if let username = path.username {
            return username + "@" + path.hostname!
        }
        return path.hostname!
    }

    override func protocolName() -> String? {
        return String(localized: "ui.swift.ssh.conductorfiletransfer.ssh_integration.2de7a54f", defaultValue: "SSH Integration", bundle: .main, comment: "User-facing text in ConductorFileTransfer.")
    }

    private var chunked = false

    func downloadChunked() -> Bool {
        chunked = true
        download()
        return status == .transferring
    }

    override func download() {
        state = .downloading
        status = .starting
        do {
            _localPath = try temporaryFilePath()
            FileTransferManager.sharedInstance().files.add(self)
            FileTransferManager.sharedInstance().transferrableFileDidStartTransfer(self)
            status = .transferring
            if !chunked {
                delegate?.beginDownload(fileTransfer: self)
            }
        } catch {
            state = .failed
        }
    }

    private func temporaryFilePath() throws -> String {
        guard let downloads = FileManager.default.downloadsDirectory() else {
            throw ConductorFileTransferError(String(localized: "ui.swift.ssh.conductorfiletransfer.unable_to_find_downloads_folder.dd7d6558", defaultValue: "Unable to find Downloads folder", bundle: .main, comment: "User-facing file-transfer error."))
        }
        let tempFileName = ".iTerm2.\(UUID().uuidString)"
        return downloads.appendingPathComponent(tempFileName)
    }

    final class ConductorFileTransferError: NSObject, LocalizedError {
        private let reason: String
        init(_ reason: String) {
            self.reason = reason
        }
        override var description: String {
            get {
                return reason
            }
        }
        var errorDescription: String? {
            get {
                return reason
            }
        }
    }

    func fail(reason: String) {
        _error = reason
        FileTransferManager.sharedInstance().transferrableFile(self, didFinishTransmissionWithError: ConductorFileTransferError(reason))
        state = .failed
    }

    private var url: URL {
        let components = NSURLComponents()
        components.host = path.hostname
        components.user = path.username
        components.path = path.path
        components.scheme = "ssh"
        return components.url!
    }

    @MainActor
    func didTransferBytes(_ count: UInt) {
        self.bytesTransferred = self.bytesTransferred + count
        if status == .transferring {
            FileTransferManager.sharedInstance().transferrableFileProgressDidChange(self)
        }
    }

    @MainActor
    func abort() {
        FileTransferManager.sharedInstance().transferrableFileDidStopTransfer(self)
    }

    @MainActor
    func didFinishSuccessfully() {
        if state == .downloading {
            if !quarantine(_localPath, sourceURL: url) {
                _error = String(localized: "ui.swift.ssh.conductorfiletransfer.failed_to_quarantine.0bbc1c5a", defaultValue: "Failed to quarantine", bundle: .main, comment: "User-facing file-transfer error.")
                FileTransferManager.sharedInstance().transferrableFile(self, didFinishTransmissionWithError: ConductorFileTransferError(_error))
                return
            }
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: _localPath!) else {
                _error = String(localized: "ui.swift.ssh.conductorfiletransfer.could_not_get_attributes_of_0.f8f6dbb3", defaultValue: "Could not get attributes of \(_localPath!)", bundle: .main, comment: "User-facing file-transfer error.")
                FileTransferManager.sharedInstance().transferrableFile(self, didFinishTransmissionWithError: ConductorFileTransferError(_error))
                return
            }
            let size = attributes[FileAttributeKey.size] as? UInt ?? 0
            self.bytesTransferred = size
            self.fileSize = Int(size)

            let finalDestination = self.finalDestination(
                forPath: path.path.lastPathComponent,
                destinationDirectory: _localPath!.deletingLastPathComponent,
                prompt: true)!
            do {
                if FileManager.default.fileExists(atPath: finalDestination) {
                    try FileManager.default.replaceItem(at: URL(fileURLWithPath: finalDestination),
                                                        withItemAt: URL(fileURLWithPath: _localPath!),
                                                        backupItemName: nil,
                                                        resultingItemURL: nil)
                } else {
                    try FileManager.default.moveItem(at: URL(fileURLWithPath: _localPath!),
                                                     to: URL(fileURLWithPath: finalDestination))
                }
            } catch {
                _error = error.localizedDescription
            }
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: _localPath!))
            _localPath = finalDestination
            state = .downloadComplete
            FileTransferManager.sharedInstance().transferrableFile(
                self,
                didFinishTransmissionWithError: nil)
        } else if state == .uploading {
            state = .uploadComplete
            FileTransferManager.sharedInstance().transferrableFile(
                self,
                didFinishTransmissionWithError: nil)
        }
    }

    // Name for uploads once established.
    var remoteName: String?
    override func destination() -> String? {
        switch state {
        case .downloading, .downloadComplete:
            return _localPath!
        case .uploading, .uploadComplete:
            return remoteName ?? path.path
        case .failed, .idle:
            return path.path
        }
    }

    private func sizeToUpload() -> Int? {
        if let data {
            return data.count
        }
        let path = localPath()!
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: path)
            guard let size = attrs[FileAttributeKey.size] as? Int else {
                _error = String(localized: "ui.swift.ssh.conductorfiletransfer.could_not_get_size_of_file_0.0888025e", defaultValue: "Could not get size of file: \(path)", bundle: .main, comment: "User-facing file-transfer error.")
                state = .failed
                FileTransferManager.sharedInstance().transferrableFile(self, didFinishTransmissionWithError: ConductorFileTransferError(_error))
                return nil
            }
            return size
        } catch {
            _error = String(localized: "ui.swift.ssh.conductorfiletransfer.no_such_file_0.db9e73ae", defaultValue: "No such file: \(path)", bundle: .main, comment: "User-facing file-transfer error.")
            FileTransferManager.sharedInstance().transferrableFile(self, didFinishTransmissionWithError: error)
            state = .failed
            return nil
        }
    }

    override func upload() {
        state = .uploading
        status = .starting
        if let size = sizeToUpload() {
            fileSize = size
        } else {
            return
        }
        FileTransferManager.sharedInstance().files.add(self)
        FileTransferManager.sharedInstance().transferrableFileDidStartTransfer(self)
        status = .transferring
        delegate?.beginUpload(fileTransfer: self)
    }

    override func isDownloading() -> Bool {
        return state == .downloading
    }

    var isStopped: Bool {
        switch state {
        case .downloading, .uploading:
            return false
        default:
            return true
        }
    }

    override func stop() {
        FileTransferManager.sharedInstance().transferrableFileWillStop(self)
        state = .failed
    }

    override func error() -> String? {
        return _error
    }

    override func localPath() -> String? {
        if data != nil {
            return "(In memory)"
        }
        return _localPath
    }
}
