//
//  ICURegexToRailroadConverterLocalizationTests.swift
//  iTerm2 ModernTests
//

import XCTest
@testable import iTerm2SharedARC

final class ICURegexToRailroadConverterLocalizationTests: XCTestCase {
    func testLocalizedLabelsPreserveRailroadGrammar() {
        let patterns = [
            ".", "^$", "(?#comment)", "(?=x)", "(?!x)", "(?<=x)", "(?<!x)",
            "(?>x)", "(?im:x)", "(?im)", #"[^\d]"#,
            #"\a"#, #"\A"#, #"\b"#, #"\B"#, #"\d"#, #"\D"#, #"\e"#,
            #"\f"#, #"\G"#, #"\h"#, #"\H"#, #"\n"#, #"\r"#, #"\R"#,
            #"\s"#, #"\S"#, #"\t"#, #"\v"#, #"\V"#, #"\w"#, #"\W"#,
            #"\X"#, #"\Z"#, #"\z"#, #"\1"#, #"\cA"#,
            "a*?", "a*+", "a+?", "a++", "a??", "a?+", "a{2}?", "a{2}+",
        ]
        let converter = ICURegexToRailroadConverter()

        for pattern in patterns {
            let dsl = converter.convert(pattern)
            XCTAssertTrue(dsl.withCString { railroad_dsl_is_valid($0) },
                          "Invalid railroad DSL for \(pattern): \(dsl)")
        }
    }
}
