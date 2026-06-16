//
//  ERASTrainingLevel.swift
//  Matchly
//
//  Residency vs fellowship classification from AAMC ERAS PAR
//  (https://systems.aamc.org/eras/erasstats/par/index.cfm).
//

import Foundation

private struct ERASPARSpecialtyIndex: Decodable {
  let residencyByCode: [String: String]
  let fellowshipByCode: [String: String]
  let acgmeSpecialtyByCode: [String: String]?
  let fellowshipParentByCode: [String: String]?
}

enum ERASTrainingLevel {
  private static let index: ERASPARSpecialtyIndex? = {
    guard let url = Bundle.main.url(forResource: "ERAS_PAR_specialties", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let decoded = try? JSONDecoder().decode(ERASPARSpecialtyIndex.self, from: data)
    else {
      print("Warning: Could not load ERAS_PAR_specialties.json — falling back to ACGME hierarchy")
      return nil
    }
    return decoded
  }()

  private static let residencyNameToCode: [String: String] = {
    guard let index else { return [:] }
    var map: [String: String] = [:]
    for (code, name) in index.residencyByCode {
      map[normalizeSpecialtyName(name)] = code
    }
    return map
  }()

  private static let fellowshipNameToCode: [String: String] = {
    guard let index else { return [:] }
    var map: [String: String] = [:]
    for (code, name) in index.fellowshipByCode {
      map[normalizeSpecialtyName(name)] = code
      let base = normalizeSpecialtyName(String(name.split(separator: "(").first ?? Substring(name)))
      map[base] = code
    }
    return map
  }()

  private static let parentAbbreviationMap: [String: String] = [
    "obgyn": "OB/GYN",
    "obstetrics and gynecology": "OB/GYN",
    "internal medicine": "Internal Medicine",
    "family medicine": "Family Medicine",
    "pediatrics": "Pediatrics",
    "general surgery": "General Surgery",
    "surgery": "General Surgery",
    "neurology": "Neurology",
    "anesthesiology": "Anesthesiology",
    "pathology": "Pathology",
    "psychiatry": "Psychiatry",
    "urology": "Urology",
    "physical medicine and rehabilitation": "PM&R",
    "preventive medicine": "Preventive Medicine",
    "multidisciplinary": "Multidisciplinary",
    "radiology": "Radiology",
    "neurological surgery": "Neurosurgery",
    "orthopaedic surgery": "Orthopedics",
    "emergency medicine": "Emergency Medicine",
  ]

  private static let ambiguousParentPrefixes: Set<String> = [
    "040", "110", "120", "140", "180", "220", "300", "320", "400", "420", "440",
  ]

  static func specialtyCode(for program: ResidencyProgramInfo) -> String? {
    if let code = ACGMSpecialtyHierarchy.catalogSpecialtyCode(from: program.specialty) {
      return code
    }
    if let code = specialtyCode(forSpecialtyName: program.specialty) {
      return code
    }
    return specialtyCode(fromAccreditationID: program.accreditationID ?? program.id, specialty: program.specialty)
  }

  static func specialtyCode(forSpecialtyName specialty: String) -> String? {
    let normalized = normalizeSpecialtyName(specialty)
    if let code = residencyNameToCode[normalized] { return code }
    if let code = fellowshipNameToCode[normalized] { return code }
    let base = normalizeSpecialtyName(String(specialty.split(separator: "(").first ?? Substring(specialty)))
    if let code = fellowshipNameToCode[base] { return code }
    if let code = fuzzySpecialtyCode(for: specialty) { return code }
    return nil
  }

  static func specialtyCode(fromAccreditationID accreditationID: String, specialty: String) -> String? {
    guard accreditationID.count >= 3 else { return nil }
    let prefix = String(accreditationID.prefix(3))

    if ambiguousParentPrefixes.contains(prefix) {
      if let code = specialtyCode(forSpecialtyName: specialty), code != prefix {
        return code
      }
    }

    if index?.fellowshipByCode[prefix] != nil { return prefix }
    if index?.fellowshipParentByCode?[prefix] != nil { return prefix }
    if index?.residencyByCode[prefix] != nil { return prefix }
    if index?.acgmeSpecialtyByCode?[prefix] != nil { return prefix }
    if ACGMSpecialtyHierarchy.residencySpecialtyCodes.contains(prefix) { return prefix }
    return nil
  }

  private static let fuzzyNameToCode: [String: String] = {
    guard let index else { return [:] }
    var map: [String: String] = [:]
    let sources = [index.residencyByCode, index.fellowshipByCode, index.acgmeSpecialtyByCode ?? [:]]
    for source in sources {
      for (code, name) in source {
        map[fuzzyKey(name)] = code
        map[fuzzyKey(String(name.split(separator: "(").first ?? Substring(name)))] = code
      }
    }
    return map
  }()

  private static func fuzzySpecialtyCode(for specialty: String) -> String? {
    fuzzyNameToCode[fuzzyKey(specialty)]
  }

  private static func fuzzyKey(_ specialty: String) -> String {
    normalizeSpecialtyName(specialty).unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
      .map { String($0) }.joined()
  }

  static func trainingLevel(for program: ResidencyProgramInfo) -> ProgramTrainingLevel? {
    guard let code = specialtyCode(for: program) else { return nil }
    if index?.residencyByCode[code] != nil { return .residency }
    if index?.fellowshipByCode[code] != nil { return .fellowship }
    return nil
  }

  static func erasSpecialtyName(for program: ResidencyProgramInfo) -> String? {
    guard let code = specialtyCode(for: program) else { return nil }
    return index?.residencyByCode[code] ?? index?.fellowshipByCode[code]
  }

  private static func normalizeSpecialtyName(_ specialty: String) -> String {
    var trimmed = specialty.trimmingCharacters(in: .whitespacesAndNewlines)
    if let open = trimmed.lastIndex(of: "("),
      let close = trimmed.lastIndex(of: ")"),
      open < close
    {
      let inner = String(trimmed[trimmed.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)
      if inner.count == 3, inner.allSatisfy(\.isNumber) {
        trimmed = String(trimmed[..<open]).trimmingCharacters(in: .whitespaces)
      }
    }
    return trimmed.lowercased()
  }

  /// Parent residency label for ERAS-listed fellowships, parsed from PAR specialty name.
  static func parentResidencyName(for program: ResidencyProgramInfo) -> String? {
    guard trainingLevel(for: program) == .fellowship,
      let code = specialtyCode(for: program),
      let fellowshipName = index?.fellowshipByCode[code]
    else { return nil }

    if let parent = parentLabel(fromERASName: fellowshipName) {
      return parent
    }
    return ACGMSpecialtyHierarchy.parentResidencyName(for: program)
  }

  static func parentLabel(fromERASName name: String) -> String? {
    // e.g. "Cardiovascular Disease (Internal Medicine)"
    guard let open = name.lastIndex(of: "("), let close = name.lastIndex(of: ")"), open < close else {
      return nil
    }
    let inner = String(name[name.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)
    guard !inner.isEmpty, inner.count != 3 || !inner.allSatisfy(\.isNumber) else { return nil }

    let key = inner.lowercased()
    if let mapped = parentAbbreviationMap[key] { return mapped }
    return inner
      .split(separator: " ")
      .map { word in
        let lower = word.lowercased()
        if ["and", "of", "in", "the", "for"].contains(lower) { return lower }
        return lower.prefix(1).uppercased() + lower.dropFirst()
      }
      .joined(separator: " ")
  }

  /// Whether an ERAS fellowship name lists the given parent specialty in parentheses.
  static func fellowshipNamesParent(_ parentUserSpecialty: String, program: ResidencyProgramInfo) -> Bool {
    guard let code = specialtyCode(for: program),
      let fellowshipName = index?.fellowshipByCode[code],
      let parentLabel = parentLabel(fromERASName: fellowshipName)
    else { return false }
    return SpecialtyFormatter.namesMatchExact(parentLabel, parentUserSpecialty)
      || SpecialtyFormatter.namesMatchExact(parentLabel, normalizedParentAlias(parentUserSpecialty))
  }

  private static func normalizedParentAlias(_ userSpecialty: String) -> String {
    switch userSpecialty {
    case "OB/GYN": return "Obstetrics and Gynecology"
    case "General Surgery": return "Surgery"
    case "PM&R": return "Physical Medicine and Rehabilitation"
    case "Orthopedics": return "Orthopaedic Surgery"
    case "ENT": return "Otolaryngology"
    case "Neurosurgery": return "Neurological Surgery"
    case "Radiology": return "Radiology-Diagnostic"
    default: return userSpecialty
    }
  }
}
