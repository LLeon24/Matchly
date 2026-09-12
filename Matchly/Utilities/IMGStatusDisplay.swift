//
//  IMGStatusDisplay.swift
//  Matchly
//

import SwiftUI

enum IMGStatusDisplay {
    case verified
    case likely
    case none

    static func forCatalogProgram(_ program: ResidencyProgramInfo) -> IMGStatusDisplay {
        if program.isIMGFriendly == true { return .verified }
        if program.isIMGFriendly == false { return .none }
        if IMGFriendlyHelper.shared.assessIMGFriendliness(program: program) == true {
            return .likely
        }
        return .none
    }

    static func forSavedProgram(_ program: Program) -> IMGStatusDisplay {
        if program.isIMGFriendly == true { return .verified }
        if program.isIMGFriendly == false { return .none }
        if IMGFriendlyHelper.shared.assessIMGFriendlinessForProgram(program) == true {
            return .likely
        }
        return .none
    }

    var label: String {
        switch self {
        case .verified: return "IMG"
        case .likely: return "IMG Likely"
        case .none: return ""
        }
    }

    var color: Color {
        switch self {
        case .verified: return .purple
        case .likely: return .purple.opacity(0.85)
        case .none: return .clear
        }
    }
}
