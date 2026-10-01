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
    var isAlreadyInList: Bool = false
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
                    
                    // Specialty + training level — specialty wraps; level/parent on next line
                    if !program.specialty.isEmpty {
                        let specialtyColor = SpecialtyFormatter.color(for: program.specialty)
                        let specialtyLabel = SpecialtyFormatter.rowSpecialtyLabel(for: program)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top, spacing: 3) {
                                Image(systemName: "stethoscope")
                                    .font(.arial(size: 8))
                                    .padding(.top, 2)
                                Text(specialtyLabel)
                                    .font(.arial(size: 10, weight: .semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }
                            .foregroundColor(specialtyColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(specialtyColor.opacity(0.15))
                            .cornerRadius(4)
                            .accessibilityLabel(specialtyLabel)

                            HStack(alignment: .center, spacing: 6) {
                                Text(program.trainingLevel.rawValue)
                                    .font(.arial(size: 9, weight: .semibold))
                                    .foregroundColor(program.trainingLevel == .fellowship ? .purple : .blue)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background((program.trainingLevel == .fellowship ? Color.purple : Color.blue).opacity(0.12))
                                    .cornerRadius(4)

                                if let parentName = SpecialtyFormatter.rowParentResidencyLabel(for: program) {
                                    Text("in \(DisplayNameFormatter.titleCaseWords(parentName))")
                                        .font(.arial(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }
                    }
                    
                    // Location and Accreditation ID on first line
                    HStack(spacing: 8) {
                        if isAlreadyInList {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.arial(size: 9))
                                Text("Added")
                                    .font(.arial(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.green)
                        }

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
                    
                    // IMG status (verified vs heuristic)
                    HStack(spacing: 8) {
                        let imgStatus = IMGStatusDisplay.forCatalogProgram(program)
                        if imgStatus != .none {
                            HStack(spacing: 3) {
                                Image(systemName: "globe.americas.fill")
                                    .font(.arial(size: 8))
                                Text(imgStatus.label)
                                    .font(.arial(size: 10, weight: .medium))
                            }
                            .foregroundColor(imgStatus.color)
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
}

