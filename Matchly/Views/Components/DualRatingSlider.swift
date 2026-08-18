//
//  DualRatingSlider.swift
//  Matchly
//
//  Created on 11/14/25.
//

import SwiftUI

struct DualRatingSlider: View {
    let question: String
    @Binding var programRating: Double
    @Binding var notes: String
    var isYesNo: Bool = false // For Section F red flags
    var isPositiveYesNo: Bool = false // For questions where "Yes" is positive (e.g., "could see yourself living in city")
    var showLabels: Bool = false // Show "Poor" and "Excellent" labels on first question
    var isUnanswered: Bool = false
    
    @State private var showNotes: Bool = false
    @FocusState private var isNotesFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Text(question)
                    .font(.arial(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineSpacing(1)

                if isUnanswered {
                    Text("Needs answer")
                        .font(.arial(size: 10, weight: .semibold))
                        .foregroundStyle(AppColors.pipelineNeedDate)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(AppColors.pipelineNeedDate.opacity(0.14))
                        )
                        .fixedSize()
                }
            }
            if isYesNo {
                // Yes/No toggle for red flags (or positive questions)
                HStack(spacing: 16) {
                    Button(action: {
                        if programRating == 1 {
                            programRating = 0
                        } else {
                            programRating = 1 // Yes
                        }
                    }) {
                        HStack {
                            Image(systemName: programRating == 1 ? "checkmark.circle.fill" : "circle")
                            Text("Yes")
                                .font(.arial(size: 14, weight: .medium))
                        }
                        .foregroundColor(programRating == 1 ? (isPositiveYesNo ? .green : .red) : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .glassEffect(
                            programRating == 1
                                ? .regular.tint((isPositiveYesNo ? Color.green : Color.red).opacity(0.18)).interactive()
                                : .regular.interactive(),
                            in: .rect(cornerRadius: 8)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        if programRating == 2 {
                            programRating = 0
                        } else {
                            programRating = 2 // No
                        }
                    }) {
                        HStack {
                            Image(systemName: programRating == 2 ? "checkmark.circle.fill" : "circle")
                            Text("No")
                                .font(.arial(size: 14, weight: .medium))
                        }
                        .foregroundColor(programRating == 2 ? (isPositiveYesNo ? .red : .green) : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .glassEffect(
                            programRating == 2
                                ? .regular.tint((isPositiveYesNo ? Color.red : Color.green).opacity(0.18)).interactive()
                                : .regular.interactive(),
                            in: .rect(cornerRadius: 8)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                
                // Notes field for yes/no questions - collapsible
                if programRating > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showNotes.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: showNotes ? "chevron.down" : "chevron.right")
                                    .font(.arial(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text(notes.isEmpty ? "Add Notes" : "Notes")
                                    .font(.arial(size: 12, weight: .medium))
                                    .foregroundColor(notes.isEmpty ? .secondary : .blue)
                                if !notes.isEmpty {
                                    Spacer()
                                    Image(systemName: "text.bubble.fill")
                                        .font(.arial(size: 10))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        
                    if showNotes {
                        HStack(alignment: .top, spacing: 8) {
                            TextField("If yes, describe...", text: $notes, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                                .focused($isNotesFocused)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            
                            if isNotesFocused {
                                VStack {
                                    Button(action: {
                                        isNotesFocused = false
                                    }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.arial(size: 20))
                                    }
                                    .buttonStyle(.plain)
                                    Spacer()
                                }
                                .frame(height: 44) // Match text field height for alignment
                            }
                        }
                    }
                    }
                }
            } else {
                // Program Rating for regular questions - properly aligned
                VStack(alignment: .leading, spacing: 3) {
                    // Rating buttons row - full width, evenly spaced
                    HStack(spacing: 6) {
                        ForEach(1...5, id: \.self) { rating in
                            Button(action: {
                                if programRating == Double(rating) {
                                    programRating = 0
                                } else {
                                    programRating = Double(rating)
                                }
                            }) {
                                let isSelected = programRating >= Double(rating) && programRating > 0 && programRating < 6
                                let color = ratingColor(for: rating)
                                
                                let textColor: Color = {
                                    if isSelected {
                                        return .white
                                    } else {
                                        switch rating {
                                        case 2, 3, 4:
                                            return Color(white: 0.2)
                                        default:
                                            return color.opacity(0.7)
                                        }
                                    }
                                }()
                                
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isSelected ? color : color.opacity(0.15))
                                        .shadow(color: isSelected ? color.opacity(0.3) : color.opacity(0.15), radius: isSelected ? 3 : 1, x: 0, y: 1)
                                    
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            LinearGradient(
                                                colors: isSelected ? [
                                                    Color.white.opacity(0.3),
                                                    Color.white.opacity(0.1)
                                                ] : [
                                                    Color.white.opacity(0.3),
                                                    Color.white.opacity(0.1),
                                                    Color.clear
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    
                                    Text("\(rating)")
                                        .font(.arial(size: 11, weight: .semibold))
                                        .foregroundColor(textColor)
                                }
                                .frame(height: 32)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(
                                            LinearGradient(
                                                colors: isSelected ? [
                                                    Color.white.opacity(0.4),
                                                    Color.white.opacity(0.15)
                                                ] : [
                                                    Color.white.opacity(0.3),
                                                    Color.white.opacity(0.1)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 0.5
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        }
                        
                        // N/A button - same width as others
                        Button(action: {
                            if programRating == 6 {
                                programRating = 0
                            } else {
                                programRating = 6
                            }
                        }) {
                            let isSelected = programRating == 6
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isSelected ? Color.secondary : Color(.tertiarySystemFill))
                                    .shadow(color: isSelected ? Color.secondary.opacity(0.25) : Color.black.opacity(0.05), radius: isSelected ? 3 : 1, x: 0, y: 1)
                                
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.3),
                                                    Color.white.opacity(0.1)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                                
                                Text("N/A")
                                    .font(.arial(size: 10, weight: .semibold))
                                    .foregroundColor(isSelected ? .white : .secondary)
                            }
                            .frame(height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(
                                        LinearGradient(
                                            colors: isSelected ? [
                                                Color.white.opacity(0.4),
                                                Color.white.opacity(0.15)
                                            ] : [
                                                Color.white.opacity(0.3),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.5
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Labels row - only shown on first question, properly aligned
                    if showLabels {
                        HStack(spacing: 6) {
                            // Button 1 label - centered
                            Text("Poor")
                                .font(.arial(size: 8, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                            
                            // Empty spaces for buttons 2, 3, 4
                            ForEach(0..<3) { _ in
                                Color.clear
                                    .frame(maxWidth: .infinity)
                            }
                            
                            // Button 5 label - centered
                            Text("Excellent")
                                .font(.arial(size: 8, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                            
                            // Empty space for N/A button
                            Color.clear
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                
                // Notes field - collapsible
                VStack(alignment: .leading, spacing: 6) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showNotes.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: showNotes ? "chevron.down" : "chevron.right")
                                .font(.arial(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text(notes.isEmpty ? "Add Notes" : "Notes (\(notes.count) chars)")
                                .font(.arial(size: 12, weight: .medium))
                                .foregroundColor(notes.isEmpty ? .secondary : .blue)
                            if !notes.isEmpty {
                                Spacer()
                                Image(systemName: "text.bubble.fill")
                                    .font(.arial(size: 10))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    if showNotes {
                        HStack(alignment: .top, spacing: 8) {
                            TextField("Notes...", text: $notes, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2...4)
                                .font(.arial(size: 13))
                                .focused($isNotesFocused)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            
                            if isNotesFocused {
                                VStack {
                                    Button(action: {
                                        isNotesFocused = false
                                    }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.arial(size: 20))
                                    }
                                    .buttonStyle(.plain)
                                    Spacer()
                                }
                                .frame(height: 44) // Match text field height for alignment
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 0)
        .glassPanelStyle(cornerRadius: 12)
        .overlay {
            if isUnanswered {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.pipelineNeedDate.opacity(0.5), lineWidth: 1.5)
            }
        }
        .onAppear {
            // Auto-expand notes if they already have content
            if !notes.isEmpty {
                showNotes = true
            }
        }
        .onChange(of: notes) { oldValue, newValue in
            // Auto-expand when user starts typing
            if !newValue.isEmpty && !showNotes {
                showNotes = true
            }
        }
    }
    
    // Color coding: 1=red, 2=orange-red, 3=yellow, 4=yellow-green, 5=green
    private func ratingColor(for rating: Int) -> Color {
        switch rating {
        case 1:
            return Color(red: 0.9, green: 0.2, blue: 0.2) // Red
        case 2:
            return Color(red: 1.0, green: 0.55, blue: 0.0) // Orange-red
        case 3:
            return Color(red: 1.0, green: 0.8, blue: 0.0) // Yellow
        case 4:
            return Color(red: 0.5, green: 0.85, blue: 0.3) // Yellow-green
        case 5:
            return Color(red: 0.2, green: 0.7, blue: 0.3) // Green
        default:
            return .gray
        }
    }
}

#Preview {
    DualRatingSlider(
        question: "Overall \"fit\" / gut feeling from interview day",
        programRating: .constant(5),
        notes: .constant("Great vibes!")
    )
    .padding()
}

