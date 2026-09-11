//
//  ICURegexToRailroadConverter.swift
//  iTerm2
//
//  Created by George Nachman on 5/25/25.
//

import Foundation
import WebKit

/// Converts ICU style regular expressions into railroad DSL for visualization
class ICURegexToRailroadConverter {

    private enum Label {
        static let anyCharacter = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.any_character.0382b1f3", defaultValue: "any character", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let startOfLine = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.start_of_line.6e2b24aa", defaultValue: "start of line", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let endOfLine = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.end_of_line.7655a5b4", defaultValue: "end of line", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let comment = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.comment.c44bb2fd", defaultValue: "comment", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let flags = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.flags.2934fb49", defaultValue: "flags", bundle: .main, comment: "Visible label for regular-expression flags in a railroad diagram.")
        static let atomic = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.atomic.fd43322a", defaultValue: "atomic", bundle: .main, comment: "Visible label for an atomic regular-expression group.")
        static let lookahead = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.lookahead.ce9a8bb4", defaultValue: "lookahead", bundle: .main, comment: "Visible label for a positive lookahead assertion.")
        static let negativeLookahead = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.negative_lookahead.8bbf4689", defaultValue: "negative lookahead", bundle: .main, comment: "Visible label for a negative lookahead assertion.")
        static let lookbehind = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.lookbehind.e7d87dd7", defaultValue: "lookbehind", bundle: .main, comment: "Visible label for a positive lookbehind assertion.")
        static let negativeLookbehind = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.negative_lookbehind.a2fad949", defaultValue: "negative lookbehind", bundle: .main, comment: "Visible label for a negative lookbehind assertion.")
        static let not = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.not.254bb97b", defaultValue: "not", bundle: .main, comment: "Visible negation label in a regular-expression railroad diagram.")
        static let bell = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.bell.f683740c", defaultValue: "bell", bundle: .main, comment: "Visible label for the bell character in a regular-expression railroad diagram.")
        static let startOfInput = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.start_of_input.8add6f8f", defaultValue: "start of input", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let wordBoundary = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.word_boundary.85f13795", defaultValue: "word boundary", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let nonWordBoundary = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.non_word_boundary.6fe535fd", defaultValue: "non-word boundary", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let digit = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.digit.95ff34cf", defaultValue: "digit", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let nonDigit = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.non_digit.527a4572", defaultValue: "non-digit", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let escape = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.escape.b3140286", defaultValue: "escape", bundle: .main, comment: "Visible label for the escape character in a regular-expression railroad diagram.")
        static let formFeed = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.form_feed.8e47ed66", defaultValue: "form feed", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let endOfPreviousMatch = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.end_of_previous_match.d777b45e", defaultValue: "end of previous match", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let horizontalWhitespace = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.horizontal_whitespace.278b3873", defaultValue: "horizontal whitespace", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let nonHorizontalWhitespace = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.non_horizontal_whitespace.35cb5862", defaultValue: "non-horizontal whitespace", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let lineFeed = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.line_feed.46f77b43", defaultValue: "line feed", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let carriageReturn = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.carriage_return.609c910e", defaultValue: "carriage return", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let newline = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.newline.ea889d83", defaultValue: "newline", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let whitespace = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.whitespace.6db1c4fb", defaultValue: "whitespace", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let nonWhitespace = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.non_whitespace.6c820459", defaultValue: "non-whitespace", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let tab = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.tab.7508386a", defaultValue: "tab", bundle: .main, comment: "Visible label for the tab character in a regular-expression railroad diagram.")
        static let verticalWhitespace = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.vertical_whitespace.0b3ad312", defaultValue: "vertical whitespace", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let nonVerticalWhitespace = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.non_vertical_whitespace.61fa32f4", defaultValue: "non-vertical whitespace", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let wordCharacter = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.word_character.03d81287", defaultValue: "word character", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let nonWordCharacter = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.non_word_character.579838e7", defaultValue: "non-word character", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let graphemeCluster = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.grapheme_cluster.f4524f88", defaultValue: "grapheme cluster", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let endOfInputBeforeFinalNewline = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.end_of_input_before_final_newline.1d28e424", defaultValue: "end of input (before final newline)", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let endOfInput = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.end_of_input.e6d428a0", defaultValue: "end of input", bundle: .main, comment: "Visible label in a regular-expression railroad diagram.")
        static let group = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.group.ad936fcb", defaultValue: "group", bundle: .main, comment: "Visible label for a numbered regular-expression capture group.")
        static let control = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.control.0fcd568a", defaultValue: "control", bundle: .main, comment: "Visible label for a control character in a regular-expression railroad diagram.")
        static let lazy = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.lazy.81fd67d0", defaultValue: "lazy", bundle: .main, comment: "Visible label for a lazy regular-expression quantifier.")
        static let possessive = String(localized: "ui.swift.regexvisualization.icuregextorailroadconverter.possessive.f64df5ab", defaultValue: "possessive", bundle: .main, comment: "Visible label for a possessive regular-expression quantifier.")
    }

    // MARK: - Types

    enum Token {
        case literal(String)
        case metachar(String)
        case charClass(String)
        case group(String)
        case quantifier(String)
        case anchor(String)
        case alternation
        case escaped(String)
    }

    // MARK: - Properties

    private var input: String
    private var position: String.Index

    // MARK: - Initialization

    init() {
        self.input = ""
        self.position = self.input.startIndex
    }

    // MARK: - Public Methods

    /// Converts an ICU regex pattern to railroad DSL
    func convert(_ pattern: String) -> String {
        self.input = pattern
        self.position = pattern.startIndex

        let result = parseAlternation()
        return result
    }

    // MARK: - Parsing Methods

    private func parseAlternation() -> String {
        var alternatives: [String] = []
        var current = parseSequence()

        while hasMore() && peek() == "|" {
            alternatives.append(current)
            advance() // consume |
            current = parseSequence()
        }

        if alternatives.isEmpty {
            return current
        } else {
            alternatives.append(current)
            // <...> is for choices/alternatives and uses commas
            return "<\(alternatives.joined(separator: ", "))>"
        }
    }

    private func parseSequence() -> String {
        var elements: [String] = []
        var currentLiteral = ""

        while hasMore() && peek() != "|" && peek() != ")" {
            let element = parseElement()

            if let elem = element {
                // Check if this element is a single unquoted character
                // (returned by parseElement when it's a literal without quantifier)
                if elem.count == 1 && !elem.contains("\"") && !elem.contains("'") && !elem.contains("`") {
                    // This is a raw character - accumulate it
                    currentLiteral.append(elem)
                } else if elem.count == 1 {
                    // This is a single character that needs escaping (like a quote)
                    // Flush any accumulated literals first
                    if !currentLiteral.isEmpty {
                        elements.append("\"\(escapeForTerminal(currentLiteral))\"")
                        currentLiteral = ""
                    }
                    // Add the single character as a properly escaped element
                    elements.append("\"\(escapeForTerminal(elem))\"")
                } else {
                    // This is a complete element (quoted, quantified, etc.)
                    // Flush any accumulated literals first
                    if !currentLiteral.isEmpty {
                        elements.append("\"\(escapeForTerminal(currentLiteral))\"")
                        currentLiteral = ""
                    }
                    elements.append(elem)
                }
            }
        }

        // Flush any remaining literals
        if !currentLiteral.isEmpty {
            elements.append("\"\(escapeForTerminal(currentLiteral))\"")
        }

        if elements.isEmpty {
            return "!"
        } else if elements.count == 1 {
            return elements[0]
        } else {
            return "{\(elements.joined(separator: ", "))}"
        }
    }

    private func parseElement() -> String? {
        guard hasMore() else { return nil }

        let char = peek()

        switch char {
        case "(":
            return parseGroup()
        case "[":
            return parseCharacterClass()
        case "\\":
            return parseEscape()
        case ".":
            advance()
            return applyQuantifier("\"[\(Label.anyCharacter)]\"")
        case "^":
            advance()
            return "`\(Label.startOfLine)`"
        case "$":
            advance()
            return "`\(Label.endOfLine)`"
        case "*", "+", "?", "{":
            // Quantifier without preceding element - invalid regex
            advance()
            return nil
        case ")":
            // End of group - let parent handle
            return nil
        default:
            // Literal character - return it without quotes for now
            // The sequence parser will handle grouping literals together
            advance()

            // Check if there's a quantifier following this literal
            if hasMore() && isQuantifier(peek()) {
                return applyQuantifier("\"\(escapeForTerminal(String(char)))\"")
            }

            // Return the literal - parseSequence will handle grouping
            return String(char)
        }
    }

    private func isQuantifier(_ char: Character) -> Bool {
        return char == "*" || char == "+" || char == "?" || char == "{"
    }

    private func parseGroup() -> String {
        advance() // consume (

        var groupType = "capture"
        var groupName = ""
        var content = ""

        if hasMore() && peek() == "?" {
            advance() // consume ?
            if hasMore() {
                let next = peek()
                switch next {
                case ":":
                    advance()
                    groupType = "non-capture"
                case ">":
                    advance()
                    groupType = "atomic"
                case "=":
                    advance()
                    groupType = "lookahead"
                case "!":
                    advance()
                    groupType = "negative-lookahead"
                case "#":
                    // Comment group
                    advance()
                    while hasMore() && peek() != ")" {
                        advance()
                    }
                    if hasMore() { advance() } // consume )
                    return "`\(Label.comment)`"
                case "<":
                    advance()
                    if hasMore() {
                        let lookBehindType = peek()
                        if lookBehindType == "=" {
                            advance()
                            groupType = "lookbehind"
                        } else if lookBehindType == "!" {
                            advance()
                            groupType = "negative-lookbehind"
                        } else {
                            // Named capture group
                            var name = ""
                            while hasMore() && peek() != ">" {
                                name.append(peek())
                                advance()
                            }
                            if hasMore() { advance() } // consume >
                            groupType = "named"
                            groupName = name
                        }
                    }
                default:
                    // Flag settings
                    if isFlag(next) || next == "-" {
                        var flags = ""
                        while hasMore() && peek() != ":" && peek() != ")" {
                            flags.append(peek())
                            advance()
                        }
                        if hasMore() && peek() == ":" {
                            advance()
                            groupType = "flags"
                            groupName = flags
                        } else {
                            // Flag change without group
                            if hasMore() { advance() } // consume )
                            return "`\(Label.flags): \(flags)`"
                        }
                    }
                }
            }
        }

        // Parse group content
        content = parseAlternation()

        if hasMore() && peek() == ")" {
            advance() // consume )
        }

        // Apply annotations based on group type
        var result = content

        switch groupType {
        case "capture":
            // Regular capture group - add annotation for group number if needed
            // For now, just return the content
            break
        case "non-capture":
            // Non-capturing group - no annotation needed
            break
        case "named":
            // Named capture group - add the name as annotation
            result = "\(content)#`\(groupName)`"
        case "atomic":
            result = "\(content)#`\(Label.atomic)`"
        case "lookahead":
            result = "\(content)#`\(Label.lookahead)`"
        case "negative-lookahead":
            result = "\(content)#`\(Label.negativeLookahead)`"
        case "lookbehind":
            result = "\(content)#`\(Label.lookbehind)`"
        case "negative-lookbehind":
            result = "\(content)#`\(Label.negativeLookbehind)`"
        case "flags":
            result = "\(content)#`\(Label.flags): \(groupName)`"
        default:
            break
        }

        return applyQuantifier(result)
    }

    private func parseCharacterClass() -> String {
        advance() // consume [

        var isNegated = false
        var elements: [String] = []

        if hasMore() && peek() == "^" {
            isNegated = true
            advance()
        }

        while hasMore() && peek() != "]" {
            if peek() == "\\" {
                advance()
                if hasMore() {
                    let escaped = peek()
                    advance()
                    elements.append(handleEscapeInClass(escaped))
                }
            } else if peek() == "[" && peekAhead() == ":" {
                // POSIX-style property
                var posixClass = ""
                advance() // [
                advance() // :
                while hasMore() && !(peek() == ":" && peekAhead() == "]") {
                    posixClass.append(peek())
                    advance()
                }
                if hasMore() { advance() } // :
                if hasMore() { advance() } // ]
                elements.append("\"[\(posixClass)]\"")
            } else {
                let char = peek()
                advance()

                // Check for range
                if hasMore() && peek() == "-" && peekAhead() != "]" {
                    advance() // consume -
                    if hasMore() {
                        let endChar = peek()
                        advance()
                        elements.append("\"[\(char)-\(endChar)]\"")
                    }
                } else {
                    elements.append("\"\(escapeForTerminal(String(char)))\"")
                }
            }
        }

        if hasMore() && peek() == "]" {
            advance() // consume ]
        }

        // Character classes are choices, so use <...> with commas
        let classContent = elements.isEmpty ? "!" : "<\(elements.joined(separator: ", "))>"
        let result = isNegated ? "{`\(Label.not)`, \(classContent)}" : classContent
        return applyQuantifier(result)
    }

    private func parseEscape() -> String {
        advance() // consume \

        guard hasMore() else { return "\"\\\\\"" }

        let escaped = peek()
        advance()

        switch escaped {
            // Special sequences
        case "a": return applyQuantifier("\"[\(Label.bell)]\"")
        case "A": return "`\(Label.startOfInput)`"
        case "b": return "`\(Label.wordBoundary)`"
        case "B": return "`\(Label.nonWordBoundary)`"
        case "d": return applyQuantifier("\"[\(Label.digit)]\"")
        case "D": return applyQuantifier("\"[\(Label.nonDigit)]\"")
        case "e": return applyQuantifier("\"[\(Label.escape)]\"")
        case "f": return applyQuantifier("\"[\(Label.formFeed)]\"")
        case "G": return "`\(Label.endOfPreviousMatch)`"
        case "h": return applyQuantifier("\"[\(Label.horizontalWhitespace)]\"")
        case "H": return applyQuantifier("\"[\(Label.nonHorizontalWhitespace)]\"")
        case "n": return applyQuantifier("\"[\(Label.lineFeed)]\"")
        case "r": return applyQuantifier("\"[\(Label.carriageReturn)]\"")
        case "R": return applyQuantifier("\"[\(Label.newline)]\"")
        case "s": return applyQuantifier("\"[\(Label.whitespace)]\"")
        case "S": return applyQuantifier("\"[\(Label.nonWhitespace)]\"")
        case "t": return applyQuantifier("\"[\(Label.tab)]\"")
        case "v": return applyQuantifier("\"[\(Label.verticalWhitespace)]\"")
        case "V": return applyQuantifier("\"[\(Label.nonVerticalWhitespace)]\"")
        case "w": return applyQuantifier("\"[\(Label.wordCharacter)]\"")
        case "W": return applyQuantifier("\"[\(Label.nonWordCharacter)]\"")
        case "X": return applyQuantifier("\"[\(Label.graphemeCluster)]\"")
        case "Z": return "`\(Label.endOfInputBeforeFinalNewline)`"
        case "z": return "`\(Label.endOfInput)`"

            // Unicode escapes
        case "u":
            var hex = ""
            for _ in 0..<4 {
                if hasMore() && isHexDigit(peek()) {
                    hex.append(peek())
                    advance()
                }
            }
            return applyQuantifier("\"[U+\(hex)]\"")

        case "U":
            var hex = ""
            for _ in 0..<8 {
                if hasMore() && isHexDigit(peek()) {
                    hex.append(peek())
                    advance()
                }
            }
            return applyQuantifier("\"[U+\(hex)]\"")

        case "x":
            if hasMore() && peek() == "{" {
                advance() // consume {
                var hex = ""
                while hasMore() && peek() != "}" {
                    hex.append(peek())
                    advance()
                }
                if hasMore() { advance() } // consume }
                return applyQuantifier("\"[U+\(hex)]\"")
            } else {
                var hex = ""
                for _ in 0..<2 {
                    if hasMore() && isHexDigit(peek()) {
                        hex.append(peek())
                        advance()
                    }
                }
                return applyQuantifier("\"[U+\(hex)]\"")
            }

            // Named character
        case "N":
            if hasMore() && peek() == "{" {
                advance() // consume {
                var name = ""
                while hasMore() && peek() != "}" {
                    name.append(peek())
                    advance()
                }
                if hasMore() { advance() } // consume }
                return applyQuantifier("\"[\(name)]\"")
            }
            return applyQuantifier("\"N\"")

            // Properties
        case "p", "P":
            let isNegated = escaped == "P"
            if hasMore() && peek() == "{" {
                advance() // consume {
                var property = ""
                while hasMore() && peek() != "}" {
                    property.append(peek())
                    advance()
                }
                if hasMore() { advance() } // consume }
                let propDesc = isNegated ? "\(Label.not) \(property)" : property
                return applyQuantifier("\"[\(propDesc)]\"")
            }
            return applyQuantifier("\"\(escaped)\"")

            // Back reference
        case "k":
            if hasMore() && peek() == "<" {
                advance() // consume <
                var name = ""
                while hasMore() && peek() != ">" {
                    name.append(peek())
                    advance()
                }
                if hasMore() { advance() } // consume >
                return applyQuantifier("'\(name)'")
            }
            return applyQuantifier("\"k\"")

            // Numeric back reference
        case "1"..."9":
            return applyQuantifier("'\(Label.group) \(escaped)'")

            // Octal
        case "0":
            var octal = "0"
            for _ in 0..<3 {
                if hasMore() && isOctalDigit(peek()) {
                    octal.append(peek())
                    advance()
                }
            }
            return applyQuantifier("\"[\\\\o\(octal)]\"")

            // Control character
        case "c":
            if hasMore() {
                let control = peek()
                advance()
                return applyQuantifier("\"[\(Label.control)-\(control)]\"")
            }
            return applyQuantifier("\"c\"")

            // Quote sequences
        case "Q":
            var quoted = ""
            while hasMore() {
                if peek() == "\\" && peekAhead() == "E" {
                    advance() // consume \
                    advance() // consume E
                    break
                }
                quoted.append(peek())
                advance()
            }
            return applyQuantifier("\"\(escapeForTerminal(quoted))\"")

        case "E":
            return "" // End of quote - handled by \Q

            // Literal escaped characters
        default:
            return applyQuantifier("\"\(escapeForTerminal(String(escaped)))\"")
        }
    }

    private func applyQuantifier(_ base: String) -> String {
        guard hasMore() else { return base }

        let quantChar = peek()

        switch quantChar {
        case "*":
            advance()
            if hasMore() && peek() == "?" {
                advance()
                // Lazy zero-or-more: choice between empty and one-or-more
                return "<!, {\(base)*!, `*? (\(Label.lazy))`}>"
            } else if hasMore() && peek() == "+" {
                advance()
                // Possessive zero-or-more: choice between empty and one-or-more
                return "<!, {\(base)*!, `*+ (\(Label.possessive))`}>"
            }
            // Zero or more: choice between empty and one-or-more
            return "<!, {\(base)*!}>"

        case "+":
            advance()
            if hasMore() && peek() == "?" {
                advance()
                // Lazy one-or-more
                return "{\(base)*!, `+? (\(Label.lazy))`}"
            } else if hasMore() && peek() == "+" {
                advance()
                // Possessive one-or-more
                return "{\(base)*!, `++ (\(Label.possessive))`}"
            }
            // One or more
            return "{\(base)*!}"

        case "?":
            advance()
            if hasMore() && peek() == "?" {
                advance()
                // Lazy optional: prefer empty
                return "<!, \(base), `?? (\(Label.lazy))`>"
            } else if hasMore() && peek() == "+" {
                advance()
                // Possessive optional
                return "<!, \(base), `?+ (\(Label.possessive))`>"
            }
            // Optional: choice between empty and the element
            return "<!, \(base)>"

        case "{":
            advance()
            var quantifier = ""
            while hasMore() && peek() != "}" {
                quantifier.append(peek())
                advance()
            }
            if hasMore() { advance() } // consume }

            var suffix = ""
            if hasMore() {
                if peek() == "?" {
                    advance()
                    suffix = " (\(Label.lazy))"
                } else if peek() == "+" {
                    advance()
                    suffix = " (\(Label.possessive))"
                }
            }

            // Parse quantifier
            let parts = quantifier.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

            if parts.count == 1 {
                // Exactly n times
                if let n = Int(parts[0]) {
                    if n == 0 {
                        // {0} means empty
                        return "!"
                    } else if n == 1 {
                        // {1} means exactly once
                        return suffix.isEmpty ? base : "{\(base), `{\(n)}\(suffix)`}"
                    } else {
                        // {n} means exactly n times - need n-1 in sequence then base
                        var result = [base]
                        for _ in 1..<n {
                            result.append(base)
                        }
                        let repeated = "{\(result.joined(separator: ", "))}"
                        return suffix.isEmpty ? repeated : "{\(repeated), `{\(n)}\(suffix)`}"
                    }
                }
            } else if parts.count == 2 {
                if parts[1].isEmpty {
                    // At least n times {n,}
                    if let n = Int(parts[0]) {
                        if n == 0 {
                            // {0,} is same as *
                            return suffix.isEmpty ? "<!, {\(base)*!}>" : "<!, {\(base)*!, `{0,}\(suffix)`}>"
                        } else if n == 1 {
                            // {1,} is same as +
                            return suffix.isEmpty ? "{\(base)*!}" : "{\(base)*!, `{1,}\(suffix)`}"
                        } else {
                            // {n,} means n required followed by zero or more
                            var required = [base]
                            for _ in 1..<n {
                                required.append(base)
                            }
                            let result = "{\(required.joined(separator: ", ")), {\(base)*!}?}"
                            return suffix.isEmpty ? result : "{\(result), `{\(n),}\(suffix)`}"
                        }
                    }
                } else {
                    // Between n and m times {n,m}
                    if let n = Int(parts[0]), let m = Int(parts[1]) {
                        if n == 0 && m == 1 {
                            // {0,1} is same as ?
                            return suffix.isEmpty ? "<!, \(base)>" : "<!, \(base), `{0,1}\(suffix)`>"
                        } else if n == 0 {
                            // {0,m} - all optional
                            var elements: [String] = []
                            for i in 0..<m {
                                if i == 0 {
                                    elements.append(base)
                                } else {
                                    elements.append("<!, \(base)>")
                                }
                            }
                            let result = "<!, {\(elements.joined(separator: ", "))}>"
                            return suffix.isEmpty ? result : "{\(result), `{\(n),\(m)}\(suffix)`}"
                        } else {
                            // {n,m} - n required, m-n optional
                            var elements: [String] = []
                            // Required elements
                            for _ in 0..<n {
                                elements.append(base)
                            }
                            // Optional elements
                            for _ in n..<m {
                                elements.append("<!, \(base)>")
                            }
                            let result = "{\(elements.joined(separator: ", "))}"
                            return suffix.isEmpty ? result : "{\(result), `{\(n),\(m)}\(suffix)`}"
                        }
                    }
                }
            }

            return "{\(base), `{\(quantifier)}\(suffix)`}"

        default:
            return base
        }
    }

    // MARK: - Helper Methods

    private func hasMore() -> Bool {
        return position < input.endIndex
    }

    private func peek() -> Character {
        guard hasMore() else { return "\0" }
        return input[position]
    }

    private func peekAhead() -> Character {
        let nextIndex = input.index(after: position)
        guard nextIndex < input.endIndex else { return "\0" }
        return input[nextIndex]
    }

    private func advance() {
        if hasMore() {
            position = input.index(after: position)
        }
    }

    private func isHexDigit(_ char: Character) -> Bool {
        return char.isHexDigit
    }

    private func isOctalDigit(_ char: Character) -> Bool {
        return char >= "0" && char <= "7"
    }

    private func isFlag(_ char: Character) -> Bool {
        return "ismwx".contains(char)
    }

    private func escapeForTerminal(_ str: String) -> String {
        return str
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func handleEscapeInClass(_ char: Character) -> String {
        switch char {
        case "d": return "\"[\(Label.digit)]\""
        case "D": return "\"[\(Label.nonDigit)]\""
        case "s": return "\"[\(Label.whitespace)]\""
        case "S": return "\"[\(Label.nonWhitespace)]\""
        case "w": return "\"[\(Label.wordCharacter)]\""
        case "W": return "\"[\(Label.nonWordCharacter)]\""
        case "h": return "\"[\(Label.horizontalWhitespace)]\""
        case "H": return "\"[\(Label.nonHorizontalWhitespace)]\""
        case "v": return "\"[\(Label.verticalWhitespace)]\""
        case "V": return "\"[\(Label.nonVerticalWhitespace)]\""
        case "n": return "\"[\(Label.lineFeed)]\""
        case "r": return "\"[\(Label.carriageReturn)]\""
        case "t": return "\"[\(Label.tab)]\""
        case "f": return "\"[\(Label.formFeed)]\""
        case "a": return "\"[\(Label.bell)]\""
        case "e": return "\"[\(Label.escape)]\""
        default: return "\"\(escapeForTerminal(String(char)))\""
        }
    }
}
