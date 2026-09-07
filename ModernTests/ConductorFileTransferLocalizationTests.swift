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
    private func transfer(localPath: String?, data: Data?) -> ConductorFileTransfer {
        let remote = SCPPath()
        remote.hostname = "test.invalid"
        remote.username = "synthetic"
        remote.path = "/synthetic-upload"
        return ConductorFileTransfer(path: remote,
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
}
