//
//  ProgramsNeedingReviewView.swift
//  Matchly
//
//  Created on 11/14/25.
//

import SwiftUI

struct ProgramsNeedingReviewView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var programsNeedingReview: [Program] {
        // Same rule as Dashboard "To Score" / "Finish scoring" — incomplete enabled questions.
        let prefs = dataManager.preferences
        return dataManager.programs.filter { $0.needsScoring(preferences: prefs) }
    }
    
    var body: some View {
        Group {
            if programsNeedingReview.isEmpty {
                List {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.arial(size: 60))
                            .foregroundColor(.green)
                        
                        Text("All Programs Scored")
                            .font(.arial(size: 20, weight: .bold))
                        
                        Text("Every program has a complete questionnaire")
                            .font(.arial(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .glassCardStyle(cornerRadius: 20)
                }
            } else {
                // Group programs by specialty (matching ProgramsListView)
                let groupedPrograms = Dictionary(grouping: programsNeedingReview) { $0.specialty }
                let sortedSpecialties = groupedPrograms.keys.sorted()
                
                List {
                    ForEach(sortedSpecialties, id: \.self) { specialty in
                        Section(header: 
                            HStack(spacing: 6) {
                                Image(systemName: "stethoscope")
                                    .font(.arial(size: 12))
                                    .foregroundColor(SpecialtyFormatter.color(for: specialty))
                                Text("\(specialty) (\(SpecialtyFormatter.abbreviation(for: specialty)))")
                                    .font(.arial(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.secondary)
                        ) {
                            ForEach(groupedPrograms[specialty] ?? []) { program in
                                NavigationLink(
                                    destination: ProgramEntryView(program: program)
                                ) {
                                    let completionRatio = program.questionnaireCompletionRatio(preferences: dataManager.preferences)
                                    let completionPercent = Int((completionRatio * 100).rounded())
                                    let tint = completionColor(completionPercent)

                                    HStack(spacing: 12) {
                                        // Progress ring — reads as "% complete", not a score
                                        ZStack {
                                            Circle()
                                                .stroke(tint.opacity(0.18), lineWidth: 3.5)
                                                .frame(width: 44, height: 44)

                                            Circle()
                                                .trim(from: 0, to: CGFloat(completionRatio))
                                                .stroke(tint, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                                                .frame(width: 44, height: 44)
                                                .rotationEffect(.degrees(-90))

                                            Text("\(completionPercent)%")
                                                .font(.arial(size: 11, weight: .bold))
                                                .foregroundColor(tint)
                                                .minimumScaleFactor(0.8)
                                                .lineLimit(1)
                                        }
                                        .accessibilityLabel("\(completionPercent) percent complete")

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(HospitalNameFormatter.format(program.hospital.isEmpty ? (program.name.isEmpty ? "Unnamed Program" : program.name) : program.hospital))
                                                .font(.arial(size: 15, weight: .semibold))
                                                .lineLimit(3)
                                                .fixedSize(horizontal: false, vertical: true)

                                            if !program.specialty.isEmpty {
                                                let specialtyColor = SpecialtyFormatter.color(for: program.specialty)
                                                let specialtyAbbrev = SpecialtyFormatter.abbreviation(for: program.specialty)

                                                HStack(spacing: 3) {
                                                    Image(systemName: "stethoscope")
                                                        .font(.arial(size: 8))
                                                    Text(specialtyAbbrev)
                                                        .font(.arial(size: 10, weight: .semibold))
                                                }
                                                .foregroundColor(specialtyColor)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .glassChipStyle(tint: specialtyColor, interactive: false)
                                            }

                                            HStack(spacing: 8) {
                                                if program.hasDisplayLocation {
                                                    HStack(spacing: 3) {
                                                        Image(systemName: "mappin.circle.fill")
                                                            .font(.arial(size: 9))
                                                        Text(program.displayCityState)
                                                            .font(.arial(size: 11))
                                                    }
                                                    .foregroundColor(.secondary)
                                                }

                                                if let acgmeID = program.accreditationID, !acgmeID.isEmpty {
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

                                            SavedProgramIMGBadge(program: program)

                                            HStack(spacing: 8) {
                                                if program.signalType != .none {
                                                    let isTiered = SignalLimits.isTiered(for: program.specialty)
                                                    let signalText = isTiered
                                                        ? (program.signalType == .gold ? "Gold Signal" : "Silver Signal")
                                                        : "Signal"
                                                    let signalColor = isTiered
                                                        ? (program.signalType == .gold ? Color.yellow : Color(white: 0.6))
                                                        : Color.blue

                                                    HStack(spacing: 3) {
                                                        Image(systemName: program.signalType == .gold ? "star.fill" : "star")
                                                            .font(.arial(size: 8))
                                                        Text(signalText)
                                                            .font(.arial(size: 10, weight: .medium))
                                                    }
                                                    .foregroundColor(signalColor)
                                                }

                                                if program.hasRedFlags() {
                                                    HStack(spacing: 3) {
                                                        Image(systemName: "exclamationmark.triangle.fill")
                                                            .font(.arial(size: 8))
                                                        Text("Red Flag")
                                                            .font(.arial(size: 10, weight: .medium))
                                                    }
                                                    .foregroundColor(.red)
                                                }

                                                ProgramVoiceMemoBadge(program: program)

                                                HStack(spacing: 3) {
                                                    Image(systemName: completionPercent == 0 ? "circle" : "circle.lefthalf.filled")
                                                        .font(.arial(size: 8))
                                                    Text(completionPercent == 0 ? "Not started" : "\(completionPercent)% complete")
                                                        .font(.arial(size: 10, weight: .medium))
                                                }
                                                .foregroundColor(tint)
                                            }
                                        }

                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .appCanvasBackground()
            }
        }
        .appCanvasBackground()
        .navigationTitle("Programs Needing Review")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Progress tint for questionnaire completion (0–100), distinct from score coloring.
    private func completionColor(_ percent: Int) -> Color {
        switch percent {
        case 0:
            return AppColors.accentOrange
        case 1..<40:
            return AppColors.accentOrange
        case 40..<75:
            return AppColors.primaryBlue
        default:
            return AppColors.accentGreen
        }
    }
}

#Preview {
    MatchlyNavigationView {
        ProgramsNeedingReviewView()
            .environmentObject(DataManager.shared)
    }
}

