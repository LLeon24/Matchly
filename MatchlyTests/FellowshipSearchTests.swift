//
//  FellowshipSearchTests.swift
//  MatchlyTests
//

import Testing
@testable import Matchly

struct FellowshipSearchTests {
  @Test func clinicalInformaticsUsesAccreditationPrefixOverCatalogSuffix() {
    let program = ResidencyProgramInfo(
      id: "1394800001",
      name: "Clinical Informatics",
      hospital: "Example Medical Center",
      city: "Boston",
      state: "MA",
      specialty: "Clinical Informatics (111)",
      accreditationID: "1394800001"
    )

    #expect(ERASTrainingLevel.specialtyCode(for: program) == "139")
    #expect(ProgramTrainingLevelClassifier.specialtyCode(for: program) == "139")
  }

  @Test func parentResidencyAccreditationKeepsFellowshipCatalogSuffix() {
    let program = ResidencyProgramInfo(
      id: "1400512012",
      name: "Pulmonary Disease and Critical Care Medicine",
      hospital: "Example Medical Center",
      city: "Boston",
      state: "MA",
      specialty: "Pulmonary Disease and Critical Care Medicine (156)",
      accreditationID: "1400512012"
    )

    #expect(ERASTrainingLevel.specialtyCode(for: program) == "156")
  }

  @Test func hematologyFellowshipMatchesSelectedERASCode() {
    let program = ResidencyProgramInfo(
      id: "1551114005",
      name: "Hematology and Medical Oncology",
      hospital: "Example Medical Center",
      city: "Boston",
      state: "MA",
      specialty: "Hematology and Medical Oncology (155)",
      accreditationID: "1551114005"
    )

    let results = ResidencyProgramDatabase.shared.search(
      query: "",
      specialties: ["Internal Medicine"],
      fellowshipCodes: ["155"],
      trainingLevel: .fellowship,
      limit: 50
    )

    #expect(ProgramTrainingLevelClassifier.specialtyCode(for: program) == "155")
    #expect(results.totalCount > 0)
  }

  @Test func clinicalInformaticsIMSearchFindsProgramsAfterCodeFix() {
    let results = ResidencyProgramDatabase.shared.search(
      query: "",
      specialties: ["Internal Medicine"],
      fellowshipCodes: ["139"],
      trainingLevel: .fellowship,
      limit: 50
    )

    #expect(results.totalCount > 0)
  }

  @Test func brainInjuryMedicineMatchesCatalogSuffixWhenAccreditationPrefixDiffers() {
    let results = ResidencyProgramDatabase.shared.search(
      query: "",
      fellowshipCodes: ["189"],
      trainingLevel: .fellowship,
      limit: 50
    )

    #expect(results.totalCount > 0)
  }

  @Test func preventiveMedicalToxicologyMatchesCatalogSuffixWhenAccreditationPrefixDiffers() {
    let results = ResidencyProgramDatabase.shared.search(
      query: "",
      fellowshipCodes: ["399"],
      trainingLevel: .fellowship,
      limit: 50
    )

    #expect(results.totalCount > 0)
  }

  @Test func emergencyClinicalInformaticsDoesNotReturnOtherFieldsViaGenericSuffix() {
    let results = ResidencyProgramDatabase.shared.search(
      query: "",
      fellowshipCodes: ["111"],
      trainingLevel: .fellowship,
      limit: 200
    )

    #expect(results.totalCount == 0)
  }
}
