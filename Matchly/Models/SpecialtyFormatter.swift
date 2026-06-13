//
//  SpecialtyFormatter.swift
//  Matchly
//
//  Created on 11/14/25.
//

import SwiftUI

struct SpecialtyFormatter {
    // Specialty abbreviations
    static let abbreviations: [String: String] = [
        "Internal Medicine": "IM",
        "Family Medicine": "FM",
        "Emergency Medicine": "EM",
        "Pediatrics": "Peds",
        "General Surgery": "GS",
        "OB/GYN": "OB/GYN",
        "Obstetrics and Gynecology": "OB/GYN",
        "Psychiatry": "Psych",
        "Neurology": "Neuro",
        "Anesthesiology": "Anes",
        "Radiology": "Rad",
        "Diagnostic Radiology": "Rad",
        "Radiology-Diagnostic": "Rad",
        "Pathology": "Path",
        "Orthopedics": "Ortho",
        "Orthopaedic Surgery": "Ortho",
        "ENT": "ENT",
        "Otolaryngology": "ENT",
        "Otolaryngology - Head and Neck Surgery": "ENT",
        "Urology": "Uro",
        "PM&R": "PM&R",
        "Physical Medicine and Rehabilitation": "PM&R",
        "Dermatology": "Derm",
        "Neurosurgery": "NS",
        "Neurological Surgery": "NS",
        "Child Neurology": "Child Neuro",
        "Nuclear Medicine": "Nuc Med",
        "Radiation Oncology": "Rad Onc",
        "Plastic Surgery": "Plastics",
        "Ophthalmology": "Ophth",
        "Interventional Radiology - Integrated": "IR",
        "Thoracic Surgery - Integrated": "CT Surg",
        "Vascular Surgery - Integrated": "Vasc Surg",
        "Transitional Year": "TY",
        "Aerospace Medicine": "Aero Med",
        "Occupational and Environmental Medicine": "Occ Med",
        "Public Health and General Preventive Medicine": "PHPM",
        "Osteopathic Neuromusculoskeletal Medicine": "ONMM"
    ]
    
    // Specialty colors - distinct colors for visual differentiation
    static let colors: [String: Color] = [
        "Internal Medicine": .blue,
        "Family Medicine": .green,
        "Emergency Medicine": .red,
        "Pediatrics": .pink,
        "General Surgery": .purple,
        "OB/GYN": .orange,
        "Obstetrics and Gynecology": .orange,
        "Psychiatry": .indigo,
        "Neurology": .teal,
        "Anesthesiology": .cyan,
        "Radiology": .mint,
        "Diagnostic Radiology": .mint,
        "Radiology-Diagnostic": .mint,
        "Pathology": .brown,
        "Orthopedics": .yellow,
        "Orthopaedic Surgery": .yellow,
        "ENT": .purple,
        "Otolaryngology": .purple,
        "Otolaryngology - Head and Neck Surgery": .purple,
        "Urology": .blue,
        "PM&R": .green,
        "Physical Medicine and Rehabilitation": .green,
        "Dermatology": .pink,
        "Neurosurgery": .indigo,
        "Neurological Surgery": .indigo,
        "Child Neurology": .teal,
        "Nuclear Medicine": .cyan,
        "Radiation Oncology": .orange,
        "Plastic Surgery": .pink,
        "Ophthalmology": .cyan,
        "Interventional Radiology - Integrated": .mint,
        "Thoracic Surgery - Integrated": .red,
        "Vascular Surgery - Integrated": .red,
        "Transitional Year": .gray,
        "Aerospace Medicine": .blue,
        "Occupational and Environmental Medicine": .green,
        "Public Health and General Preventive Medicine": .teal,
        "Osteopathic Neuromusculoskeletal Medicine": .brown
    ]
    
    static func abbreviation(for specialty: String) -> String {
        return abbreviations[specialty] ?? specialty
    }
    
    static func color(for specialty: String) -> Color {
        return colors[specialty] ?? .purple
    }
    
    static func displayNameWithAbbreviation(_ specialty: String) -> String {
        let abbrev = abbreviation(for: specialty)
        if abbrev == specialty {
            return specialty
        }
        return "\(specialty) (\(abbrev))"
    }
}

