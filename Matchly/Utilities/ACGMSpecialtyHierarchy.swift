//
//  ACGMSpecialtyHierarchy.swift
//  Matchly
//
//  ACGME specialty codes and parent/child relationships.
//  Fellowship parents ship in ERAS_PAR_specialties.json (generated from ACGME Report #1 + ERAS PAR).
//

import Foundation

enum ACGMSpecialtyHierarchy {
  private struct PARIndex: Decodable {
    let residencyByCode: [String: String]?
    let fellowshipByCode: [String: String]?
    let fellowshipParentByCode: [String: String]?
    let userSpecialtyResidencyCodes: [String: [String]]?
    let additionalFellowshipCodesByUserSpecialty: [String: [String]]?
  }

  private static let parIndex: PARIndex? = {
    guard let url = Bundle.main.url(forResource: "ERAS_PAR_specialties", withExtension: "json"),
      let data = try? Data(contentsOf: url)
    else { return nil }
    return try? JSONDecoder().decode(PARIndex.self, from: data)
  }()

  /// Core residency / combined-program specialty codes (3-digit).
  static let residencySpecialtyCodes: Set<String> = [
    "020", "040", "060", "080", "110", "120", "140", "130", "160", "180", "185", "200", "220", "240",
    "260", "275", "280", "300", "320", "340", "360", "362", "380", "382", "383", "400", "416", "420",
    "430", "440", "450", "451", "460", "461", "480", "999",
    "700", "705", "715", "726", "730", "735", "740", "742", "745", "751", "752", "753", "754", "755",
    "756", "757", "765", "766", "770", "775", "785", "790", "795", "796", "797",
  ]

  /// Fellowship code → parent residency code (loaded from bundled JSON).
  static var fellowshipParentCode: [String: String] {
    parIndex?.fellowshipParentByCode ?? fallbackFellowshipParentCode
  }

  static let residencyDisplayNames: [String: String] = [
    "020": "Allergy and Immunology",
    "040": "Anesthesiology",
    "060": "Colon and Rectal Surgery",
    "080": "Dermatology",
    "110": "Emergency Medicine",
    "120": "Family Medicine",
    "130": "Medical Genetics and Genomics",
    "140": "Internal Medicine",
    "160": "Neurological Surgery",
    "180": "Neurology",
    "185": "Child Neurology",
    "200": "Nuclear Medicine",
    "220": "Obstetrics and Gynecology",
    "240": "Ophthalmology",
    "260": "Orthopaedic Surgery",
    "275": "Osteopathic Neuromusculoskeletal Medicine",
    "280": "Otolaryngology",
    "300": "Pathology",
    "320": "Pediatrics",
    "340": "Physical Medicine and Rehabilitation",
    "360": "Plastic Surgery",
    "362": "Plastic Surgery - Integrated",
    "380": "Public Health and General Preventive Medicine",
    "382": "Occupational and Environmental Medicine",
    "383": "Aerospace Medicine",
    "400": "Psychiatry",
    "416": "Interventional Radiology - Integrated",
    "420": "Diagnostic Radiology",
    "430": "Radiation Oncology",
    "440": "General Surgery",
    "450": "Vascular Surgery - Independent",
    "451": "Vascular Surgery - Integrated",
    "460": "Thoracic Surgery - Independent",
    "461": "Thoracic Surgery - Integrated",
    "480": "Urology",
    "999": "Transitional Year",
  ]

  private static var userSpecialtyResidencyCodes: [String: Set<String>] {
    guard let raw = parIndex?.userSpecialtyResidencyCodes else { return fallbackUserSpecialtyResidencyCodes }
    return raw.mapValues { Set($0) }
  }

  private static var additionalFellowshipCodesByUserSpecialty: [String: Set<String>] {
    guard let raw = parIndex?.additionalFellowshipCodesByUserSpecialty else {
      return fallbackAdditionalFellowshipCodes
    }
    return raw.mapValues { Set($0) }
  }

