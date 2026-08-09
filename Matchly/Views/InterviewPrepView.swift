//
//  InterviewPrepView.swift
//  Matchly
//

import SwiftUI

struct InterviewPrepView: View {
    @EnvironmentObject private var dataManager: DataManager
    let program: Program

    @State private var prepState = InterviewPrepState()
    @State private var didLoadPrepState = false

    private var liveProgram: Program {
        dataManager.programs.first { $0.id == program.id } ?? program
    }

    private var availablePrompts: [(id: String, sectionTitle: String, question: String)] {
        liveProgram.questionnaire.allPrepPrompts(preferences: dataManager.preferences)
    }

    private var selectedPrompts: [(id: String, sectionTitle: String, question: String)] {
        availablePrompts.filter { prepState.selectedQuestionIds.contains($0.id) }
    }

    private var priorityPrompts: [(id: String, sectionTitle: String, question: String)] {
        prepState.priorityQuestionIds.compactMap { id in
            availablePrompts.first { $0.id == id }
        }
    }

    private var groupedPrompts: [(sectionTitle: String, prompts: [(id: String, sectionTitle: String, question: String)])] {
        let grouped = Dictionary(grouping: availablePrompts, by: \.sectionTitle)
        return grouped.keys.sorted().map { title in
            (sectionTitle: title, prompts: grouped[title] ?? [])
        }
    }

    private static let checklistItems = [
        "Confirm interview time and location",
        "Review the program website",
        "Plan travel, parking, or your virtual link",
        "Prepare a brief introduction about yourself",
        "Lay out your outfit or test your virtual setup"
    ]

    private static let quickTips = [
        "Know your \"why this program\" in 30 seconds",
        "Research one faculty member or rotation you'd like to learn about",
        "Bring a notebook with your top questions written down",
        "If virtual, join 5 minutes early with camera and mic ready"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                snapshotCard

                if liveProgram.hasRedFlags() {
                    redFlagsReminderCard
                }

                if !availablePrompts.isEmpty {
                    topThreeCard
                    questionsCard
                }

                quickTipsCard

                if !liveProgram.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    notesCard
                }

