import XCTest
@testable import iTerm2SharedARC

final class NerdFontInstallerTests: XCTestCase {
    func testDownloadFailureKeepsStableDiagnosticReason() {
        let error = NerdFontInstallerError.downloadFailed(
            reason: "Localized reason",
            diagnosticReason: "Stable reason")

        XCTAssertEqual(
            error.diagnosticDescription,
            "Download failed: Stable reason")
    }

    func testFontInstallationFailureKeepsStableDiagnosticReason() {
        let error = NerdFontInstallerError.fontInstallationFailed(
            reason: "Localized reason",
            diagnosticReason: "Stable reason")

        XCTAssertEqual(
            error.diagnosticDescription,
            "Installation of downloaded fonts failed: Stable reason")
    }
}
