//
//  CatalogProgramMapper.swift
//  Matchly
//

import Foundation

enum CatalogProgramMapper {
    static func toSavedProgram(_ info: ResidencyProgramInfo) -> Program {
        let resolved = AddressFormatter.resolved(for: info)
        return Program(
            specialty: SpecialtyFormatter.normalizedUserSpecialty(info.specialty),
            name: info.name,
            hospital: HospitalNameFormatter.format(info.hospital),
            city: resolved.city,
            state: resolved.state,
            address: resolved.street.isEmpty ? nil : resolved.street,
            type: info.type,
            accreditationID: info.accreditationID,
            websiteURL: info.websiteURL,
            contactEmail: info.contactEmail,
            contactPhone: info.contactPhone,
            programCoordinator: info.programCoordinator,
            programDirector: DirectorNameFormatter.displayDirector(
                programDirector: info.programDirector,
                contactEmail: info.contactEmail
            ),
            isIMGFriendly: info.isIMGFriendly
        )
    }

    static func applyCatalogInfo(_ info: ResidencyProgramInfo, to program: inout Program) {
        let mapped = toSavedProgram(info)
        program.specialty = mapped.specialty
        program.name = mapped.name
        program.hospital = mapped.hospital
        program.city = mapped.city
        program.state = mapped.state
        program.address = mapped.address
        program.type = mapped.type
        program.accreditationID = mapped.accreditationID
        program.websiteURL = mapped.websiteURL
        program.contactEmail = mapped.contactEmail
        program.contactPhone = mapped.contactPhone
        program.programCoordinator = mapped.programCoordinator
        program.programDirector = mapped.programDirector
        program.isIMGFriendly = mapped.isIMGFriendly
    }
}