                checklistCard
                scoreAfterButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .matchlyScrollTabBarClearance()
        .navigationTitle("Interview Prep")
        .navigationBarTitleDisplayMode(.inline)
        .appCanvasBackground()
        .onAppear {
            loadPrepStateIfNeeded()
        }
        .onChange(of: availablePrompts.map(\.id)) { _, _ in
            sanitizePrepState()
        }
    }

    // MARK: - Snapshot

    private var snapshotCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(displayHospitalName)
                .font(.arial(size: 22, weight: .bold))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if !liveProgram.specialty.isEmpty {
                MatchlyProgramSpecialtyBadge(specialty: liveProgram.specialty, useFullName: true)
            }

            MatchlyProgramLocationAndIDRow(program: liveProgram)

            if !liveProgram.type.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: programTypeIcon(liveProgram.type))
                        .font(.arial(size: 11))
                    Text(liveProgram.type)
                        .font(.arial(size: 12, weight: .medium))
                }
                .foregroundColor(programTypeColor(liveProgram.type))
            }

            if let date = liveProgram.interviewDate {
                interviewScheduleRow(for: date)
            }

            HStack(spacing: 8) {
                SavedProgramIMGBadge(program: liveProgram, iconSize: 9, textSize: 11)
                if liveProgram.signalType != .none {
                    signalBadge
                }
            }

            if let emrLabel = emrSummary {
                Label(emrLabel, systemImage: "desktopcomputer")
                    .font(.arial(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCardStyle()
    }

    private var displayHospitalName: String {
        HospitalNameFormatter.format(
            liveProgram.hospital.isEmpty
                ? (liveProgram.name.isEmpty ? "Unnamed Program" : liveProgram.name)
                : liveProgram.hospital
        )
    }

    private func interviewScheduleRow(for date: Date) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.arial(size: 11))
                Text(Self.interviewDateFormatter.string(from: date))
                Text("·")
                Text(Self.interviewTimeFormatter.string(from: date))
            }
            .font(.arial(size: 13, weight: .semibold))
            .foregroundColor(AppColors.accentTeal)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppColors.accentTeal.opacity(0.12))
            .clipShape(Capsule())

            if date > Date() {
                let days = max(Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0, 0)
                Text(days == 0 ? "Today" : days == 1 ? "Tomorrow" : "In \(days) days")
                    .font(.arial(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.pipelineUpcoming)
            }
        }
    }

    @ViewBuilder
    private var signalBadge: some View {
        let isTiered = SignalLimits.isTiered(for: liveProgram.specialty)
        let label = isTiered
            ? (liveProgram.signalType == .gold ? "Gold Signal" : "Silver Signal")
            : "Signal"
        let color: Color = isTiered
            ? (liveProgram.signalType == .gold ? .yellow : Color(white: 0.55))
            : .blue

        HStack(spacing: 3) {
            Image(systemName: liveProgram.signalType == .gold ? "star.fill" : "star")
                .font(.arial(size: 9))
            Text(label)
                .font(.arial(size: 11, weight: .medium))
        }
        .foregroundColor(color)
    }

    private var emrSummary: String? {
        guard let emr = liveProgram.emr, !emr.isEmpty else { return nil }
        return "EMR: \(emr)"
    }

    // MARK: - Top 3

    private var topThreeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            prepSectionHeader(title: "Top 3 Must-Ask", icon: "star.fill", tint: .yellow)

            if priorityPrompts.isEmpty {
                Text("Star up to 3 questions below — these are the ones you most want answered on interview day.")
                    .font(.arial(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(priorityPrompts.enumerated()), id: \.element.id) { index, prompt in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.arial(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Color.yellow.opacity(0.9)))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(Self.shortSectionTitle(prompt.sectionTitle))
                                    .font(.arial(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Text(prompt.question)
                                    .font(.arial(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.yellow.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCardStyle()
    }

    // MARK: - Questions

    private var questionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                prepSectionHeader(title: "Questions to Ask", icon: "text.bubble.fill", tint: AppColors.accentGreen)
                Spacer(minLength: 8)
                Text("\(selectedPrompts.count) selected")
                    .font(.arial(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Text("Tap to include a question. Star your top 3 must-ask items.")
                .font(.arial(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button("Select All") {
                    prepState.selectedQuestionIds = Set(availablePrompts.map(\.id))
                    persistPrepState()
                }
                .font(.arial(size: 12, weight: .semibold))
                .foregroundColor(AppColors.primaryBlue)

                Button("Clear") {
                    prepState.selectedQuestionIds.removeAll()
                    prepState.priorityQuestionIds.removeAll()
                    persistPrepState()
                }
                .font(.arial(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(groupedPrompts, id: \.sectionTitle) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Self.shortSectionTitle(group.sectionTitle))
                            .font(.arial(size: 11, weight: .semibold))
                            .foregroundColor(SpecialtyFormatter.color(for: liveProgram.specialty))
                            .textCase(.uppercase)

                        VStack(spacing: 8) {
                            ForEach(group.prompts, id: \.id) { prompt in
                                questionRow(prompt)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCardStyle()
    }

    private func questionRow(_ prompt: (id: String, sectionTitle: String, question: String)) -> some View {
        let isSelected = prepState.selectedQuestionIds.contains(prompt.id)
        let isPriority = prepState.priorityQuestionIds.contains(prompt.id)
        let priorityIndex = prepState.priorityQuestionIds.firstIndex(of: prompt.id)

        return HStack(alignment: .top, spacing: 10) {
            Button {
                toggleQuestionSelection(prompt.id)
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.arial(size: 20))
                    .foregroundColor(isSelected ? AppColors.accentGreen : .secondary)
            }
            .buttonStyle(.plain)

            Text(prompt.question)
                .font(.arial(size: 14))
                .foregroundColor(isSelected ? .primary : .secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                togglePriority(prompt.id)
            } label: {
                ZStack {
                    Image(systemName: isPriority ? "star.fill" : "star")
                        .font(.arial(size: 16, weight: .semibold))
                        .foregroundColor(isPriority ? .yellow : .secondary.opacity(isSelected ? 0.8 : 0.35))

                    if let priorityIndex {
                        Text("\(priorityIndex + 1)")
                            .font(.arial(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .offset(y: 1)
                    }
                }
                .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(!isSelected && !isPriority)
        }
        .padding(12)
        .background(isPriority ? Color.yellow.opacity(0.08) : Color.primary.opacity(isSelected ? 0.04 : 0.02))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Tips & Notes

    private var quickTipsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            prepSectionHeader(title: "Quick Tips", icon: "lightbulb.fill", tint: AppColors.accentPurple)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Self.quickTips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.arial(size: 12))
                            .foregroundColor(AppColors.accentPurple.opacity(0.8))
                            .padding(.top, 2)
                        Text(tip)
                            .font(.arial(size: 13))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCardStyle()
    }

    private var redFlagsReminderCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "flag.fill")
                .font(.arial(size: 14))
                .foregroundColor(.red)
            VStack(alignment: .leading, spacing: 4) {
                Text("You flagged concerns for this program")
                    .font(.arial(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Review your red flags before the interview so you can ask thoughtful follow-up questions.")
                    .font(.arial(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            prepSectionHeader(title: "Your Notes", icon: "note.text", tint: AppColors.accentPurple)

            Text(liveProgram.notes)
                .font(.arial(size: 14))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCardStyle()
    }

    // MARK: - Checklist

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            prepSectionHeader(title: "Day-Before Checklist", icon: "checklist", tint: AppColors.accentOrange)

            VStack(spacing: 0) {
                ForEach(Self.checklistItems, id: \.self) { item in
                    Button {
                        toggleChecklistItem(item)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: prepState.checkedChecklistItems.contains(item) ? "checkmark.circle.fill" : "circle")
                                .font(.arial(size: 18))
                                .foregroundColor(prepState.checkedChecklistItems.contains(item) ? AppColors.accentGreen : .secondary)

                            Text(item)
                                .font(.arial(size: 14))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    if item != Self.checklistItems.last {
                        Divider()
                    }
                }
            }

            if prepState.checkedChecklistItems.count == Self.checklistItems.count, !Self.checklistItems.isEmpty {
                Label("You're all set — good luck!", systemImage: "hands.clap.fill")
                    .font(.arial(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.accentGreen)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCardStyle()
    }

    // MARK: - Score CTA

    private var scoreAfterButton: some View {
        NavigationLink(destination: ProgramEntryView(program: liveProgram)) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .font(.arial(size: 16, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text(liveProgram.isReviewed ? "View Questionnaire" : "Score After Interview")
                        .font(.arial(size: 15, weight: .semibold))
                    Text(
                        liveProgram.isReviewed
                            ? "Update ratings or notes from your visit"
                            : "Open the questionnaire when you're ready to rate this visit"
                    )
                        .font(.arial(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.arial(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.primary)
            .padding(16)
            .dashboardCardStyle()
        }
        .buttonStyle(.plain)
    }

    // MARK: - State

    private func loadPrepStateIfNeeded() {
        guard !didLoadPrepState else { return }
        didLoadPrepState = true

        var state = dataManager.preferences.interviewPrepByProgram[program.id] ?? InterviewPrepState()
        let validIds = Set(availablePrompts.map(\.id))

        if state.selectedQuestionIds.isEmpty, !validIds.isEmpty {
            state.selectedQuestionIds = validIds
        }

        state.selectedQuestionIds = state.selectedQuestionIds.intersection(validIds)
        state.priorityQuestionIds = state.priorityQuestionIds.filter { validIds.contains($0) }
        if state.priorityQuestionIds.count > 3 {
            state.priorityQuestionIds = Array(state.priorityQuestionIds.prefix(3))
        }

        prepState = state
        persistPrepState()
    }

    private func sanitizePrepState() {
        let validIds = Set(availablePrompts.map(\.id))
        prepState.selectedQuestionIds = prepState.selectedQuestionIds.intersection(validIds)
        prepState.priorityQuestionIds = prepState.priorityQuestionIds.filter { validIds.contains($0) }
        persistPrepState()
    }

    private func toggleQuestionSelection(_ id: String) {
        if prepState.selectedQuestionIds.contains(id) {
            prepState.selectedQuestionIds.remove(id)
            prepState.priorityQuestionIds.removeAll { $0 == id }
        } else {
            prepState.selectedQuestionIds.insert(id)
        }
        persistPrepState()
    }

    private func togglePriority(_ id: String) {
        if prepState.priorityQuestionIds.contains(id) {
            prepState.priorityQuestionIds.removeAll { $0 == id }
        } else if prepState.priorityQuestionIds.count < 3 {
            prepState.selectedQuestionIds.insert(id)
            prepState.priorityQuestionIds.append(id)
        }
        persistPrepState()
    }

    private func toggleChecklistItem(_ item: String) {
        if prepState.checkedChecklistItems.contains(item) {
            prepState.checkedChecklistItems.remove(item)
        } else {
            prepState.checkedChecklistItems.insert(item)
        }
        persistPrepState()
    }

    private func persistPrepState() {
        dataManager.preferences.interviewPrepByProgram[program.id] = prepState
        dataManager.savePreferences()
    }

    // MARK: - Helpers

    private func prepSectionHeader(title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.arial(size: 14, weight: .semibold))
                    .foregroundColor(tint)
            }

            Text(title)
                .font(.arial(size: 16, weight: .semibold))
                .foregroundColor(.primary)
        }
    }

    private static func shortSectionTitle(_ title: String) -> String {
        if let range = title.range(of: " — ") {
            return String(title[range.upperBound...])
        }
        return title
    }

    private static let interviewDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    private static let interviewTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

#Preview {
    MatchlyNavigationView {
        InterviewPrepView(program: DataManager.shared.programs.first ?? Program.sample)
            .environmentObject(DataManager.shared)
    }
}

private extension Program {
    static var sample: Program {
        Program(
            id: "preview",
            specialty: "Family Medicine",
            name: "Sample Program",
            hospital: "Baptist Outreach Services",
            city: "Montgomery",
            state: "AL",
            type: "Community",
            accreditationID: "12345",
            programQuality: ProgramQuality(),
            cultureFit: CultureFit(),
            location: Location(),
            logistics: Logistics(),
            careerAlignment: CareerAlignment(),
            redFlags: RedFlags(),
            questionnaire: Questionnaire(),
            notes: "Ask about rural clinic exposure.",
            interviewDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())
        )
    }
}
