//
//  HospitalNameFormatter.swift
//  Matchly
//
//  Created on 11/14/25.
//

import Foundation

struct HospitalNameFormatter {
    // Common acronyms that should stay uppercase (2-4 letters, all caps)
    private static let acronyms: Set<String> = [
        "HCA", "UCLA", "UCSF", "NYU", "USC", "UNC", "UVA", "UPMC", "GME",
        "ACGME", "ERAS", "AAMC", "ACLS", "BLS", "ICU", "ER", "OR", "MRI",
        "CT", "USA", "EU", "FDA", "CDC", "NIH", "WHO", "UN", "FBI", "CIA",
        "NASA", "FAA", "FCC", "SEC", "IRS", "GPS", "USB", "HDMI", "PDF",
        "HTML", "CSS", "API", "URL", "HTTP", "HTTPS", "IP", "DNS", "VPN",
        "AI", "ML", "CEO", "CFO", "CTO", "VP", "HR", "IT", "PR", "MD",
        "DO", "PA", "NP", "RN", "LPN", "EMT", "PALS", "ATLS", "NRP", "NALS"
    ]
    
    // Words that should be lowercase (unless at start)
    private static let lowercaseWords: Set<String> = [
        "of", "the", "and", "or", "but", "in", "on", "at", "to", "for",
        "with", "by", "from", "as", "a", "an"
    ]
    
    // Compiled once and reused. Built from a constant literal pattern, so it will
    // never realistically fail, but we avoid `try!` (and per-call recompilation)
    // so a future pattern change can't crash the app.
    private static let parenthesesRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: "\\(([^)]+)\\)", options: [])
    }()
    
    static func format(_ name: String) -> String {
        guard !name.isEmpty else { return name }
        
        var result = normalizeRawName(name)
        
        // Handle parentheses - format content inside parentheses
        if let regex = parenthesesRegex {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            
            // Process matches in reverse order to preserve indices
            for match in matches.reversed() {
                if match.numberOfRanges >= 2 {
                    let fullRange = match.range(at: 0)
                    let contentRange = match.range(at: 1)
                    let content = nsString.substring(with: contentRange)
                    let formatted = formatPart(content)
                    result = (result as NSString).replacingCharacters(in: fullRange, with: "(\(formatted))")
                }
            }
        }
        
        // Handle / separator
        if result.contains("/") {
            let parts = result.components(separatedBy: "/")
            let formattedParts = parts.map { part in
                // Check if part contains parentheses (already formatted)
                if part.contains("(") && part.contains(")") {
                    // Extract and format the part before parentheses
                    if let parenRange = part.range(of: "(") {
                        let beforeParen = String(part[..<parenRange.lowerBound])
                        let afterParen = String(part[parenRange.lowerBound...])
                        return formatPart(beforeParen.trimmingCharacters(in: .whitespaces)) + afterParen
                    }
                }
                return formatPart(part.trimmingCharacters(in: .whitespaces))
            }
            result = formattedParts.joined(separator: "/")
        } else {
            // Format the main part if it doesn't already have formatted parentheses
            if !result.contains("(") || !result.contains(")") {
                result = formatPart(result)
            } else {
                // Format parts outside parentheses
                var formattedResult = ""
                var currentIndex = result.startIndex
                
                while currentIndex < result.endIndex {
                    if let parenStart = result[currentIndex...].firstIndex(of: "("),
                       let parenEnd = result[parenStart...].firstIndex(of: ")") {
                        // Format text before parentheses
                        let beforeParen = String(result[currentIndex..<parenStart])
                        if !beforeParen.isEmpty {
                            formattedResult += formatPart(beforeParen)
                        }
                        // Keep parentheses content as is (already formatted)
                        formattedResult += String(result[parenStart...parenEnd])
                        currentIndex = result.index(after: parenEnd)
                    } else {
                        // No more parentheses, format the rest
                        let remaining = String(result[currentIndex...])
                        formattedResult += formatPart(remaining)
                        break
                    }
                }
                result = formattedResult
            }
        }
        
        return DisplayNameFormatter.titleCaseParentheticals(in: result)
    }

    private static func normalizeRawName(_ name: String) -> String {
        var result = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.lowercased().hasSuffix(" program") {
            result = String(result.dropLast(8)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let regex = try? NSRegularExpression(pattern: "([^\\s])\\(", options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "$1 (")
        }
        return result
    }
    
    private static func formatPart(_ part: String) -> String {
        guard !part.isEmpty else { return part }
        
        let words = part.components(separatedBy: .whitespaces)
        var formattedWords: [String] = []
        
        for (index, word) in words.enumerated() {
            let trimmed = word.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if trimmed.contains("-") {
                let hyphenParts = trimmed
                    .split(separator: "-")
                    .map { capitalizeFirst(String($0)) }
                formattedWords.append(hyphenParts.joined(separator: "-"))
                continue
            }
            
            let lower = trimmed.lowercased()
            let upper = trimmed.uppercased()
            
            // Check lowercase words first (before acronym check) to prevent false acronyms
            if index > 0 && lowercaseWords.contains(lower) {
                // Articles/prepositions: lowercase (unless it's the first word)
                formattedWords.append(lower)
            } else if acronyms.contains(upper) || (trimmed.count <= 4 && trimmed.allSatisfy { $0.isLetter && $0.isUppercase } && !lowercaseWords.contains(lower)) {
                // Check if it's an acronym (2-4 uppercase letters, but not a lowercase word)
                formattedWords.append(upper)
            } else if index == 0 {
                // First word: Title case
                formattedWords.append(capitalizeFirst(trimmed))
            } else {
                // Other words: Title case
                formattedWords.append(capitalizeFirst(trimmed))
            }
        }
        
        return formattedWords.joined(separator: " ")
    }
    
    private static func capitalizeFirst(_ string: String) -> String {
        guard !string.isEmpty else { return string }
        return string.prefix(1).uppercased() + string.dropFirst().lowercased()
    }
}

// Extension to apply formatting when loading programs
extension ResidencyProgramInfo {
    var formattedHospital: String {
        return HospitalNameFormatter.format(hospital)
    }
}

