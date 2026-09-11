import XCTest
@testable import iTerm2SharedARC

final class ConductorFileTransferLocalizationTests: XCTestCase {
    @MainActor
    private final class NoTransferDelegate: ConductorFileTransferDelegate {
        func beginDownload(fileTransfer: ConductorFileTransfer) {
            XCTFail("Path inspection must not start a download")
        }

        func beginUpload(fileTransfer: ConductorFileTransfer) {
            XCTFail("Path inspection must not start an upload")
        }
    }

    @MainActor
    private lazy var transferDelegate = NoTransferDelegate()

    @MainActor
    private final class RecordingTransfer: ConductorFileTransfer {
        var reportedErrors: [String] = []

        override func didFailWithError(_ error: String) {
            // Replace only the user-notification sink. The real Conductor
            // failure and FileTransferManager logging/callback still run.
            reportedErrors.append(error)
        }
    }

    @MainActor
    private func transfer(localPath: String?, data: Data?) -> RecordingTransfer {
        let remote = SCPPath()
        remote.hostname = "test.invalid"
        remote.username = "synthetic"
        remote.path = "/synthetic-upload"
        return RecordingTransfer(path: remote,
                                 localPath: localPath,
                                 data: data,
                                 delegate: transferDelegate)
    }

    @MainActor
    func testInMemoryLocalPathDoesNotFollowUILanguage() throws {
        for bytes in [Data(), Data([0, 255])] {
            let file = transfer(localPath: nil, data: bytes)
            let path = try XCTUnwrap(file.localPath())
            XCTAssertEqual(path, "(In memory)")
            // The existing menu's Open and Show in Finder actions pass this
            // getter to fileURLWithPath, so it is not a display-only label.
            XCTAssertEqual(URL(fileURLWithPath: path).lastPathComponent, "(In memory)")
        }
    }

    @MainActor
    func testDataKeepsOriginalPrecedenceOverLocalFilePath() {
        let file = transfer(localPath: "/synthetic/not-read.txt", data: Data([1]))
        XCTAssertEqual(file.localPath(), "(In memory)")
    }

    @MainActor
    func testDiskPathPreservesUserText() {
        let path = "/synthetic/Example 文件.txt"
        XCTAssertEqual(transfer(localPath: path, data: nil).localPath(), path)
    }

    @MainActor
    func testAbsentDiskPathRemainsNil() {
        XCTAssertNil(transfer(localPath: nil, data: nil).localPath())
    }

    @MainActor
    private func conductor() -> Conductor {
        Conductor("test.invalid", boolArgs: "", dcsID: "diagnostic-test",
                  clientUniqueID: "synthetic", varsToSend: [:], clientVars: [:],
                  initialDirectory: nil, shouldInjectShellIntegration: false, parent: nil)
    }

    // A missing local path fails before opening any file or starting any SSH
    // operation. Exercise the real manager's error storage and completion path.
    @MainActor
    func testMissingDownloadPathPreservesSharedDiagnostic() {
        let file = transfer(localPath: nil, data: nil)
        var results: [String?] = []
        file.completionBlock = { success, message in
            XCTAssertFalse(success)
            results.append(message)
        }
        conductor().beginDownload(fileTransfer: file)
        XCTAssertEqual(file.error(), "No local path specified")
        XCTAssertEqual(file.reportedErrors, ["No local path specified"])
        XCTAssertEqual(results, ["No local path specified"])
        XCTAssertNil(file.completionBlock)
    }

    @MainActor
    func testMissingUploadPathPreservesSharedDiagnostic() {
        let file = transfer(localPath: nil, data: nil)
        var results: [String?] = []
        file.completionBlock = { success, message in
            XCTAssertFalse(success)
            results.append(message)
        }
        conductor().beginUpload(fileTransfer: file)
        XCTAssertEqual(file.error(), "No local filename specified")
        XCTAssertEqual(file.reportedErrors, ["No local filename specified"])
        XCTAssertEqual(results, ["No local filename specified"])
        XCTAssertNil(file.completionBlock)
    }
}
