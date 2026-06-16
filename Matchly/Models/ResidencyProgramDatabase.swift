//
//  ResidencyProgramDatabase.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import Foundation
import Combine

struct ResidencyProgramInfo: Identifiable, Codable {
    let id: String
    let name: String
    let hospital: String
    let city: String
    let state: String
    let address: String? // Full street address
    let specialty: String
    let type: String // Academic, Community, Hybrid
    let accreditationID: String? // ACGME Program Code
    let websiteURL: String? // Program website URL
    let contactEmail: String? // Contact email
    let contactPhone: String? // Contact phone
    let programCoordinator: String? // Program coordinator name
    let programDirector: String? // Program director from ACGME
    var isIMGFriendly: Bool? // IMG-friendly status (nil = unknown, true = friendly, false = not friendly)
    
    var displayName: String {
        if name.isEmpty {
            return hospital
        }
        return "\(name) - \(hospital)"
    }
    
    var location: String {
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedState = state.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (trimmedCity.isEmpty, trimmedState.isEmpty) {
        case (false, false):
            return "\(trimmedCity), \(trimmedState)"
        case (false, true):
            return trimmedCity
        case (true, false):
            return trimmedState
        default:
            return ""
        }
    }
    
    // Convenience initializer for backward compatibility
    init(id: String, name: String, hospital: String, city: String, state: String, specialty: String, type: String, accreditationID: String? = nil, websiteURL: String? = nil, contactEmail: String? = nil, contactPhone: String? = nil, programCoordinator: String? = nil, programDirector: String? = nil, address: String? = nil, isIMGFriendly: Bool? = nil) {
        self.id = id
        self.name = name
        self.hospital = hospital
        self.city = city
        self.state = state
        self.specialty = specialty
        self.type = type
        self.accreditationID = accreditationID
        self.websiteURL = websiteURL
        self.contactEmail = contactEmail
        self.contactPhone = contactPhone
        self.programCoordinator = programCoordinator
        self.programDirector = programDirector
        self.address = address
        self.isIMGFriendly = isIMGFriendly
    }
}

struct ProgramSearchResults {
    let programs: [ResidencyProgramInfo]
    let totalCount: Int
    let isTruncated: Bool
}

final class ResidencyProgramDatabase: ObservableObject {
    static let shared = ResidencyProgramDatabase()

    static let defaultResultLimit = 300

    @Published private(set) var isReady = false
    @Published private(set) var programCount = 0
    @Published private(set) var residencyCount = 0
    @Published private(set) var fellowshipCount = 0

    private var programs: [ResidencyProgramInfo] = []
    private var residencyPrograms: [ResidencyProgramInfo] = []
    private var fellowshipPrograms: [ResidencyProgramInfo] = []
    private let lock = NSLock()

