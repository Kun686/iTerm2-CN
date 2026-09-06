//
//  SecureUserDefaultsTests.swift
//  ModernTests
//

import XCTest
@testable import iTerm2SharedARC

final class SecureUserDefaultsTests: XCTestCase {
    func testAppleScriptStringLiteralRoundTripsPromptText() throws {
        let prompt = "Prompt with \\backslash, \"quotes\", tab\tand lines\r\nnext"
        let source = "return \(iTermAppleScriptStringLiteral(prompt))"
        let script = try XCTUnwrap(NSAppleScript(source: source))
        var error: NSDictionary?

        let result = script.executeAndReturnError(&error)

        XCTAssertNil(error)
        XCTAssertEqual(result.stringValue, prompt)
    }

    func testPrivilegedAppleScriptUsesLocalizedPromptOnlyInExecutableSource() {
        let localizedPrompt = "iTerm2 需要修改安全设置。"
        let diagnosticPrompt = "iTerm2 needs to modify secure settings."
        let body = "umask 077\n/bin/true"

        let sources = iTermPrivilegedAppleScriptSourcePair(
            body: body,
            userFacingPrompt: localizedPrompt,
            diagnosticPrompt: diagnosticPrompt)

        XCTAssertTrue(sources.executable.contains(localizedPrompt))
        XCTAssertFalse(sources.diagnostic.contains(localizedPrompt))
        XCTAssertTrue(sources.diagnostic.contains(diagnosticPrompt))
        XCTAssertTrue(sources.executable.contains(body))
        XCTAssertTrue(sources.diagnostic.contains(body))
    }

    func testStableErrorDiagnosticDoesNotLeakLocalizedDescription() {
        let localizedMessage = "无法写入安全设置。"
        let error = SecureUserDefault<Bool>.SecureUserDefaultError.scriptError(localizedMessage)

        XCTAssertEqual(error.localizedDescription, localizedMessage)
        XCTAssertEqual(iTermSecureUserDefaultsDiagnosticDescription(for: error),
                       "Secure user defaults AppleScript failed.")
        XCTAssertFalse(iTermSecureUserDefaultsDiagnosticDescription(for: error)
            .contains(localizedMessage))
    }

    func testStableErrorDiagnosticUsesDomainAndCodeForExternalErrors() {
        let localizedMessage = "文件不存在。"
        let error = NSError(domain: NSCocoaErrorDomain,
                            code: NSFileNoSuchFileError,
                            userInfo: [NSLocalizedDescriptionKey: localizedMessage])

        XCTAssertEqual(iTermSecureUserDefaultsDiagnosticDescription(for: error),
                       "error domain=NSCocoaErrorDomain code=4")
        XCTAssertFalse(iTermSecureUserDefaultsDiagnosticDescription(for: error)
            .contains(localizedMessage))
    }

    func testAppleScriptDiagnosticUsesOnlyStableErrorNumber() {
        let localizedMessage = "用户已取消。"
        let error: NSDictionary = [
            NSAppleScript.errorNumber: NSNumber(value: -128),
            NSAppleScript.errorBriefMessage: localizedMessage
        ]

        XCTAssertEqual(iTermAppleScriptDiagnostic(error),
                       "AppleScript error number=-128")
        XCTAssertFalse(iTermAppleScriptDiagnostic(error).contains(localizedMessage))
    }
}