  /// Inverted map: parent residency code → fellowship specialty codes underneath it.
  static var fellowshipCodesByParent: [String: Set<String>] {
    var result: [String: Set<String>] = [:]
    for (fellowshipCode, parentCode) in fellowshipParentCode {
      result[parentCode, default: []].insert(fellowshipCode)
    }
    return result
  }

  /// Parses the trailing `(###)` ACGME specialty code from catalog strings.
  static func catalogSpecialtyCode(from specialty: String) -> String? {
    let trimmed = specialty.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let open = trimmed.lastIndex(of: "("),
      let close = trimmed.lastIndex(of: ")"),
      open < close
    else { return nil }
    let code = trimmed[trimmed.index(after: open)..<close].trimmingCharacters(in: .whitespaces)
    return code.count == 3 && code.allSatisfy(\.isNumber) ? code : nil
  }

  static func trainingLevel(for program: ResidencyProgramInfo) -> ProgramTrainingLevel {
    if let erasLevel = ERASTrainingLevel.trainingLevel(for: program) {
      return erasLevel
    }

    if let code = catalogSpecialtyCode(from: program.specialty) {
      return residencySpecialtyCodes.contains(code) ? .residency : .fellowship
    }

    if let code = ERASTrainingLevel.specialtyCode(forSpecialtyName: program.specialty) {
      if parIndex?.residencyByCode?[code] != nil || residencySpecialtyCodes.contains(code) {
        return .residency
      }
      return .fellowship
    }

    if let id = program.accreditationID ?? Optional(program.id), id.count >= 3 {
      let prefix = String(id.prefix(3))
      if fellowshipParentCode[prefix] != nil { return .fellowship }
      if residencySpecialtyCodes.contains(prefix) { return .residency }
    }

    return .fellowship
  }

  static func parentResidencyCode(for program: ResidencyProgramInfo) -> String? {
    let code = ERASTrainingLevel.specialtyCode(for: program)
      ?? catalogSpecialtyCode(from: program.specialty)
    guard let code else { return nil }
    if residencySpecialtyCodes.contains(code) { return code }
    return fellowshipParentCode[code]
  }

  static func parentResidencyName(for program: ResidencyProgramInfo) -> String? {
    guard let parentCode = parentResidencyCode(for: program) else { return nil }
    return residencyDisplayNames[parentCode]
      ?? SpecialtyFormatter.normalizedCatalogName(program.specialty)
  }

  static func residencyCodes(forUserSpecialty userSpecialty: String) -> Set<String> {
    let trimmed = userSpecialty.trimmingCharacters(in: .whitespacesAndNewlines)
    return userSpecialtyResidencyCodes[trimmed] ?? []
  }

  static func fellowshipCodes(forUserSpecialty userSpecialty: String) -> Set<String> {
    let trimmed = userSpecialty.trimmingCharacters(in: .whitespacesAndNewlines)
    let parentCodes = residencyCodes(forUserSpecialty: trimmed)
    var codes = Set<String>()
    for parent in parentCodes {
      if let children = fellowshipCodesByParent[parent] {
        codes.formUnion(children)
      }
    }
    if let extras = additionalFellowshipCodesByUserSpecialty[trimmed] {
      codes.formUnion(extras)
    }
    return codes
  }

  // MARK: - Fallback maps (if JSON fails to load)

