//
//  DirectorNameFormatter.swift
//  Matchly
//

import Foundation

enum DirectorNameFormatter {
    /// Extracts a person name from noisy ACGME director strings.
    static func clean(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        if let match = raw.range(of: #",?\s*MD\s*$"#, options: [.regularExpression, .caseInsensitive]) {
            let beforeMD = String(raw[..<match.lowerBound])
            let parts = beforeMD.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if let last = parts.last, looksLikePersonName(last) {
                return last
            }
        }

        if looksLikePersonName(raw) {
            return raw
        }

        let tokens = raw.split(separator: " ")
        if tokens.count >= 2 {
            let last = tokens.suffix(2).joined(separator: " ")
            if looksLikePersonName(last) {
                return last
            }
        }

        return nil
    }

    /// Derive a display name from coordinator email when director is missing.
    static func fromEmail(_ email: String?) -> String? {
        guard let email, let local = email.split(separator: "@").first else { return nil }
        let parts = local.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        return parts.map { $0.capitalized }.joined(separator: " ")
    }

    static func displayDirector(programDirector: String?, contactEmail: String?) -> String? {
        clean(programDirector) ?? fromEmail(contactEmail)
    }

    private static func looksLikePersonName(_ name: String) -> Bool {
        let lower = name.lowercased()
        let blocklist = ["university", "hospital", "medical", "center", "healthcare", "program", "accreditation"]
        if blocklist.contains(where: { lower.contains($0) }) { return false }
        return name.split(separator: " ").count >= 2
    }
}
