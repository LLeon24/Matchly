//
//  ProgramSearchRowView.swift
//  Matchly
//
//  Created on 11/14/25.
//

import SwiftUI

struct ProgramSearchRowView: View {
    let program: ResidencyProgramInfo
    let isSelected: Bool
    let allowMultiSelect: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator for multi-select
                if allowMultiSelect {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray.opacity(0.5))
                        .font(.system(size: 20))
                        .frame(width: 24)
                }
                
                // Program info - compact style matching My Programs
                VStack(alignment: .leading, spacing: 3) {
                    // Hospital name
                    Text(program.formattedHospital)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(2)
                    
                    // Specialty badge (only badge-style element)
                    if !program.specialty.isEmpty {
                        let specialtyColor = SpecialtyFormatter.color(for: program.specialty)
                        let specialtyAbbrev = SpecialtyFormatter.abbreviation(for: program.specialty)
                        
                        HStack(spacing: 3) {
                            Image(systemName: "stethoscope")
                                .font(.system(size: 8))
                            Text(specialtyAbbrev)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(specialtyColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(specialtyColor.opacity(0.15))
                        .cornerRadius(4)
                    }
                    
                    // Location and Accreditation ID on first line
                    HStack(spacing: 8) {
                        // Location
                        HStack(spacing: 3) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 9))
                            Text(program.location)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.secondary)
                        
                        // Accreditation ID - subtle, no background
                        if let acgmeID = program.accreditationID {
                            HStack(spacing: 2) {
                                Image(systemName: "number.circle.fill")
                                    .font(.system(size: 9))
                                Text("ID:")
                                    .font(.system(size: 10, weight: .medium))
                                Text(acgmeID)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    // Program Type and IMG on second line
                    HStack(spacing: 8) {
                        // Program Type - full text, not abbreviated (matching My Programs)
                        if !program.type.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: programTypeIcon(program.type))
                                    .font(.system(size: 8))
                                Text(program.type)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(programTypeColor(program.type))
                        }
                        
                        // IMG-Friendly - same style as Program Type (text with icon, no badge)
                        if program.isIMGFriendly == true {
                            HStack(spacing: 3) {
                                Image(systemName: "globe.americas.fill")
                                    .font(.system(size: 8))
                                Text("IMG")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.purple)
                        }
                    }
                }
                
                Spacer()
                
                if !allowMultiSelect {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.4))
                        .frame(width: 16)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func programTypeColor(_ type: String) -> Color {
        switch type {
        case "Academic":
            return .blue
        case "Community":
            return .green
        case "Hybrid":
            return .orange
        default:
            return .gray
        }
    }
    
    private func programTypeIcon(_ type: String) -> String {
        switch type {
        case "Academic":
            return "graduationcap.fill"
        case "Community":
            return "house.fill"
        case "Hybrid":
            return "square.stack.3d.up.fill"
        default:
            return "building.2.fill"
        }
    }
    
    private func programTypeAbbreviation(_ type: String) -> String {
        switch type {
        case "Academic":
            return "Acad" // Keep as is, but ensure badge has enough width
        case "Community":
            return "Comm" // Keep as is
        case "Hybrid":
            return "Hybrid"
        default:
            // For any other type, try to abbreviate if too long
            return type.count > 6 ? String(type.prefix(6)) : type
        }
    }
}

