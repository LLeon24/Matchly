//
//  ProgramSearchMatcher.swift
//  Matchly
//

import Foundation

struct ProgramSearchIndex {
    let haystack: String
    let acronym: String
    let hospitalAcronym: String
}

enum ProgramSearchMatcher {
    /// Avoid overly broad acronym matches (e.g. "st", "la").
    static let minAcronymQueryLength = 3

    private static let stopWords: Set<String> = [
        "a", "an", "and", "at", "for", "in", "of", "or", "the", "to", "with"
    ]

    /// Common nicknames and acronyms → substrings expected in program names.
    private static let queryAliases: [String: [String]] = [
        "fsu": ["florida state"],
        "uf": ["university of florida"],
        "ucf": ["central florida"],
        "usf": ["south florida"],
        "fiu": ["florida international"],
        "um": ["university of miami"],
        "uab": ["university of alabama"],
        "uams": ["arkansas for medical sciences"],
        "uth": ["ut health", "uthealth"],
        "utsw": ["ut southwestern"],
        "utmb": ["ut medical branch"],
        "baylor": ["baylor"],
        "emory": ["emory"],
        "duke": ["duke"],
        "vandy": ["vanderbilt"],
        "vanderbilt": ["vanderbilt"],
        "hopkins": ["johns hopkins"],
        "mgh": ["massachusetts general"],
        "bwh": ["brigham"],
        "bmc": ["boston medical center"],
        "tufts": ["tufts"],
        "nyu": ["nyu", "new york university"],
        "nyp": ["new york-presbyterian", "new york presbyterian"],
        "penn": ["university of pennsylvania", "penn medicine", "hospital of the university of pennsylvania"],
        "hup": ["hospital of the university of pennsylvania"],
        "chop": ["children's hospital of philadelphia", "childrens hospital of philadelphia"],
        "upenn": ["university of pennsylvania"],
        "osu": ["ohio state"],
        "ohsu": ["ohsu", "oregon health"],
        "uw": ["university of washington", "uw medicine"],
        "uwm": ["university of wisconsin"],
        "uwash": ["university of washington"],
        "ucsd": ["san diego"],
        "ucd": ["uc davis", "davis"],
        "uci": ["irvine"],
        "ucsf": ["san francisco"],
        "usc": ["university of southern california", "usc"],
        "llu": ["loma linda"],
        "mayo": ["mayo clinic"],
        "cleveland": ["cleveland clinic"],
        "rush": ["rush university", "rush medical"],
        "northwestern": ["northwestern"],
        "uchicago": ["university of chicago"],
        "uic": ["university of illinois"],
        "loyola": ["loyola"],
        "musc": ["medical university of south carolina"],
        "vcu": ["virginia commonwealth"],
        "uva": ["university of virginia"],
        "vt": ["virginia tech", "carilion"],
        "unc": ["university of north carolina"],
        "wake": ["wake forest"],
        "campbell": ["campbell"],
        "ecu": ["east carolina"],
        "temple": ["temple"],
        "jeff": ["jefferson", "thomas jefferson"],
        "tju": ["thomas jefferson"],
        "drexel": ["drexel"],
        "pitt": ["university of pittsburgh"],
        "upmc": ["upmc", "university of pittsburgh"],
        "wvu": ["west virginia university"],
        "iu": ["indiana university"],
        "iuh": ["indiana university"],
        "umn": ["university of minnesota"],
        "umich": ["university of michigan", "michigan medicine"],
        "uofm": ["university of michigan", "university of minnesota"],
        "kumc": ["university of kansas"],
        "kcu": ["kansas city university"],
        "slu": ["saint louis university", "st louis university"],
        "wustl": ["washington university"],
        "washu": ["washington university"],
        "barnes": ["washington university", "barnes-jewish"],
        "utah": ["university of utah"],
        "cu": ["university of colorado", "columbia university"],
        "cuanschutz": ["university of colorado"],
        "unm": ["university of new mexico"],
        "ua": ["university of arizona"],
        "asu": ["arizona state"],
        "honor": ["honorhealth"],
        "banner": ["banner"],
        "advent": ["adventhealth"],
        "hca": ["hca"],
    ]

    private static var cache: [String: ProgramSearchIndex] = [:]
    private static let cacheLock = NSLock()

    static func warmCache(for programs: [ResidencyProgramInfo]) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache.removeAll(keepingCapacity: true)
        cache.reserveCapacity(programs.count)
        for program in programs {
            cache[program.id] = buildIndex(for: program)
        }
    }

    static func clearCache() {
        cacheLock.lock()
        cache.removeAll()
        cacheLock.unlock()
    }

    static func index(for program: ResidencyProgramInfo) -> ProgramSearchIndex {
        cacheLock.lock()
        if let cached = cache[program.id] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let built = buildIndex(for: program)
        cacheLock.lock()
        cache[program.id] = built
        cacheLock.unlock()
        return built
    }

    static func matches(
        query: String,
        program: ResidencyProgramInfo,
        stateToAbbrev: [String: String]
    ) -> Bool {
        let lowerQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lowerQuery.isEmpty else { return true }

        let searchIndex = index(for: program)

        if searchIndex.haystack.contains(lowerQuery) {
            return true
        }

        let normalizedState = stateToAbbrev[lowerQuery] ?? lowerQuery
        let cityLower = program.city.lowercased()
        let stateLower = program.state.lowercased()

        if cityLower == lowerQuery || cityLower.contains(lowerQuery) {
            return true
        }

        if stateLower == lowerQuery ||
            normalizedState.uppercased() == program.state.uppercased() ||
            (stateToAbbrev[lowerQuery]?.uppercased() == program.state.uppercased()) {
            return true
        }

        if let accreditationID = program.accreditationID?.lowercased(),
           accreditationID == lowerQuery || accreditationID.contains(lowerQuery) {
            return true
        }

        if matchesAcronym(lowerQuery, searchIndex: searchIndex) {
            return true
        }

        if matchesAlias(lowerQuery, haystack: searchIndex.haystack) {
            return true
        }

        return false
    }

    private static func buildIndex(for program: ResidencyProgramInfo) -> ProgramSearchIndex {
        let haystack = [
            program.hospital,
            program.name,
            program.city,
            program.state,
            program.accreditationID ?? ""
        ]
        .joined(separator: " ")
        .lowercased()

        let combined = "\(program.hospital) \(program.name)"
        return ProgramSearchIndex(
            haystack: haystack,
            acronym: acronym(from: combined),
            hospitalAcronym: acronym(from: program.hospital)
        )
    }

    private static func tokens(from text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "'", with: "")
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { !$0.isEmpty && !stopWords.contains($0) }
    }

    static func acronym(from text: String) -> String {
        tokens(from: text).compactMap(\.first).map { String($0) }.joined()
    }

    private static func matchesAcronym(_ query: String, searchIndex: ProgramSearchIndex) -> Bool {
        guard query.count >= minAcronymQueryLength else { return false }
        guard query.allSatisfy(\.isLetter) else { return false }

        if searchIndex.acronym.hasPrefix(query) || searchIndex.hospitalAcronym.hasPrefix(query) {
            return true
        }

        return false
    }

    private static func matchesAlias(_ query: String, haystack: String) -> Bool {
        guard let phrases = queryAliases[query] else { return false }
        return phrases.contains { haystack.contains($0) }
    }
}
