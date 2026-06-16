//
//  DisplayNameFormatter.swift
//  Matchly
//
//  Consistent title casing for ERAS labels, parentheticals, and display text.
//

import Foundation

enum DisplayNameFormatter {
    private static let lowercaseWords: Set<String> = ["and", "of", "in", "the", "for", "or", "at", "by"]

    /// Title-cases each word; keeps small words lowercase except at the start. Handles `/` segments.
    static func titleCaseWords(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        if trimmed.contains("/") {
            return trimmed
                .split(separator: "/")
                .map { titleCaseWords(String($0)) }
                .joined(separator: "/")
        }

        let words = trimmed.split(separator: " ")
        return words.enumerated().map { index, word in
            titleCaseWord(String(word), atSentenceStart: index == 0)
        }
        .joined(separator: " ")
    }

    /// Title-cases content inside each parenthetical segment.
    static func titleCaseParentheticals(in text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\\(([^)]+)\\)") else { return text }
        let ns = text as NSString
        var result = text
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for match in matches.reversed() where match.numberOfRanges >= 2 {
            let fullRange = match.range(at: 0)
            let inner = ns.substring(with: match.range(at: 1))
            let formatted = titleCaseWords(inner)
            result = (result as NSString).replacingCharacters(in: fullRange, with: "(\(formatted))")
        }
        return result
    }

    private static func titleCaseWord(_ word: String, atSentenceStart: Bool) -> String {
        let lower = word.lowercased()
        if !atSentenceStart, lowercaseWords.contains(lower) {
            return lower
        }
        if word.isEmpty { return word }
        return word.prefix(1).uppercased() + word.dropFirst().lowercased()
    }
}
