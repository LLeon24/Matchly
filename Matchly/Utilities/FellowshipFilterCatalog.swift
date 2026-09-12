//
//  FellowshipFilterCatalog.swift
//  Matchly
//
//  ERAS fellowship subspecialty options for search filtering.
//

import Foundation

struct FellowshipFilterOption: Identifiable, Hashable {
  let code: String
  let displayName: String
  let parentLabel: String

  var id: String { code }
}

enum FellowshipFilterCatalog {
  private struct PARFellowshipIndex: Decodable {
    let fellowshipByCode: [String: String]
  }

  private static let fellowshipByCode: [String: String] = {
    guard let url = Bundle.main.url(forResource: "ERAS_PAR_specialties", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let decoded = try? JSONDecoder().decode(PARFellowshipIndex.self, from: data)
    else { return [:] }
    return decoded.fellowshipByCode
  }()

  /// Fellowship subspecialties the user can apply to, based on selected parent specialty(ies).
  static func options(forUserSpecialties userSpecialties: [String]) -> [FellowshipFilterOption] {
    guard !userSpecialties.isEmpty else { return [] }

    var codes = Set<String>()
    for specialty in userSpecialties {
      codes.formUnion(ACGMSpecialtyHierarchy.fellowshipCodes(forUserSpecialty: specialty))
    }

    return codes.compactMap { code in
      guard let name = fellowshipByCode[code] else { return nil }
      let parent = ERASTrainingLevel.parentLabel(fromERASName: name)
        ?? ACGMSpecialtyHierarchy.residencyDisplayNames[ACGMSpecialtyHierarchy.fellowshipParentCode[code] ?? ""]
        ?? "Other"
      return FellowshipFilterOption(code: code, displayName: name, parentLabel: parent)
    }
    .sorted { lhs, rhs in
      if lhs.parentLabel != rhs.parentLabel {
        return lhs.parentLabel.localizedCaseInsensitiveCompare(rhs.parentLabel) == .orderedAscending
      }
      return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
    }
  }

  static func groupedOptions(forUserSpecialties userSpecialties: [String]) -> [(parent: String, options: [FellowshipFilterOption])] {
    let options = options(forUserSpecialties: userSpecialties)
    let grouped = Dictionary(grouping: options) { $0.parentLabel }
    return grouped.keys.sorted().map { key in
      (parent: key, options: grouped[key]!.sorted { $0.displayName < $1.displayName })
    }
  }

  static func displayName(forCode code: String) -> String? {
    fellowshipByCode[code]
  }
}