  private static let fallbackFellowshipParentCode: [String: String] = [
    "041": "040", "042": "040", "043": "040", "044": "040", "045": "040", "046": "040", "047": "040",
    "081": "080", "082": "080", "100": "080",
    "111": "110", "112": "110", "114": "110", "116": "110", "118": "110", "119": "110",
    "122": "120", "125": "120", "127": "120",
    "141": "140", "142": "140", "143": "140", "146": "140", "147": "140", "148": "140", "149": "140",
    "150": "140", "151": "140", "152": "140", "153": "140", "154": "140", "155": "140", "156": "140",
    "158": "140", "159": "140", "137": "140", "138": "140", "139": "140", "145": "140",
    "163": "160", "182": "180", "183": "180", "184": "180", "186": "180", "187": "180", "188": "180", "189": "180",
    "221": "220", "225": "220", "230": "220", "235": "220", "236": "220",
    "241": "240",
    "261": "260", "262": "260", "263": "260", "265": "260", "267": "260", "268": "260", "269": "260", "270": "260",
    "286": "280", "288": "280",
    "302": "300", "305": "300", "306": "300", "307": "300", "310": "300", "311": "300", "314": "300", "315": "300", "316": "300",
    "321": "320", "322": "320", "323": "320", "324": "320", "325": "320", "326": "320", "327": "320",
    "328": "320", "329": "320", "330": "320", "331": "320", "332": "320", "333": "320", "334": "320",
    "335": "320", "336": "320", "338": "320", "339": "320",
    "342": "340", "345": "340", "346": "340", "347": "340",
    "361": "360", "363": "360",
    "398": "380", "399": "380",
    "401": "400", "404": "400", "405": "400", "406": "400", "407": "400", "409": "400",
    "415": "420", "421": "420", "422": "420", "423": "420", "424": "420", "425": "420", "426": "420", "427": "420",
    "442": "440", "443": "440", "445": "440", "446": "440", "450": "440", "460": "440",
    "466": "460",
    "485": "480", "486": "480",
    "520": "140", "530": "040", "540": "120", "550": "180",
    "060": "440", "754": "220",
  ]

  private static let fallbackUserSpecialtyResidencyCodes: [String: Set<String>] = [
    "Internal Medicine": ["140", "700", "705", "715", "740", "742", "745", "751", "766", "785"],
    "Family Medicine": ["120", "720", "752", "753", "795"],
    "Emergency Medicine": ["110", "705", "725", "795", "796", "797"],
    "Pediatrics": ["320", "700", "725", "726", "730", "735", "765", "790"],
    "General Surgery": ["440"],
    "OB/GYN": ["220"],
    "Psychiatry": ["400", "715", "720", "730", "755"],
    "Neurology": ["180", "745", "755"],
    "Anesthesiology": ["040", "726", "742", "796"],
    "Radiology": ["420", "770"],
    "Interventional Radiology - Integrated": ["416"],
    "Pathology": ["300"],
    "Orthopedics": ["260"],
    "ENT": ["280"],
    "Urology": ["480"],
    "PM&R": ["340", "735"],
    "Dermatology": ["080", "785", "790"],
    "Neurosurgery": ["160"],
    "Child Neurology": ["185"],
    "Nuclear Medicine": ["200", "770"],
    "Radiation Oncology": ["430"],
    "Plastic Surgery": ["360", "362"],
    "Ophthalmology": ["240"],
    "Thoracic Surgery - Integrated": ["461"],
    "Vascular Surgery - Integrated": ["451"],
    "Transitional Year": ["999"],
    "Aerospace Medicine": ["383", "797"],
    "Occupational and Environmental Medicine": ["382"],
    "Public Health and General Preventive Medicine": ["380"],
    "Osteopathic Neuromusculoskeletal Medicine": ["275", "753"],
  ]

  private static let fallbackAdditionalFellowshipCodes: [String: Set<String>] = [
    "Emergency Medicine": ["404", "520", "540", "530"],
    "Family Medicine": ["404", "520", "540", "127"],
    "Internal Medicine": ["404", "520", "540", "530"],
    "Pediatrics": ["404", "520", "540"],
    "Psychiatry": ["404", "520", "540"],
    "Neurology": ["404", "520", "540", "550"],
    "Anesthesiology": ["404", "520", "540", "530"],
    "PM&R": ["404", "520", "540"],
    "General Surgery": ["060", "450", "460", "446", "445", "442", "443"],
    "OB/GYN": ["754"],
    "Radiology": ["415", "421", "422", "423", "424", "425", "426", "427"],
  ]
}
