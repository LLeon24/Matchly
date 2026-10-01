//
//  CoupleProgramSnapshot.swift
//  Matchly
//
//  Minimal program payload shared between linked partners via CloudKit.
//

import Foundation

struct CoupleProgramSnapshot: Codable, Identifiable, Hashable {
    let id: String
    var specialty: String
    var name: String
    var hospital: String
    var city: String
    var state: String
    var address: String?
    var type: String
    var accreditationID: String?
    var finalScore: Double
    var emr: String?
    var rankPosition: Int

    init(from program: Program, rankPosition: Int) {
        id = program.id
        specialty = program.specialty
        name = program.name
        hospital = program.hospital
        city = program.city
        state = program.state
        address = program.address
        type = program.type
        accreditationID = program.accreditationID
        finalScore = program.finalScore
        emr = program.emr
        self.rankPosition = rankPosition
    }

    func asProgram() -> Program {
        Program(
            id: id,
            specialty: specialty,
            name: name,
            hospital: hospital,
            city: city,
            state: state,
            address: address,
            type: type,
            accreditationID: accreditationID,
            emr: emr,
            finalScore: finalScore
        )
    }

    var displayName: String {
        hospital.isEmpty ? name : hospital
    }
}

extension Program {
    static func rankedSnapshots(from programs: [Program]) -> [CoupleProgramSnapshot] {
        programs
            .sorted { $0.finalScore > $1.finalScore }
            .enumerated()
            .map { CoupleProgramSnapshot(from: $0.element, rankPosition: $0.offset + 1) }
    }
}
