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
                        .font(.arial(size: 20))
                        .frame(width: 24)
                }
                
                // Program info - compact style matching My Programs
                VStack(alignment: .leading, spacing: 3) {
                    // Hospital name
                    Text(program.formattedHospital)
                        .font(.arial(size: 15, weight: .semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Specialty — full name, wraps on any device width
                    if !program.specialty.isEmpty {
                        let specialtyColor = SpecialtyFormatter.color(for: program.specialty)
                        let specialtyLabel = SpecialtyFormatter.rowSpecialtyLabel(for: program)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top, spacing: 4) {
                                Image(systemName: "stethoscope")
                                    .font(.arial(size: 9))
                                    .padding(.top, 2)
                                Text(specialtyLabel)
                                    .font(.arial(size: 11, weight: .semibold))
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .foregroundColor(specialtyColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(specialtyColor.opacity(0.12))
                            .cornerRadius(6)

                            HStack(spacing: 6) {
                                Text(program.trainingLevel.rawValue)
                                    .font(.arial(size: 9, weight: .semibold))
                                    .foregroundColor(program.trainingLevel == .fellowship ? .purple : .blue)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background((program.trainingLevel == .fellowship ? Color.purple : Color.blue).opacity(0.12))
                                    .cornerRadius(4)

                                if let parentName = SpecialtyFormatter.rowParentResidencyLabel(for: program) {
                                    Text("in \(parentName)")
                                        .font(.arial(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    
                    // Location and Accreditation ID on first line
                    HStack(spacing: 8) {
                        // Location
                        if !program.location.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.arial(size: 9))
                                Text(program.location)
                                    .font(.arial(size: 11))
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        // Accreditation ID - subtle, no background
                        if let acgmeID = program.accreditationID {
                            HStack(spacing: 2) {
                                Image(systemName: "number.circle.fill")
                                    .font(.arial(size: 9))
                                Text("ID:")
                                    .font(.arial(size: 10, weight: .medium))
                                Text(acgmeID)
                                    .font(.arial(size: 11, weight: .medium))
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
                                    .font(.arial(size: 8))
                                Text(program.type)
                                    .font(.arial(size: 10, weight: .medium))
                            }
                            .foregroundColor(programTypeColor(program.type))
                        }
                        
                        // IMG-Friendly - same style as Program Type (text with icon, no badge)
                        if program.isIMGFriendly == true {
                            HStack(spacing: 3) {
                                Image(systemName: "globe.americas.fill")
                                    .font(.arial(size: 8))
                                Text("IMG")
                                    .font(.arial(size: 10, weight: .medium))
                            }
                            .foregroundColor(.purple)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer(minLength: 0)
                
                if !allowMultiSelect {
                    Image(systemName: "chevron.right")
                        .font(.arial(size: 11, weight: .medium))
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

