//
//  ProgramTrainingLevel.swift
//  Matchly
//

import Foundation

/// Whether a program is a core residency (incl. combined / integrated) or subspecialty fellowship.
enum ProgramTrainingLevel: String, Codable, CaseIterable, Identifiable {
  case residency = "Residency"
  case fellowship = "Fellowship"

  var id: String { rawValue }
}

enum ProgramTrainingLevelFilter: String, CaseIterable, Identifiable {
  case all = "All"
  case residency = "Residency"
  case fellowship = "Fellowship"

  var id: String { rawValue }

  var trainingLevel: ProgramTrainingLevel? {
    switch self {
    case .all: return nil
    case .residency: return .residency
    case .fellowship: return .fellowship
    }
  }
}

enum ProgramTrainingLevelClassifier {
  static func specialtyCode(for program: ResidencyProgramInfo) -> String? {
    ERASTrainingLevel.specialtyCode(for: program)
      ?? ACGMSpecialtyHierarchy.catalogSpecialtyCode(from: program.specialty)
      ?? fellowshipCodeFromAccreditationID(program)
  }

  /// ERAS PAR is authoritative when a specialty code is listed there; otherwise ACGME hierarchy.
  static func trainingLevel(for program: ResidencyProgramInfo) -> ProgramTrainingLevel {
    if let erasLevel = ERASTrainingLevel.trainingLevel(for: program) {
      return erasLevel
    }
    return ACGMSpecialtyHierarchy.trainingLevel(for: program)
  }

  /// Fellowship codes are explicit in accreditation IDs (e.g. 156, 141). Parent codes (140) are ambiguous.
  private static func fellowshipCodeFromAccreditationID(_ program: ResidencyProgramInfo) -> String? {
    let id = program.accreditationID ?? program.id
    guard id.count >= 3 else { return nil }
    let prefix = String(id.prefix(3))
    guard ACGMSpecialtyHierarchy.fellowshipParentCode[prefix] != nil else { return nil }
    return prefix
  }
}

extension ResidencyProgramInfo {
  var trainingLevel: ProgramTrainingLevel {
    ProgramTrainingLevelClassifier.trainingLevel(for: self)
  }

  /// Parent residency specialty for fellowships (e.g. OB/GYN for urogynecology).
  var parentResidencyName: String? {
    guard trainingLevel == .fellowship else { return nil }
    return ERASTrainingLevel.parentResidencyName(for: self)
      ?? ACGMSpecialtyHierarchy.parentResidencyName(for: self)
  }
}
