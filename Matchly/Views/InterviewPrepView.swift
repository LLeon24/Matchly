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
    @State private var showQuestionnairePicker = false
    @State private var newCustomQuestionText = ""
    @State private var isReorderMode = false
    @State private var isSelectMode = false
    @State private var reorderEditMode: EditMode = .inactive
    @State private var selectedForRemoval: Set<String> = []
    @State private var showClearQuestionsConfirmation = false
    @State private var showDeleteSelectedConfirmation = false
    @State private var showSaveDefaultQuestionsConfirmation = false
    @State private var showShareSheet = false
    @State private var pdfURL: URL?
    @State private var showProgramInfo = false

    private struct PrepListItem: Identifiable {
        let id: String
        let sectionTitle: String
        let question: String
        let isCustom: Bool
    }

    private typealias PrepPrompt = (id: String, sectionTitle: String, question: String)

    private var liveProgram: Program {
        dataManager.programs.first { $0.id == program.id } ?? program
    }

    private var availablePrompts: [PrepPrompt] {
        liveProgram.questionnaire.allPrepPrompts(preferences: dataManager.preferences)
    }

    private var listItems: [PrepListItem] {
        prepState.questionListOrder.compactMap { id in
            if let custom = prepState.customQuestions.first(where: { $0.id == id }) {
                return PrepListItem(id: id, sectionTitle: "Custom", question: custom.question, isCustom: true)
            }
            if let prompt = availablePrompts.first(where: { $0.id == id }) {
                return PrepListItem(id: id, sectionTitle: prompt.sectionTitle, question: prompt.question, isCustom: false)
            }
            return nil
        }
    }

    private var orderedListItems: [PrepListItem] {
        let byId = Dictionary(uniqueKeysWithValues: listItems.map { ($0.id, $0) })
        var result: [PrepListItem] = prepState.priorityQuestionIds.compactMap { byId[$0] }
        let prioritySet = Set(prepState.priorityQuestionIds)
        for id in prepState.questionListOrder where !prioritySet.contains(id) {
            if let item = byId[id] {
                result.append(item)
            }
        }
        return result
    }

    private var priorityItems: [PrepListItem] {
        prepState.priorityQuestionIds.compactMap { id in
            listItems.first { $0.id == id }
        }
    }

    private var hasAnyListItems: Bool {
        !listItems.isEmpty
    }

    private var hasSavedDefaultQuestions: Bool {
        !(dataManager.preferences.interviewPrepDefaultQuestions?.isEmpty ?? true)
    }

    private static let maxPriorityCount = 5
    private static let rowActionColumnWidth: CGFloat = 72

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
        VStack(spacing: 0) {
            snapshotCard
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Color(.systemBackground).opacity(0.98))
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)

            ScrollView {
                LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                    if liveProgram.hasRedFlags() {
                        redFlagsReminderCard
                    }

                    Section {
                        questionsCard
                    } header: {
                        if hasAnyListItems {
                            questionsListToolbar
                        }
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
        }
        .matchlyScrollTabBarClearance()
        .navigationTitle("Interview Prep")
        .navigationBarTitleDisplayMode(.inline)
        .matchlyKeyboardDismissOverlay()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    exportPDF()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Export PDF")
            }
        }
        .appCanvasBackground()
        .onAppear {
            loadPrepStateIfNeeded()
        }
        .onChange(of: availablePrompts.map(\.id)) { _, _ in
            sanitizePrepState()
        }
        .sheet(isPresented: $showShareSheet, onDismiss: { pdfURL = nil }) {
            if let pdfURL {
                ShareSheet(activityItems: [pdfURL])
            }
        }
        .sheet(isPresented: $showProgramInfo) {
            programInfoSheet
        }
        .sheet(isPresented: $showQuestionnairePicker) {
            InterviewPrepQuestionnairePickerSheet(
                program: liveProgram,
                availablePrompts: availablePrompts,
                alreadyAddedIds: Set(prepState.questionListOrder),
                onAdd: { ids in
                    for id in ids where !prepState.questionListOrder.contains(id) {
                        prepState.selectedQuestionIds.insert(id)
                        prepState.questionListOrder.append(id)
                    }
                    persistPrepState()
                }
            )
        }
        .alert("Clear all questions?", isPresented: $showClearQuestionsConfirmation) {
            Button("Clear All", role: .destructive) {
                clearAllQuestions()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every question from your list for this program.")
        }
        .alert("Remove selected questions?", isPresented: $showDeleteSelectedConfirmation) {
            Button("Remove", role: .destructive) {
                deleteSelectedQuestions()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \(selectedForRemoval.count) question\(selectedForRemoval.count == 1 ? "" : "s") from your list.")
        }
        .alert("Save as default questions?", isPresented: $showSaveDefaultQuestionsConfirmation) {
            Button("Save") {
                saveAsDefaultQuestions()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your current list will replace any previously saved default questions.")
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

            HStack(alignment: .center, spacing: 8) {
                MatchlyProgramLocationAndIDRow(program: liveProgram)

                if hasProgramInfoDetails {
                    Button {
                        showProgramInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.arial(size: 14))
                            .foregroundColor(AppColors.primaryBlue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Program information")
                }

                Spacer(minLength: 0)
            }

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

    // MARK: - Questions

    private var hasProgramInfoDetails: Bool {
        programInfoAddressText != nil || programDirectorDisplayName != nil
    }

    private var programInfoAddressText: String? {
        let resolved = AddressFormatter.resolved(
            hospital: liveProgram.hospital,
            address: liveProgram.address,
            city: liveProgram.city,
            state: liveProgram.state,
            accreditationID: liveProgram.accreditationID
        )
        let street = resolved.street
        if !street.isEmpty, !resolved.city.isEmpty, !resolved.state.isEmpty {
            return "\(street)\n\(resolved.city), \(resolved.state)"
        }
        if !street.isEmpty {
            return street
        }
        if !resolved.city.isEmpty, !resolved.state.isEmpty {
            return "\(resolved.city), \(resolved.state)"
        }
        return nil
    }

    private var programDirectorDisplayName: String? {
        DirectorNameFormatter.displayDirector(
            programDirector: liveProgram.programDirector,
            contactEmail: liveProgram.contactEmail
        )
    }

    private var programInfoSheet: some View {
        NavigationStack {
            List {
                if let addressText = programInfoAddressText {
                    Section("Address") {
                        Text(addressText)
                            .font(.arial(size: 15))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let directorName = programDirectorDisplayName {
                    Section("Program Director") {
                        Text(directorName)
                            .font(.arial(size: 15))
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Program Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showProgramInfo = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var questionsListToolbar: some View {
        HStack(alignment: .center, spacing: 10) {
            Spacer(minLength: 0)
            questionsListToolbarActions
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .background(Color(.systemBackground).opacity(0.98))
    }

    @ViewBuilder
    private var questionsListToolbarActions: some View {
        if hasAnyListItems {
            if isSelectMode {
                prepListActionChip(title: "Cancel", icon: "xmark", tint: AppColors.primaryBlue) {
                    exitSelectMode()
                }

                prepListActionChip(
                    title: selectedForRemoval.isEmpty ? "Delete" : "Delete (\(selectedForRemoval.count))",
                    icon: "trash",
                    tint: .red,
                    isFilled: !selectedForRemoval.isEmpty
                ) {
                    showDeleteSelectedConfirmation = true
                }
                .disabled(selectedForRemoval.isEmpty)
                .opacity(selectedForRemoval.isEmpty ? 0.55 : 1)
            } else if isReorderMode {
                prepListActionChip(title: "Done", icon: "checkmark", tint: AppColors.primaryBlue, isFilled: true) {
                    exitReorderMode()
                }
            } else {
                prepListActionChip(title: "Edit", icon: "checkmark.circle", tint: AppColors.primaryBlue) {
                    enterSelectMode()
                }

                prepListActionChip(title: "Reorder", icon: "line.3.horizontal", tint: AppColors.accentGreen) {
                    enterReorderMode()
                }
            }
        }
    }

    private func prepListActionChip(
        title: String,
        icon: String,
        tint: Color,
        isFilled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MatchlyActionChipLabel(icon: icon, text: title, tint: tint, isFilled: isFilled)
        }
        .buttonStyle(.plain)
    }

    private var questionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            prepSectionHeader(title: "Questions to Ask", icon: "text.bubble.fill", tint: AppColors.accentGreen)

            addQuestionControls
            yourListSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCardStyle()
    }

    private var addQuestionControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add a Question")
                    .font(.arial(size: 13, weight: .semibold))

                HStack(alignment: .center, spacing: 8) {
                    ClearableTextField("Type your own question…", text: $newCustomQuestionText, axis: .vertical)
                        .lineLimit(1...3)
                        .font(.arial(size: 14))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button("Add") {
                        addCustomQuestion()
                    }
                    .font(.arial(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.primaryBlue)
                    .disabled(newCustomQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .frame(minHeight: 44)
                }
            }

            if !availablePrompts.isEmpty {
                Button {
                    showQuestionnairePicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.arial(size: 15))
                        Text("Browse Questionnaire Questions")
                            .font(.arial(size: 14, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.arial(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(AppColors.accentGreen)
                    .padding(12)
                    .background(AppColors.accentGreen.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var yourListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Your List")
                        .font(.arial(size: 14, weight: .semibold))
                    if !priorityItems.isEmpty {
                        Text("★ \(priorityItems.count)/\(Self.maxPriorityCount) pinned")
                            .font(.arial(size: 11, weight: .semibold))
                            .foregroundColor(.yellow.opacity(0.95))
                    }
                }

                Spacer(minLength: 8)

                if hasAnyListItems, !isSelectMode, !isReorderMode {
                    Button("Clear All") {
                        showClearQuestionsConfirmation = true
                    }
                    .font(.arial(size: 12, weight: .semibold))
                    .foregroundColor(.red)
                }
            }

            if hasAnyListItems, !isSelectMode, !isReorderMode {
                Button("Save as default questions") {
                    showSaveDefaultQuestionsConfirmation = true
                }
                .font(.arial(size: 12, weight: .semibold))
                .foregroundColor(AppColors.primaryBlue)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if hasAnyListItems {
                Text(listHelperText)
                    .font(.arial(size: 11))
                    .foregroundColor(.secondary)
            }

            if orderedListItems.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Questions you type or pick from the questionnaire will show up here.")
                        .font(.arial(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if hasSavedDefaultQuestions {
                        Button("Load default questions") {
                            loadDefaultQuestions()
                        }
                        .font(.arial(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.primaryBlue)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else if isReorderMode {
                List {
                    ForEach(orderedListItems) { item in
                        reorderRow(item)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onMove(perform: moveListItems)
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, $reorderEditMode)
                .frame(height: prepListHeight(for: orderedListItems.count))
            } else if isSelectMode {
                List {
                    ForEach(orderedListItems) { item in
                        selectListRow(item)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    removeFromList(item.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .frame(height: prepListHeight(for: orderedListItems.count))
            } else {
                List {
                    ForEach(orderedListItems) { item in
                        yourListRow(item)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    removeFromList(item.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .frame(height: prepListHeight(for: orderedListItems.count))
            }
        }
    }

    private var listHelperText: String {
        if isSelectMode {
            return "Tap questions to select · Delete removes selected · Swipe left to remove one"
        }
        if isReorderMode {
            return "Drag to reorder · tap Done when finished"
        }
        return "Tap ★ to pin up to \(Self.maxPriorityCount) to the top · tap row when asked · swipe left to delete"
    }

    private func prepListHeight(for count: Int) -> CGFloat {
        max(CGFloat(count) * 72 + 8, 0)
    }

    private func yourListRow(_ item: PrepListItem) -> some View {
        let isAsked = prepState.askedQuestionIds.contains(item.id)
        let isStarred = prepState.priorityQuestionIds.contains(item.id)
        let starRank = prepState.priorityQuestionIds.firstIndex(of: item.id)
        let starsFull = prepState.priorityQuestionIds.count >= Self.maxPriorityCount

        return questionLabel(for: item, emphasized: isStarred, isAsked: isAsked)
            .padding(12)
            .padding(.trailing, Self.rowActionColumnWidth)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isStarred ? Color.yellow.opacity(0.08) : Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .trailing) {
                HStack(spacing: 10) {
                    Button {
                        toggleAsked(item.id)
                    } label: {
                        Image(systemName: isAsked ? "checkmark.circle.fill" : "circle")
                            .font(.arial(size: 22))
                            .foregroundColor(isAsked ? AppColors.accentGreen : .secondary.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isAsked ? "Mark as not asked" : "Mark as asked")

                    Button {
                        togglePriority(item.id)
                    } label: {
                        ZStack {
                            Image(systemName: isStarred ? "star.fill" : "star")
                                .font(.arial(size: 20, weight: .semibold))
                                .foregroundColor(isStarred ? .yellow : .secondary.opacity(0.45))

                            if let starRank {
                                Text("\(starRank + 1)")
                                    .font(.arial(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                                    .offset(y: 1)
                            }
                        }
                        .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .disabled(starsFull && !isStarred)
                    .accessibilityLabel(isStarred ? "Unpin question" : "Pin to top")
                }
                .padding(.trailing, 12)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onTapGesture {
                toggleAsked(item.id)
            }
            .contextMenu {
                Button(role: .destructive) {
                    removeFromList(item.id)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
    }

    private func selectListRow(_ item: PrepListItem) -> some View {
        let isSelected = selectedForRemoval.contains(item.id)
        let isStarred = prepState.priorityQuestionIds.contains(item.id)

        return Button {
            toggleSelectionForRemoval(item.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.arial(size: 22))
                    .foregroundColor(isSelected ? AppColors.primaryBlue : .secondary.opacity(0.45))
                    .frame(width: 24, height: 24)

                questionLabel(for: item, emphasized: isStarred, isAsked: false)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(
                isSelected
                    ? AppColors.primaryBlue.opacity(0.08)
                    : (isStarred ? Color.yellow.opacity(0.08) : Color.primary.opacity(0.04))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func reorderRow(_ item: PrepListItem) -> some View {
        let isStarred = prepState.priorityQuestionIds.contains(item.id)

        return HStack(spacing: 8) {
            if isStarred {
                Image(systemName: "star.fill")
                    .font(.arial(size: 12))
                    .foregroundColor(.yellow)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.isCustom ? "CUSTOM" : Self.shortSectionTitle(item.sectionTitle))
                    .font(.arial(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Text(item.question)
                    .font(.arial(size: 14))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isStarred ? Color.yellow.opacity(0.08) : Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func questionLabel(for item: PrepListItem, emphasized: Bool, isAsked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.isCustom ? "CUSTOM" : Self.shortSectionTitle(item.sectionTitle))
                .font(.arial(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            Text(item.question)
                .font(.arial(size: 14, weight: emphasized ? .medium : .regular))
                .foregroundColor(isAsked ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        NavigationLink(destination: ProgramEntryView(program: liveProgram, scrollToRedFlags: true)) {
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
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.arial(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
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
                        .contentShape(Rectangle())
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
            }
            .foregroundColor(.primary)
            .padding(16)
            .dashboardCardStyle()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - State

    private func loadPrepStateIfNeeded() {
        guard !didLoadPrepState else { return }
        didLoadPrepState = true

        var state = dataManager.preferences.interviewPrepByProgram[program.id] ?? InterviewPrepState()
        let validQuestionnaireIds = Set(availablePrompts.map(\.id))
        let validCustomIds = Set(state.customQuestions.map(\.id))
        let allValidIds = validQuestionnaireIds.union(validCustomIds)

        state.selectedQuestionIds = state.selectedQuestionIds.intersection(validQuestionnaireIds)
        state.customQuestions.removeAll { $0.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        state.priorityQuestionIds = state.priorityQuestionIds.filter { allValidIds.contains($0) }
        state.askedQuestionIds = state.askedQuestionIds.intersection(allValidIds)
        if state.priorityQuestionIds.count > Self.maxPriorityCount {
            state.priorityQuestionIds = Array(state.priorityQuestionIds.prefix(Self.maxPriorityCount))
        }
        state.questionListOrder = state.questionListOrder.filter { allValidIds.contains($0) }
        state.selectedQuestionIds = state.selectedQuestionIds
            .intersection(validQuestionnaireIds)
            .intersection(Set(state.questionListOrder))

        prepState = state
        persistPrepState()
    }

    private func sanitizePrepState() {
        let validQuestionnaireIds = Set(availablePrompts.map(\.id))
        let validCustomIds = Set(prepState.customQuestions.map(\.id))
        let allValidIds = validQuestionnaireIds.union(validCustomIds)

        prepState.selectedQuestionIds = prepState.selectedQuestionIds
            .intersection(validQuestionnaireIds)
            .intersection(Set(prepState.questionListOrder))
        prepState.questionListOrder = prepState.questionListOrder.filter { allValidIds.contains($0) }
        prepState.priorityQuestionIds = prepState.priorityQuestionIds.filter { allValidIds.contains($0) }
        prepState.askedQuestionIds = prepState.askedQuestionIds.intersection(allValidIds)
        if prepState.priorityQuestionIds.count > Self.maxPriorityCount {
            prepState.priorityQuestionIds = Array(prepState.priorityQuestionIds.prefix(Self.maxPriorityCount))
        }
        persistPrepState()
    }

    private func removeFromList(_ id: String) {
        removeFromList(Set([id]))
    }

    private func removeFromList(_ ids: Set<String>) {
        guard !ids.isEmpty else { return }
        for id in ids {
            prepState.selectedQuestionIds.remove(id)
            prepState.customQuestions.removeAll { $0.id == id }
            prepState.questionListOrder.removeAll { $0 == id }
            prepState.priorityQuestionIds.removeAll { $0 == id }
            prepState.askedQuestionIds.remove(id)
        }
        selectedForRemoval.subtract(ids)
        if prepState.questionListOrder.isEmpty {
            exitSelectMode()
            exitReorderMode()
        }
        persistPrepState()
    }

    private func clearAllQuestions() {
        prepState.selectedQuestionIds = []
        prepState.customQuestions = []
        prepState.questionListOrder = []
        prepState.priorityQuestionIds = []
        prepState.askedQuestionIds = []
        exitSelectMode()
        exitReorderMode()
        persistPrepState()
    }

    private func saveAsDefaultQuestions() {
        dataManager.preferences.interviewPrepDefaultQuestions = InterviewPrepDefaultQuestions.from(prepState: prepState)
        dataManager.savePreferences()
    }

    private func loadDefaultQuestions() {
        guard let template = dataManager.preferences.interviewPrepDefaultQuestions,
              !template.isEmpty else { return }
        let validQuestionnaireIds = Set(availablePrompts.map(\.id))
        prepState = template.prepState(matching: validQuestionnaireIds)
        persistPrepState()
    }

    private func deleteSelectedQuestions() {
        removeFromList(selectedForRemoval)
        exitSelectMode()
    }

    private func enterSelectMode() {
        exitReorderMode()
        selectedForRemoval = []
        isSelectMode = true
    }

    private func exitSelectMode() {
        isSelectMode = false
        selectedForRemoval = []
    }

    private func enterReorderMode() {
        exitSelectMode()
        isReorderMode = true
        reorderEditMode = .active
    }

    private func exitReorderMode() {
        isReorderMode = false
        reorderEditMode = .inactive
    }

    private func toggleSelectionForRemoval(_ id: String) {
        if selectedForRemoval.contains(id) {
            selectedForRemoval.remove(id)
        } else {
            selectedForRemoval.insert(id)
        }
    }

    private func addCustomQuestion() {
        let trimmed = newCustomQuestionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let question = InterviewPrepCustomQuestion(question: trimmed)
        prepState.customQuestions.append(question)
        prepState.questionListOrder.append(question.id)
        newCustomQuestionText = ""
        persistPrepState()
    }

    private func moveListItems(from source: IndexSet, to destination: Int) {
        var ids = orderedListItems.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        prepState.priorityQuestionIds = ids.filter { prepState.priorityQuestionIds.contains($0) }
        prepState.questionListOrder = ids
        persistPrepState()
    }

    private func togglePriority(_ id: String) {
        if prepState.priorityQuestionIds.contains(id) {
            prepState.priorityQuestionIds.removeAll { $0 == id }
            persistPrepState()
        } else if prepState.priorityQuestionIds.count < Self.maxPriorityCount,
                  listItems.contains(where: { $0.id == id }) {
            prepState.priorityQuestionIds.append(id)
            persistPrepState()
        }
    }

    private func toggleAsked(_ id: String) {
        if prepState.askedQuestionIds.contains(id) {
            prepState.askedQuestionIds.remove(id)
        } else {
            prepState.askedQuestionIds.insert(id)
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

    private func exportPDF() {
        let location = [liveProgram.city, liveProgram.state]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        let priority = priorityItems.map {
            (
                sectionTitle: $0.sectionTitle,
                question: $0.question,
                asked: prepState.askedQuestionIds.contains($0.id)
            )
        }
        let other = orderedListItems.filter { !prepState.priorityQuestionIds.contains($0.id) }.map {
            (
                sectionTitle: $0.sectionTitle,
                question: $0.question,
                asked: prepState.askedQuestionIds.contains($0.id)
            )
        }
        let checklist = Self.checklistItems.map {
            (title: $0, checked: prepState.checkedChecklistItems.contains($0))
        }

        let config = InterviewPrepPDFExporter.Configuration(
            hospitalName: displayHospitalName,
            specialty: liveProgram.specialty,
            location: location,
            interviewDate: liveProgram.interviewDate,
            priorityQuestions: priority,
            otherSelectedQuestions: other,
            checklistItems: checklist,
            notes: liveProgram.notes.isEmpty ? nil : liveProgram.notes,
            generatedAt: Date()
        )

        if let url = InterviewPrepPDFExporter.generatePDF(configuration: config) {
            pdfURL = url
            showShareSheet = true
        }
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

// MARK: - Questionnaire picker sheet

private struct InterviewPrepQuestionnairePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let program: Program
    let availablePrompts: [(id: String, sectionTitle: String, question: String)]
    let alreadyAddedIds: Set<String>
    let onAdd: (Set<String>) -> Void

    @State private var pendingSelection: Set<String> = []

    private var addablePrompts: [(id: String, sectionTitle: String, question: String)] {
        availablePrompts.filter { !alreadyAddedIds.contains($0.id) }
    }

    private var groupedPrompts: [(sectionTitle: String, prompts: [(id: String, sectionTitle: String, question: String)])] {
        let grouped = Dictionary(grouping: addablePrompts, by: \.sectionTitle)
        return grouped.keys.sorted().compactMap { title in
            let prompts = grouped[title] ?? []
            guard !prompts.isEmpty else { return nil }
            return (sectionTitle: title, prompts: prompts)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(
                        addablePrompts.isEmpty
                            ? "Every questionnaire question is already on your list."
                            : "Pick questions to add to your list."
                    )
                        .font(.arial(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    if groupedPrompts.isEmpty {
                        Text("Remove questions from Your List if you want to browse and re-add them here.")
                            .font(.arial(size: 13))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .padding(.horizontal, 16)
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(groupedPrompts, id: \.sectionTitle) { group in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(shortSectionTitle(group.sectionTitle))
                                        .font(.arial(size: 11, weight: .semibold))
                                        .foregroundColor(SpecialtyFormatter.color(for: program.specialty))
                                        .textCase(.uppercase)
                                        .padding(.horizontal, 16)

                                    VStack(spacing: 8) {
                                        ForEach(group.prompts, id: \.id) { prompt in
                                            pickerRow(prompt)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .appCanvasBackground()
            .navigationTitle("Questionnaire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onAdd(pendingSelection)
                        dismiss()
                    }
                    .font(.arial(size: 16, weight: .semibold))
                    .disabled(pendingSelection.isEmpty)
                }
            }
        }
    }

    private func pickerRow(_ prompt: (id: String, sectionTitle: String, question: String)) -> some View {
        let isSelected = pendingSelection.contains(prompt.id)

        return Button {
            if isSelected {
                pendingSelection.remove(prompt.id)
            } else {
                pendingSelection.insert(prompt.id)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.arial(size: 22))
                    .foregroundColor(isSelected ? AppColors.accentGreen : Color.primary.opacity(0.35))

                Text(prompt.question)
                    .font(.arial(size: 14))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Color.primary.opacity(isSelected ? 0.04 : 0.02))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func shortSectionTitle(_ title: String) -> String {
        if let range = title.range(of: " — ") {
            return String(title[range.upperBound...])
        }
        return title
    }
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