    init() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.loadPrograms()
        }
    }

    private func withPrograms<T>(_ work: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return work()
    }

    // State name to abbreviation mapping
    private let stateToAbbrev: [String: String] = [
        "alabama": "AL", "alaska": "AK", "arizona": "AZ", "arkansas": "AR",
        "california": "CA", "colorado": "CO", "connecticut": "CT", "delaware": "DE",
        "florida": "FL", "georgia": "GA", "hawaii": "HI", "idaho": "ID",
        "illinois": "IL", "indiana": "IN", "iowa": "IA", "kansas": "KS",
        "kentucky": "KY", "louisiana": "LA", "maine": "ME", "maryland": "MD",
        "massachusetts": "MA", "michigan": "MI", "minnesota": "MN", "mississippi": "MS",
        "missouri": "MO", "montana": "MT", "nebraska": "NE", "nevada": "NV",
        "new hampshire": "NH", "new jersey": "NJ", "new mexico": "NM", "new york": "NY",
        "north carolina": "NC", "north dakota": "ND", "ohio": "OH", "oklahoma": "OK",
        "oregon": "OR", "pennsylvania": "PA", "rhode island": "RI", "south carolina": "SC",
        "south dakota": "SD", "tennessee": "TN", "texas": "TX", "utah": "UT",
        "vermont": "VT", "virginia": "VA", "washington": "WA", "west virginia": "WV",
        "wisconsin": "WI", "wyoming": "WY", "district of columbia": "DC", "puerto rico": "PR"
    ]
    
    func search(
        query: String,
        specialty: String? = nil,
        specialties: [String]? = nil,
        fellowshipCodes: Set<String>? = nil,
        stateFilter: String? = nil,
        stateFilters: Set<String>? = nil,
        programTypeFilter: String? = nil,
        programTypes: [String]? = nil,
        trainingLevel: ProgramTrainingLevel? = nil,
        imgFriendlyOnly: Bool = false,
        limit: Int = ResidencyProgramDatabase.defaultResultLimit
    ) -> ProgramSearchResults {
        withPrograms {
            performSearch(
                query: query,
                specialty: specialty,
                specialties: specialties,
                fellowshipCodes: fellowshipCodes,
                stateFilter: stateFilter,
                stateFilters: stateFilters,
                programTypeFilter: programTypeFilter,
                programTypes: programTypes,
                trainingLevel: trainingLevel,
                imgFriendlyOnly: imgFriendlyOnly,
                limit: limit
            )
        }
    }

    /// Backward-compatible search that returns all matches (uncapped).
    func searchPrograms(
        query: String,
        specialty: String? = nil,
        specialties: [String]? = nil,
        stateFilter: String? = nil,
        stateFilters: Set<String>? = nil,
        programTypeFilter: String? = nil,
        programTypes: [String]? = nil,
        trainingLevel: ProgramTrainingLevel? = nil,
        imgFriendlyOnly: Bool = false
    ) -> [ResidencyProgramInfo] {
        search(
            query: query,
            specialty: specialty,
            specialties: specialties,
            fellowshipCodes: nil,
            stateFilter: stateFilter,
            stateFilters: stateFilters,
            programTypeFilter: programTypeFilter,
            programTypes: programTypes,
            trainingLevel: trainingLevel,
            imgFriendlyOnly: imgFriendlyOnly,
            limit: Int.max
        ).programs
    }

    private func performSearch(
        query: String,
        specialty: String?,
        specialties: [String]?,
        fellowshipCodes: Set<String>?,
        stateFilter: String?,
        stateFilters: Set<String>?,
        programTypeFilter: String?,
        programTypes: [String]?,
        trainingLevel: ProgramTrainingLevel?,
        imgFriendlyOnly: Bool,
        limit: Int
    ) -> ProgramSearchResults {
        let lowerQuery = query.lowercased().trimmingCharacters(in: .whitespaces)

        let pool: [ResidencyProgramInfo]
        switch trainingLevel {
        case .residency:
            pool = residencyPrograms
        case .fellowship:
            pool = fellowshipPrograms
        case nil:
            pool = programs
        }

        var totalCount = 0
        var results: [ResidencyProgramInfo] = []
        results.reserveCapacity(min(limit, pool.count))

        for program in pool {
            guard matchesProgram(
                program,
                lowerQuery: lowerQuery,
                specialty: specialty,
                specialties: specialties,
                fellowshipCodes: fellowshipCodes,
                stateFilter: stateFilter,
                stateFilters: stateFilters,
                programTypeFilter: programTypeFilter,
                programTypes: programTypes,
                imgFriendlyOnly: imgFriendlyOnly
            ) else { continue }

            totalCount += 1
            if results.count < limit {
                results.append(program)
            }
        }

        return ProgramSearchResults(
            programs: results,
            totalCount: totalCount,
            isTruncated: totalCount > results.count
        )
    }

    private func matchesProgram(
        _ program: ResidencyProgramInfo,
        lowerQuery: String,
        specialty: String?,
        specialties: [String]?,
        fellowshipCodes: Set<String>?,
        stateFilter: String?,
        stateFilters: Set<String>?,
        programTypeFilter: String?,
        programTypes: [String]?,
        imgFriendlyOnly: Bool
    ) -> Bool {
        let matchesSpecialty: Bool
        if let specialties, !specialties.isEmpty {
            matchesSpecialty = SpecialtyFormatter.matchesAny(userSpecialties: specialties, program: program)
        } else if let specialty {
            matchesSpecialty = program.specialty == specialty
                || SpecialtyFormatter.matches(userSpecialty: specialty, program: program)
        } else {
            matchesSpecialty = true
        }

        let matchesFellowshipType: Bool
        if let fellowshipCodes, !fellowshipCodes.isEmpty {
            let programCode = ProgramTrainingLevelClassifier.specialtyCode(for: program)
            matchesFellowshipType = programCode.map { fellowshipCodes.contains($0) } ?? false
        } else {
            matchesFellowshipType = true
        }

        let matchesState: Bool
        if let stateFilters, !stateFilters.isEmpty {
            let programStateUpper = program.state.uppercased()
            matchesState = stateFilters.contains { filterState in
                let filterUpper = filterState.uppercased()
                if filterUpper == programStateUpper { return true }
                if let abbrev = stateToAbbrev[filterState.lowercased()], abbrev.uppercased() == programStateUpper {
                    return true
                }
                if let programAbbrev = stateToAbbrev[program.state.lowercased()], programAbbrev.uppercased() == filterUpper {
                    return true
                }
                return false
            }
        } else if let stateFilter, !stateFilter.isEmpty {
            let lowerStateFilter = stateFilter.lowercased()
            let programStateLower = program.state.lowercased()

            if lowerStateFilter == programStateLower {
                matchesState = true
            } else if let abbrev = stateToAbbrev[lowerStateFilter], abbrev.uppercased() == program.state.uppercased() {
                matchesState = true
            } else if programStateLower.contains(lowerStateFilter) || lowerStateFilter.contains(programStateLower) {
                matchesState = true
            } else {
                matchesState = false
            }
        } else {
            matchesState = true
        }

        let matchesType: Bool
        if let programTypes, !programTypes.isEmpty {
            if programTypes.contains("IMG-Friendly") {
                if programTypes.count == 1 {
                    matchesType = program.isIMGFriendly == true
                } else {
                    let otherTypes = programTypes.filter { $0 != "IMG-Friendly" }
                    matchesType = (program.isIMGFriendly == true) || otherTypes.contains(program.type)
                }
            } else {
                matchesType = programTypes.contains(program.type)
            }
        } else if let programTypeFilter {
            matchesType = programTypeFilter == "All" || program.type == programTypeFilter
        } else {
            matchesType = true
        }

        let matchesIMG: Bool
        if imgFriendlyOnly && programTypes == nil {
            matchesIMG = program.isIMGFriendly == true
        } else {
            matchesIMG = true
        }

        let matchesQuery: Bool
        if lowerQuery.isEmpty {
            matchesQuery = true
        } else {
            let normalizedState = stateToAbbrev[lowerQuery] ?? lowerQuery

            let cityExactMatch = program.city.lowercased() == lowerQuery
            let cityContainsMatch = program.city.lowercased().contains(lowerQuery)
            let stateExactMatch = program.state.lowercased() == lowerQuery ||
                normalizedState.uppercased() == program.state.uppercased() ||
                (stateToAbbrev[lowerQuery]?.uppercased() == program.state.uppercased())
            let hospitalMatch = program.hospital.lowercased().contains(lowerQuery)
            let nameMatch = program.name.lowercased().contains(lowerQuery)
            let idMatch = program.accreditationID?.lowercased() == lowerQuery ||
                (program.accreditationID?.lowercased().contains(lowerQuery) ?? false)

            matchesQuery = cityExactMatch || cityContainsMatch || stateExactMatch || hospitalMatch || nameMatch || idMatch
        }

        return matchesSpecialty && matchesFellowshipType && matchesState && matchesType && matchesIMG && matchesQuery
    }

    func getAllPrograms(specialty: String? = nil, specialties: [String]? = nil, trainingLevel: ProgramTrainingLevel? = nil) -> [ResidencyProgramInfo] {
        withPrograms {
            let pool: [ResidencyProgramInfo]
            switch trainingLevel {
            case .residency:
                pool = residencyPrograms
            case .fellowship:
                pool = fellowshipPrograms
            case nil:
                pool = programs
            }

            if let specialties, !specialties.isEmpty {
                return pool.filter { SpecialtyFormatter.matchesAny(userSpecialties: specialties, program: $0) }
            }
            if let specialty {
                return pool.filter {
                    $0.specialty == specialty || SpecialtyFormatter.matches(userSpecialty: specialty, program: $0)
                }
            }
            return pool
        }
    }

    private func publishCatalogCounts() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.programCount = self.programs.count
            self.residencyCount = self.residencyPrograms.count
            self.fellowshipCount = self.fellowshipPrograms.count
            self.isReady = true
        }
    }

    func program(withAccreditationID accreditationID: String) -> ResidencyProgramInfo? {
        let trimmed = accreditationID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return withPrograms {
            programs.first {
                $0.accreditationID == trimmed || $0.id == trimmed
            }
        }
    }

    private func indexLoadedPrograms(_ loaded: [ResidencyProgramInfo]) {
        lock.lock()
        programs = loaded
        residencyPrograms = loaded.filter { $0.trainingLevel == .residency }
        fellowshipPrograms = loaded.filter { $0.trainingLevel == .fellowship }
        lock.unlock()
        publishCatalogCounts()
    }
    
    // MARK: - ERAS Data Loading
    
    /// Load programs from bundled JSON (ACGME or ERAS format).
    func loadFromERASJSON(data: Data) throws {
        let decoder = JSONDecoder()
        let loaded = try decoder.decode([ResidencyProgramInfo].self, from: data)
        let merged = withPrograms {
            programs.append(contentsOf: loaded)
            return programs
        }
        indexLoadedPrograms(merged)
    }
    
    /// Load programs from ERAS JSON file in the app bundle
    func loadFromERASJSONFile(filename: String) {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Warning: Could not load ERAS data file: \(filename).json")
            return
        }
        
        do {
            try loadFromERASJSON(data: data)
            print("Successfully loaded ERAS data from \(filename).json")
        } catch {
            print("Error loading ERAS data: \(error)")
        }
    }
    
    /// Load programs from ERAS JSON file at a specific URL (for user-imported files)
    func loadFromERASJSONURL(url: URL) throws {
        let data = try Data(contentsOf: url)
        try loadFromERASJSON(data: data)
    }
    
    /// Clear existing programs and load only from bundled JSON data.
    func replaceWithERASData(data: Data) throws {
        let decoder = JSONDecoder()
        let loaded = try decoder.decode([ResidencyProgramInfo].self, from: data)
        indexLoadedPrograms(loaded)
    }
    
    private func loadPrograms() {
        // Prefer ACGME catalog (full US accreditation list), then ERAS fallback.
        let possibleNames = ["ACGME_2026", "Data/ACGME_2026", "ERAS2026", "Data/ERAS2026"]
        
        for name in possibleNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "json"),
               let data = try? Data(contentsOf: url) {
                do {
                    try replaceWithERASData(data: data)
                    print("✓ Loaded programs from \(name) database")
                    return
                } catch {
                    print("⚠️ Error loading program data, falling back to hardcoded programs: \(error)")
                }
            }
        }
        
        // Fallback to hardcoded programs if bundled data not available
        loadInternalMedicinePrograms()
        loadFamilyMedicinePrograms()
        loadEmergencyMedicinePrograms()
        loadPediatricsPrograms()
        loadGeneralSurgeryPrograms()
        loadPsychiatryPrograms()
        loadOBGYNPrograms()
        loadAnesthesiologyPrograms()
        loadRadiologyPrograms()
        loadNeurologyPrograms()
        loadPathologyPrograms()
        loadOrthopedicsPrograms()
        loadENTPrograms()
        loadUrologyPrograms()
        loadPMRPrograms()
        loadDermatologyPrograms()
        loadNeurosurgeryPrograms()
        indexLoadedPrograms(withPrograms { programs })
    }
    
    private func loadInternalMedicinePrograms() {
        programs.append(contentsOf: [
            // Top Academic Programs
            ResidencyProgramInfo(id: "im_001", name: "Internal Medicine", hospital: "Johns Hopkins Hospital", city: "Baltimore", state: "MD", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_002", name: "Internal Medicine", hospital: "Massachusetts General Hospital", city: "Boston", state: "MA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_003", name: "Internal Medicine", hospital: "Brigham and Women's Hospital", city: "Boston", state: "MA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_004", name: "Internal Medicine", hospital: "Mayo Clinic", city: "Rochester", state: "MN", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_005", name: "Internal Medicine", hospital: "Cleveland Clinic", city: "Cleveland", state: "OH", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_006", name: "Internal Medicine", hospital: "New York-Presbyterian Hospital", city: "New York", state: "NY", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_007", name: "Internal Medicine", hospital: "UCSF Medical Center", city: "San Francisco", state: "CA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_008", name: "Internal Medicine", hospital: "Stanford Hospital", city: "Stanford", state: "CA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_009", name: "Internal Medicine", hospital: "Duke University Hospital", city: "Durham", state: "NC", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_010", name: "Internal Medicine", hospital: "University of Pennsylvania", city: "Philadelphia", state: "PA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_011", name: "Internal Medicine", hospital: "Yale-New Haven Hospital", city: "New Haven", state: "CT", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_012", name: "Internal Medicine", hospital: "University of Chicago Medical Center", city: "Chicago", state: "IL", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_013", name: "Internal Medicine", hospital: "Northwestern Memorial Hospital", city: "Chicago", state: "IL", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_014", name: "Internal Medicine", hospital: "Vanderbilt University Medical Center", city: "Nashville", state: "TN", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_015", name: "Internal Medicine", hospital: "Washington University Barnes-Jewish Hospital", city: "St. Louis", state: "MO", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_016", name: "Internal Medicine", hospital: "University of Michigan Hospital", city: "Ann Arbor", state: "MI", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_017", name: "Internal Medicine", hospital: "UCLA Medical Center", city: "Los Angeles", state: "CA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_018", name: "Internal Medicine", hospital: "Cedars-Sinai Medical Center", city: "Los Angeles", state: "CA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_019", name: "Internal Medicine", hospital: "Mount Sinai Hospital", city: "New York", state: "NY", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_020", name: "Internal Medicine", hospital: "NYU Langone Health", city: "New York", state: "NY", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_021", name: "Internal Medicine", hospital: "Columbia University Medical Center", city: "New York", state: "NY", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_022", name: "Internal Medicine", hospital: "Weill Cornell Medical Center", city: "New York", state: "NY", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_023", name: "Internal Medicine", hospital: "Emory University Hospital", city: "Atlanta", state: "GA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_024", name: "Internal Medicine", hospital: "University of Washington Medical Center", city: "Seattle", state: "WA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_025", name: "Internal Medicine", hospital: "University of Texas Southwestern", city: "Dallas", state: "TX", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_026", name: "Internal Medicine", hospital: "Baylor College of Medicine", city: "Houston", state: "TX", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_027", name: "Internal Medicine", hospital: "University of California San Diego", city: "San Diego", state: "CA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_028", name: "Internal Medicine", hospital: "University of California Irvine", city: "Irvine", state: "CA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_029", name: "Internal Medicine", hospital: "University of California Davis", city: "Sacramento", state: "CA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_030", name: "Internal Medicine", hospital: "University of California Los Angeles", city: "Los Angeles", state: "CA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_031", name: "Internal Medicine", hospital: "University of Pittsburgh Medical Center", city: "Pittsburgh", state: "PA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_032", name: "Internal Medicine", hospital: "University of Wisconsin Hospital", city: "Madison", state: "WI", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_033", name: "Internal Medicine", hospital: "University of Minnesota Medical Center", city: "Minneapolis", state: "MN", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_034", name: "Internal Medicine", hospital: "University of Colorado Hospital", city: "Aurora", state: "CO", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_035", name: "Internal Medicine", hospital: "University of Utah Hospital", city: "Salt Lake City", state: "UT", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_036", name: "Internal Medicine", hospital: "Oregon Health & Science University", city: "Portland", state: "OR", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_037", name: "Internal Medicine", hospital: "University of Arizona Medical Center", city: "Tucson", state: "AZ", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_038", name: "Internal Medicine", hospital: "Mayo Clinic Arizona", city: "Phoenix", state: "AZ", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_039", name: "Internal Medicine", hospital: "University of Miami Hospital", city: "Miami", state: "FL", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_040", name: "Internal Medicine", hospital: "University of Florida Shands Hospital", city: "Gainesville", state: "FL", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_041", name: "Internal Medicine", hospital: "University of South Florida", city: "Tampa", state: "FL", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_042", name: "Internal Medicine", hospital: "University of North Carolina", city: "Chapel Hill", state: "NC", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_043", name: "Internal Medicine", hospital: "Wake Forest Baptist Medical Center", city: "Winston-Salem", state: "NC", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_044", name: "Internal Medicine", hospital: "Medical University of South Carolina", city: "Charleston", state: "SC", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_045", name: "Internal Medicine", hospital: "University of Virginia Medical Center", city: "Charlottesville", state: "VA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_046", name: "Internal Medicine", hospital: "Virginia Commonwealth University", city: "Richmond", state: "VA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_047", name: "Internal Medicine", hospital: "Georgetown University Hospital", city: "Washington", state: "DC", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_048", name: "Internal Medicine", hospital: "George Washington University Hospital", city: "Washington", state: "DC", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_049", name: "Internal Medicine", hospital: "University of Maryland Medical Center", city: "Baltimore", state: "MD", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_050", name: "Internal Medicine", hospital: "Thomas Jefferson University Hospital", city: "Philadelphia", state: "PA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_051", name: "Internal Medicine", hospital: "Temple University Hospital", city: "Philadelphia", state: "PA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_052", name: "Internal Medicine", hospital: "Drexel University College of Medicine", city: "Philadelphia", state: "PA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_053", name: "Internal Medicine", hospital: "Rutgers Robert Wood Johnson", city: "New Brunswick", state: "NJ", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_054", name: "Internal Medicine", hospital: "Rutgers New Jersey Medical School", city: "Newark", state: "NJ", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_055", name: "Internal Medicine", hospital: "Hackensack University Medical Center", city: "Hackensack", state: "NJ", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_056", name: "Internal Medicine", hospital: "University of Rochester Medical Center", city: "Rochester", state: "NY", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_057", name: "Internal Medicine", hospital: "SUNY Upstate Medical University", city: "Syracuse", state: "NY", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_058", name: "Internal Medicine", hospital: "SUNY Downstate Medical Center", city: "Brooklyn", state: "NY", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_059", name: "Internal Medicine", hospital: "Albany Medical Center", city: "Albany", state: "NY", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_060", name: "Internal Medicine", hospital: "Boston University Medical Center", city: "Boston", state: "MA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_061", name: "Internal Medicine", hospital: "Tufts Medical Center", city: "Boston", state: "MA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_062", name: "Internal Medicine", hospital: "Beth Israel Deaconess Medical Center", city: "Boston", state: "MA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_063", name: "Internal Medicine", hospital: "Brown University", city: "Providence", state: "RI", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_064", name: "Internal Medicine", hospital: "Dartmouth-Hitchcock Medical Center", city: "Lebanon", state: "NH", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_065", name: "Internal Medicine", hospital: "University of Vermont Medical Center", city: "Burlington", state: "VT", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_066", name: "Internal Medicine", hospital: "Indiana University Hospital", city: "Indianapolis", state: "IN", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_067", name: "Internal Medicine", hospital: "Ohio State University Wexner Medical Center", city: "Columbus", state: "OH", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_068", name: "Internal Medicine", hospital: "Case Western Reserve University", city: "Cleveland", state: "OH", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_069", name: "Internal Medicine", hospital: "University of Cincinnati Medical Center", city: "Cincinnati", state: "OH", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_070", name: "Internal Medicine", hospital: "University of Kentucky Medical Center", city: "Lexington", state: "KY", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_071", name: "Internal Medicine", hospital: "University of Louisville Hospital", city: "Louisville", state: "KY", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_072", name: "Internal Medicine", hospital: "Vanderbilt University Medical Center", city: "Nashville", state: "TN", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_073", name: "Internal Medicine", hospital: "University of Tennessee Medical Center", city: "Knoxville", state: "TN", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_074", name: "Internal Medicine", hospital: "University of Alabama at Birmingham", city: "Birmingham", state: "AL", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_075", name: "Internal Medicine", hospital: "University of Mississippi Medical Center", city: "Jackson", state: "MS", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_076", name: "Internal Medicine", hospital: "University of Arkansas Medical Center", city: "Little Rock", state: "AR", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_077", name: "Internal Medicine", hospital: "Louisiana State University", city: "New Orleans", state: "LA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_078", name: "Internal Medicine", hospital: "Tulane University Medical Center", city: "New Orleans", state: "LA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_079", name: "Internal Medicine", hospital: "University of Oklahoma Medical Center", city: "Oklahoma City", state: "OK", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_080", name: "Internal Medicine", hospital: "University of Kansas Medical Center", city: "Kansas City", state: "KS", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_081", name: "Internal Medicine", hospital: "University of Missouri", city: "Columbia", state: "MO", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_082", name: "Internal Medicine", hospital: "University of Iowa Hospitals", city: "Iowa City", state: "IA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_083", name: "Internal Medicine", hospital: "University of Nebraska Medical Center", city: "Omaha", state: "NE", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_084", name: "Internal Medicine", hospital: "Creighton University Medical Center", city: "Omaha", state: "NE", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_085", name: "Internal Medicine", hospital: "University of South Dakota", city: "Sioux Falls", state: "SD", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_086", name: "Internal Medicine", hospital: "University of North Dakota", city: "Fargo", state: "ND", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_087", name: "Internal Medicine", hospital: "University of New Mexico Hospital", city: "Albuquerque", state: "NM", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_088", name: "Internal Medicine", hospital: "University of Nevada Las Vegas", city: "Las Vegas", state: "NV", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_089", name: "Internal Medicine", hospital: "University of Nevada Reno", city: "Reno", state: "NV", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_090", name: "Internal Medicine", hospital: "Loma Linda University Medical Center", city: "Loma Linda", state: "CA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_091", name: "Internal Medicine", hospital: "University of Southern California", city: "Los Angeles", state: "CA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_092", name: "Internal Medicine", hospital: "Harbor-UCLA Medical Center", city: "Torrance", state: "CA", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_093", name: "Internal Medicine", hospital: "Kaiser Permanente Los Angeles", city: "Los Angeles", state: "CA", specialty: "Internal Medicine", type: "Community"),
            ResidencyProgramInfo(id: "im_094", name: "Internal Medicine", hospital: "Scripps Mercy Hospital", city: "San Diego", state: "CA", specialty: "Internal Medicine", type: "Community"),
            ResidencyProgramInfo(id: "im_095", name: "Internal Medicine", hospital: "Santa Clara Valley Medical Center", city: "San Jose", state: "CA", specialty: "Internal Medicine", type: "Community"),
            ResidencyProgramInfo(id: "im_096", name: "Internal Medicine", hospital: "Kern Medical Center", city: "Bakersfield", state: "CA", specialty: "Internal Medicine", type: "Community"),
            ResidencyProgramInfo(id: "im_097", name: "Internal Medicine", hospital: "University of Hawaii", city: "Honolulu", state: "HI", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_098", name: "Internal Medicine", hospital: "University of Alaska Anchorage", city: "Anchorage", state: "AK", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_099", name: "Internal Medicine", hospital: "Maine Medical Center", city: "Portland", state: "ME", specialty: "Internal Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "im_100", name: "Internal Medicine", hospital: "Yale-New Haven Hospital", city: "New Haven", state: "CT", specialty: "Internal Medicine", type: "Academic"),
        ])
    }
    
    private func loadFamilyMedicinePrograms() {
        programs.append(contentsOf: [
            ResidencyProgramInfo(id: "fm_001", name: "Family Medicine", hospital: "University of Washington", city: "Seattle", state: "WA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_002", name: "Family Medicine", hospital: "University of North Carolina", city: "Chapel Hill", state: "NC", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_003", name: "Family Medicine", hospital: "Oregon Health & Science University", city: "Portland", state: "OR", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_004", name: "Family Medicine", hospital: "University of Colorado", city: "Denver", state: "CO", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_005", name: "Family Medicine", hospital: "University of California Davis", city: "Sacramento", state: "CA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_006", name: "Family Medicine", hospital: "UCSF San Francisco General", city: "San Francisco", state: "CA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_007", name: "Family Medicine", hospital: "University of Michigan", city: "Ann Arbor", state: "MI", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_008", name: "Family Medicine", hospital: "University of Wisconsin", city: "Madison", state: "WI", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_009", name: "Family Medicine", hospital: "University of Minnesota", city: "Minneapolis", state: "MN", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_010", name: "Family Medicine", hospital: "Mayo Clinic", city: "Rochester", state: "MN", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_011", name: "Family Medicine", hospital: "University of Iowa", city: "Iowa City", state: "IA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_012", name: "Family Medicine", hospital: "University of Missouri", city: "Columbia", state: "MO", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_013", name: "Family Medicine", hospital: "University of Kansas", city: "Kansas City", state: "KS", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_014", name: "Family Medicine", hospital: "University of Nebraska", city: "Omaha", state: "NE", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_015", name: "Family Medicine", hospital: "Creighton University", city: "Omaha", state: "NE", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_016", name: "Family Medicine", hospital: "University of Oklahoma", city: "Oklahoma City", state: "OK", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_017", name: "Family Medicine", hospital: "University of Texas Southwestern", city: "Dallas", state: "TX", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_018", name: "Family Medicine", hospital: "Baylor College of Medicine", city: "Houston", state: "TX", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_019", name: "Family Medicine", hospital: "University of Texas Health San Antonio", city: "San Antonio", state: "TX", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_020", name: "Family Medicine", hospital: "Texas A&M University", city: "Bryan", state: "TX", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_021", name: "Family Medicine", hospital: "University of Arkansas", city: "Little Rock", state: "AR", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_022", name: "Family Medicine", hospital: "Louisiana State University", city: "New Orleans", state: "LA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_023", name: "Family Medicine", hospital: "Tulane University", city: "New Orleans", state: "LA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_024", name: "Family Medicine", hospital: "University of Mississippi", city: "Jackson", state: "MS", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_025", name: "Family Medicine", hospital: "University of Alabama", city: "Birmingham", state: "AL", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_026", name: "Family Medicine", hospital: "University of Tennessee", city: "Knoxville", state: "TN", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_027", name: "Family Medicine", hospital: "Vanderbilt University", city: "Nashville", state: "TN", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_028", name: "Family Medicine", hospital: "University of Kentucky", city: "Lexington", state: "KY", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_029", name: "Family Medicine", hospital: "University of Louisville", city: "Louisville", state: "KY", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_030", name: "Family Medicine", hospital: "Indiana University", city: "Indianapolis", state: "IN", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_031", name: "Family Medicine", hospital: "Ohio State University", city: "Columbus", state: "OH", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_032", name: "Family Medicine", hospital: "Case Western Reserve", city: "Cleveland", state: "OH", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_033", name: "Family Medicine", hospital: "University of Cincinnati", city: "Cincinnati", state: "OH", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_034", name: "Family Medicine", hospital: "Wright State University", city: "Dayton", state: "OH", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_035", name: "Family Medicine", hospital: "University of Michigan", city: "Ann Arbor", state: "MI", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_036", name: "Family Medicine", hospital: "Wayne State University", city: "Detroit", state: "MI", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_037", name: "Family Medicine", hospital: "Michigan State University", city: "East Lansing", state: "MI", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_038", name: "Family Medicine", hospital: "University of Illinois", city: "Chicago", state: "IL", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_039", name: "Family Medicine", hospital: "Northwestern University", city: "Chicago", state: "IL", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_040", name: "Family Medicine", hospital: "University of Chicago", city: "Chicago", state: "IL", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_041", name: "Family Medicine", hospital: "Loyola University", city: "Maywood", state: "IL", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_042", name: "Family Medicine", hospital: "Southern Illinois University", city: "Springfield", state: "IL", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_043", name: "Family Medicine", hospital: "Rush University", city: "Chicago", state: "IL", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_044", name: "Family Medicine", hospital: "University of Wisconsin", city: "Madison", state: "WI", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_045", name: "Family Medicine", hospital: "Medical College of Wisconsin", city: "Milwaukee", state: "WI", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_046", name: "Family Medicine", hospital: "University of Minnesota", city: "Minneapolis", state: "MN", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_047", name: "Family Medicine", hospital: "Mayo Clinic", city: "Rochester", state: "MN", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_048", name: "Family Medicine", hospital: "University of Iowa", city: "Iowa City", state: "IA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_049", name: "Family Medicine", hospital: "Des Moines University", city: "Des Moines", state: "IA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_050", name: "Family Medicine", hospital: "University of Missouri", city: "Columbia", state: "MO", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_051", name: "Family Medicine", hospital: "Saint Louis University", city: "St. Louis", state: "MO", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_052", name: "Family Medicine", hospital: "University of Kansas", city: "Kansas City", state: "KS", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_053", name: "Family Medicine", hospital: "University of Nebraska", city: "Omaha", state: "NE", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_054", name: "Family Medicine", hospital: "Creighton University", city: "Omaha", state: "NE", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_055", name: "Family Medicine", hospital: "University of North Dakota", city: "Fargo", state: "ND", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_056", name: "Family Medicine", hospital: "University of South Dakota", city: "Sioux Falls", state: "SD", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_057", name: "Family Medicine", hospital: "University of Colorado", city: "Denver", state: "CO", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_058", name: "Family Medicine", hospital: "University of Utah", city: "Salt Lake City", state: "UT", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_059", name: "Family Medicine", hospital: "University of New Mexico", city: "Albuquerque", state: "NM", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_060", name: "Family Medicine", hospital: "University of Arizona", city: "Tucson", state: "AZ", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_061", name: "Family Medicine", hospital: "Mayo Clinic Arizona", city: "Phoenix", state: "AZ", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_062", name: "Family Medicine", hospital: "University of Nevada Las Vegas", city: "Las Vegas", state: "NV", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_063", name: "Family Medicine", hospital: "University of Nevada Reno", city: "Reno", state: "NV", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_064", name: "Family Medicine", hospital: "Oregon Health & Science University", city: "Portland", state: "OR", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_065", name: "Family Medicine", hospital: "University of Washington", city: "Seattle", state: "WA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_066", name: "Family Medicine", hospital: "University of California San Francisco", city: "San Francisco", state: "CA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_067", name: "Family Medicine", hospital: "University of California Los Angeles", city: "Los Angeles", state: "CA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_068", name: "Family Medicine", hospital: "University of California San Diego", city: "San Diego", state: "CA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_069", name: "Family Medicine", hospital: "University of California Irvine", city: "Irvine", state: "CA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_070", name: "Family Medicine", hospital: "University of California Davis", city: "Sacramento", state: "CA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_071", name: "Family Medicine", hospital: "Loma Linda University", city: "Loma Linda", state: "CA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_072", name: "Family Medicine", hospital: "University of Southern California", city: "Los Angeles", state: "CA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_073", name: "Family Medicine", hospital: "Stanford University", city: "Stanford", state: "CA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_074", name: "Family Medicine", hospital: "University of Hawaii", city: "Honolulu", state: "HI", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_075", name: "Family Medicine", hospital: "University of Alaska", city: "Anchorage", state: "AK", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_076", name: "Family Medicine", hospital: "University of Florida", city: "Gainesville", state: "FL", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_077", name: "Family Medicine", hospital: "University of South Florida", city: "Tampa", state: "FL", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_078", name: "Family Medicine", hospital: "University of Miami", city: "Miami", state: "FL", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_079", name: "Family Medicine", hospital: "Florida State University", city: "Tallahassee", state: "FL", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_080", name: "Family Medicine", hospital: "Nova Southeastern University", city: "Fort Lauderdale", state: "FL", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_081", name: "Family Medicine", hospital: "University of North Carolina", city: "Chapel Hill", state: "NC", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_082", name: "Family Medicine", hospital: "Wake Forest University", city: "Winston-Salem", state: "NC", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_083", name: "Family Medicine", hospital: "East Carolina University", city: "Greenville", state: "NC", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_084", name: "Family Medicine", hospital: "Duke University", city: "Durham", state: "NC", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_085", name: "Family Medicine", hospital: "Medical University of South Carolina", city: "Charleston", state: "SC", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_086", name: "Family Medicine", hospital: "University of South Carolina", city: "Columbia", state: "SC", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_087", name: "Family Medicine", hospital: "University of Georgia", city: "Augusta", state: "GA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_088", name: "Family Medicine", hospital: "Emory University", city: "Atlanta", state: "GA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_089", name: "Family Medicine", hospital: "Mercer University", city: "Macon", state: "GA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_090", name: "Family Medicine", hospital: "Morehouse School of Medicine", city: "Atlanta", state: "GA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_091", name: "Family Medicine", hospital: "University of Virginia", city: "Charlottesville", state: "VA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_092", name: "Family Medicine", hospital: "Virginia Commonwealth University", city: "Richmond", state: "VA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_093", name: "Family Medicine", hospital: "Eastern Virginia Medical School", city: "Norfolk", state: "VA", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_094", name: "Family Medicine", hospital: "West Virginia University", city: "Morgantown", state: "WV", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_095", name: "Family Medicine", hospital: "Marshall University", city: "Huntington", state: "WV", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_096", name: "Family Medicine", hospital: "Georgetown University", city: "Washington", state: "DC", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_097", name: "Family Medicine", hospital: "George Washington University", city: "Washington", state: "DC", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_098", name: "Family Medicine", hospital: "Howard University", city: "Washington", state: "DC", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_099", name: "Family Medicine", hospital: "University of Maryland", city: "Baltimore", state: "MD", specialty: "Family Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "fm_100", name: "Family Medicine", hospital: "Johns Hopkins University", city: "Baltimore", state: "MD", specialty: "Family Medicine", type: "Academic"),
        ])
    }
    
    private func loadEmergencyMedicinePrograms() {
        programs.append(contentsOf: [
            ResidencyProgramInfo(id: "em_001", name: "Emergency Medicine", hospital: "Denver Health", city: "Denver", state: "CO", specialty: "Emergency Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "em_002", name: "Emergency Medicine", hospital: "Highland Hospital", city: "Oakland", state: "CA", specialty: "Emergency Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "em_003", name: "Emergency Medicine", hospital: "Carolinas Medical Center", city: "Charlotte", state: "NC", specialty: "Emergency Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "em_004", name: "Emergency Medicine", hospital: "University of Cincinnati", city: "Cincinnati", state: "OH", specialty: "Emergency Medicine", type: "Academic"),
            ResidencyProgramInfo(id: "em_005", name: "Emergency Medicine", hospital: "Cook County Hospital", city: "Chicago", state: "IL", specialty: "Emergency Medicine", type: "Academic"),
        ])
    }
    
    private func loadPediatricsPrograms() {
        programs.append(contentsOf: [
            ResidencyProgramInfo(id: "peds_001", name: "Pediatrics", hospital: "Boston Children's Hospital", city: "Boston", state: "MA", specialty: "Pediatrics", type: "Academic"),
            ResidencyProgramInfo(id: "peds_002", name: "Pediatrics", hospital: "Children's Hospital of Philadelphia", city: "Philadelphia", state: "PA", specialty: "Pediatrics", type: "Academic"),
            ResidencyProgramInfo(id: "peds_003", name: "Pediatrics", hospital: "Cincinnati Children's Hospital", city: "Cincinnati", state: "OH", specialty: "Pediatrics", type: "Academic"),
            ResidencyProgramInfo(id: "peds_004", name: "Pediatrics", hospital: "Texas Children's Hospital", city: "Houston", state: "TX", specialty: "Pediatrics", type: "Academic"),
            ResidencyProgramInfo(id: "peds_005", name: "Pediatrics", hospital: "Seattle Children's Hospital", city: "Seattle", state: "WA", specialty: "Pediatrics", type: "Academic"),
        ])
    }
    
    private func loadGeneralSurgeryPrograms() {
        programs.append(contentsOf: [
            ResidencyProgramInfo(id: "surg_001", name: "General Surgery", hospital: "Massachusetts General Hospital", city: "Boston", state: "MA", specialty: "General Surgery", type: "Academic"),
            ResidencyProgramInfo(id: "surg_002", name: "General Surgery", hospital: "Johns Hopkins Hospital", city: "Baltimore", state: "MD", specialty: "General Surgery", type: "Academic"),
            ResidencyProgramInfo(id: "surg_003", name: "General Surgery", hospital: "Brigham and Women's Hospital", city: "Boston", state: "MA", specialty: "General Surgery", type: "Academic"),
            ResidencyProgramInfo(id: "surg_004", name: "General Surgery", hospital: "Mayo Clinic", city: "Rochester", state: "MN", specialty: "General Surgery", type: "Academic"),
            ResidencyProgramInfo(id: "surg_005", name: "General Surgery", hospital: "Cleveland Clinic", city: "Cleveland", state: "OH", specialty: "General Surgery", type: "Academic"),
        ])
    }
    
    private func loadPsychiatryPrograms() {
        programs.append(contentsOf: [
            ResidencyProgramInfo(id: "psych_001", name: "Psychiatry", hospital: "Massachusetts General Hospital", city: "Boston", state: "MA", specialty: "Psychiatry", type: "Academic"),
            ResidencyProgramInfo(id: "psych_002", name: "Psychiatry", hospital: "Yale-New Haven Hospital", city: "New Haven", state: "CT", specialty: "Psychiatry", type: "Academic"),
            ResidencyProgramInfo(id: "psych_003", name: "Psychiatry", hospital: "UCLA Medical Center", city: "Los Angeles", state: "CA", specialty: "Psychiatry", type: "Academic"),
            ResidencyProgramInfo(id: "psych_004", name: "Psychiatry", hospital: "Stanford Hospital", city: "Stanford", state: "CA", specialty: "Psychiatry", type: "Academic"),
            ResidencyProgramInfo(id: "psych_005", name: "Psychiatry", hospital: "Johns Hopkins Hospital", city: "Baltimore", state: "MD", specialty: "Psychiatry", type: "Academic"),
        ])
    }
    
    private func loadOBGYNPrograms() {
        programs.append(contentsOf: [
            ResidencyProgramInfo(id: "obgyn_001", name: "OB/GYN", hospital: "Brigham and Women's Hospital", city: "Boston", state: "MA", specialty: "OB/GYN", type: "Academic"),
            ResidencyProgramInfo(id: "obgyn_002", name: "OB/GYN", hospital: "Johns Hopkins Hospital", city: "Baltimore", state: "MD", specialty: "OB/GYN", type: "Academic"),
            ResidencyProgramInfo(id: "obgyn_003", name: "OB/GYN", hospital: "UCSF Medical Center", city: "San Francisco", state: "CA", specialty: "OB/GYN", type: "Academic"),
            ResidencyProgramInfo(id: "obgyn_004", name: "OB/GYN", hospital: "Mayo Clinic", city: "Rochester", state: "MN", specialty: "OB/GYN", type: "Academic"),
            ResidencyProgramInfo(id: "obgyn_005", name: "OB/GYN", hospital: "Cleveland Clinic", city: "Cleveland", state: "OH", specialty: "OB/GYN", type: "Academic"),
        ])
    }
    
    private func loadAnesthesiologyPrograms() {
        programs.append(contentsOf: [
            ResidencyProgramInfo(id: "anes_001", name: "Anesthesiology", hospital: "Massachusetts General Hospital", city: "Boston", state: "MA", specialty: "Anesthesiology", type: "Academic"),
            ResidencyProgramInfo(id: "anes_002", name: "Anesthesiology", hospital: "Johns Hopkins Hospital", city: "Baltimore", state: "MD", specialty: "Anesthesiology", type: "Academic"),
            ResidencyProgramInfo(id: "anes_003", name: "Anesthesiology", hospital: "Stanford Hospital", city: "Stanford", state: "CA", specialty: "Anesthesiology", type: "Academic"),
            ResidencyProgramInfo(id: "anes_004", name: "Anesthesiology", hospital: "Duke University Hospital", city: "Durham", state: "NC", specialty: "Anesthesiology", type: "Academic"),
            ResidencyProgramInfo(id: "anes_005", name: "Anesthesiology", hospital: "UCSF Medical Center", city: "San Francisco", state: "CA", specialty: "Anesthesiology", type: "Academic"),
        ])
    }
    
    private func loadRadiologyPrograms() {
        programs.append(contentsOf: [
            ResidencyProgramInfo(id: "rad_001", name: "Radiology", hospital: "Massachusetts General Hospital", city: "Boston", state: "MA", specialty: "Radiology", type: "Academic"),
            ResidencyProgramInfo(id: "rad_002", name: "Radiology", hospital: "Johns Hopkins Hospital", city: "Baltimore", state: "MD", specialty: "Radiology", type: "Academic"),
            ResidencyProgramInfo(id: "rad_003", name: "Radiology", hospital: "Stanford Hospital", city: "Stanford", state: "CA", specialty: "Radiology", type: "Academic"),
            ResidencyProgramInfo(id: "rad_004", name: "Radiology", hospital: "UCSF Medical Center", city: "San Francisco", state: "CA", specialty: "Radiology", type: "Academic"),
            ResidencyProgramInfo(id: "rad_005", name: "Radiology", hospital: "Mayo Clinic", city: "Rochester", state: "MN", specialty: "Radiology", type: "Academic"),
        ])
    }
    
    private func loadNeurologyPrograms() {
        programs.append(contentsOf: [
            ResidencyProgramInfo(id: "neuro_001", name: "Neurology", hospital: "Massachusetts General Hospital", city: "Boston", state: "MA", specialty: "Neurology", type: "Academic"),
            ResidencyProgramInfo(id: "neuro_002", name: "Neurology", hospital: "Johns Hopkins Hospital", city: "Baltimore", state: "MD", specialty: "Neurology", type: "Academic"),
            ResidencyProgramInfo(id: "neuro_003", name: "Neurology", hospital: "Mayo Clinic", city: "Rochester", state: "MN", specialty: "Neurology", type: "Academic"),
            ResidencyProgramInfo(id: "neuro_004", name: "Neurology", hospital: "Cleveland Clinic", city: "Cleveland", state: "OH", specialty: "Neurology", type: "Academic"),
            ResidencyProgramInfo(id: "neuro_005", name: "Neurology", hospital: "UCSF Medical Center", city: "San Francisco", state: "CA", specialty: "Neurology", type: "Academic"),
        ])
    }
    
    private func loadPathologyPrograms() {
        programs.append(contentsOf: [
            // Placeholder - add programs as needed
        ])
    }
    
    private func loadOrthopedicsPrograms() {
        programs.append(contentsOf: [
            // Placeholder - add programs as needed
        ])
    }
    
    private func loadENTPrograms() {
        programs.append(contentsOf: [
            // Placeholder - add programs as needed
        ])
    }
    
    private func loadUrologyPrograms() {
        programs.append(contentsOf: [
            // Placeholder - add programs as needed
        ])
    }
    
    private func loadPMRPrograms() {
        programs.append(contentsOf: [
            // Placeholder - add programs as needed
        ])
    }
    
    private func loadDermatologyPrograms() {
        programs.append(contentsOf: [
            // Placeholder - add programs as needed
        ])
    }
    
    private func loadNeurosurgeryPrograms() {
        programs.append(contentsOf: [
            // Placeholder - add programs as needed
        ])
    }
}

