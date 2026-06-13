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
    
    @State private var showNotes: Bool = false
    @FocusState private var isNotesFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Question text
            Text(question)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
                .lineSpacing(2)
            
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
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(programRating == 1 ? (isPositiveYesNo ? .green : .red) : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(programRating == 1 ? (isPositiveYesNo ? Color.green.opacity(0.1) : Color.red.opacity(0.1)) : Color(.systemGray6))
                        .cornerRadius(8)
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
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(programRating == 2 ? (isPositiveYesNo ? .red : .green) : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(programRating == 2 ? (isPositiveYesNo ? Color.red.opacity(0.1) : Color.green.opacity(0.1)) : Color(.systemGray6))
                        .cornerRadius(8)
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
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text(notes.isEmpty ? "Add Notes" : "Notes (\(notes.count) chars)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(notes.isEmpty ? .secondary : .blue)
                                if !notes.isEmpty {
                                    Spacer()
                                    Image(systemName: "text.bubble.fill")
                                        .font(.system(size: 10))
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
                                Button(action: {
                                    isNotesFocused = false
                                }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 20))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    }
                }
            } else {
                // Program Rating for regular questions
                VStack(spacing: 8) {
                    // Program Rating header - cleaner
                    HStack {
                        Text("Rating")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Group {
                            if programRating == 6 {
                                Text("N/A")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                            } else {
                                Text(programRating > 0 ? "\(Int(programRating))" : "—")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(programRating > 0 ? ratingColor(for: Int(programRating)) : .secondary)
                            }
                        }
                        .frame(width: 30)
                    }
                    
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
                                
                                // Determine text color for better legibility
                                let textColor: Color = {
                                    if isSelected {
                                        return .white
                                    } else {
                                        // Use dark text for lighter colors (2-4), light text for darker (1, 5)
                                        switch rating {
                                        case 2, 3, 4:
                                            return Color(white: 0.2)
                                        default:
                                            return color.opacity(0.7)
                                        }
                                    }
                                }()
                                
                                ZStack {
                                    // Background with color and liquid glass effect
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isSelected ? color : color.opacity(0.15))
                                        .shadow(color: isSelected ? color.opacity(0.4) : color.opacity(0.2), radius: isSelected ? 4 : 2, x: 0, y: 1)
                                        .shadow(color: Color.white.opacity(0.25), radius: 2, x: 0, y: -0.5)
                                    
                                    // Glass overlay
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            LinearGradient(
                                                colors: isSelected ? [
                                                    Color.white.opacity(0.35),
                                                    Color.white.opacity(0.15),
                                                    Color.white.opacity(0.05)
                                                ] : [
                                                    Color.white.opacity(0.4),
                                                    Color.white.opacity(0.2),
                                                    Color.clear
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    
                                // Text
                                Text("\(rating)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(textColor)
                                    .shadow(color: isSelected ? Color.black.opacity(0.3) : (rating <= 1 || rating >= 5 ? Color.clear : Color.white.opacity(0.8)), radius: isSelected ? 1 : 0.5, x: 0, y: 0.5)
                            }
                            .frame(width: 50, height: 40) // More square shape
                            .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            LinearGradient(
                                                colors: isSelected ? [
                                                    Color.white.opacity(0.5),
                                                    Color.white.opacity(0.2)
                                                ] : [
                                                    Color.white.opacity(0.4),
                                                    Color.white.opacity(0.2)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 0.8
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // N/A button
                        Button(action: {
                            if programRating == 6 {
                                programRating = 0
                            } else {
                                programRating = 6 // N/A
                            }
                        }) {
                            let isSelected = programRating == 6
                            
                            ZStack {
                                // Background with liquid glass effect
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Color.secondary : Color(.tertiarySystemFill))
                                    .shadow(color: isSelected ? Color.secondary.opacity(0.3) : Color.black.opacity(0.05), radius: isSelected ? 4 : 2, x: 0, y: 1)
                                    .shadow(color: Color.white.opacity(0.2), radius: 2, x: 0, y: -0.5)
                                
                                // Glass overlay when selected
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.35),
                                                    Color.white.opacity(0.15),
                                                    Color.white.opacity(0.05)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                                
                                // Text
                                Text("N/A")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(isSelected ? .white : .secondary)
                                    .shadow(color: isSelected ? Color.black.opacity(0.3) : Color.clear, radius: 1, x: 0, y: 0.5)
                            }
                            .frame(width: 50, height: 40) // More square shape
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        LinearGradient(
                                            colors: isSelected ? [
                                                Color.white.opacity(0.5),
                                                Color.white.opacity(0.2)
                                            ] : [
                                                Color.white.opacity(0.3),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.8
                                    )
                            )
                        }
                        .buttonStyle(.plain)
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
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text(notes.isEmpty ? "Add Notes" : "Notes (\(notes.count) chars)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(notes.isEmpty ? .secondary : .blue)
                            if !notes.isEmpty {
                                Spacer()
                                Image(systemName: "text.bubble.fill")
                                    .font(.system(size: 10))
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
                                .font(.system(size: 13))
                                .focused($isNotesFocused)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            
                            if isNotesFocused {
                                Button(action: {
                                    isNotesFocused = false
                                }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 20))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
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

