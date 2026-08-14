//
//  DashboardView.swift
//  Matchly
//
//  Created on 11/14/25.
//

import SwiftUI
import Charts
import UIKit
import Combine

private enum HeroStatDestination: Hashable {
    case needDates
    case needReview
}

struct DashboardView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.matchlyLayout) private var screenLayout
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showAddProgram = false
    @State private var showCustomization = false
    @State private var showProfileEdit = false
    @State private var heroStatDestination: HeroStatDestination?
    @Binding var selectedTab: Int
    
    init(selectedTab: Binding<Int> = .constant(0)) {
        _selectedTab = selectedTab
    }
    
    private var layout: DashboardLayout {
        dataManager.preferences.dashboardLayout
    }

    private var isCoupleLinked: Bool {
        FeatureFlags.couplesMatchEnabled && dataManager.preferences.couple?.isLinked == true
    }

    private var dashboardPreferences: DashboardPreferences {
        dataManager.preferences.dashboardPreferences
    }

    /// Changes when layout or header prefs change — forces dashboard to refresh.
    private var dashboardCustomizationToken: String {
        let layout = dataManager.preferences.dashboardLayout
        let prefs = dataManager.preferences.dashboardPreferences
        let disabled = layout.disabledSections.sorted().joined(separator: ",")
        let order = layout.sectionOrder.joined(separator: ",")
        return "\(order)|\(disabled)|\(prefs.greetingStyle.rawValue)|\(prefs.headerSubtitleMode.rawValue)"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
                .id(dashboardCustomizationToken)

            if dataManager.programs.isEmpty {
                ScrollView {
                    emptyStateSection
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, screenLayout.pageBottomInset)
                }
                .matchlyScrollTabBarClearance()
            } else {
                dashboardPage
                    .id("dashboard-\(dashboardCustomizationToken)")
            }
        }
        .matchlyRootContentFrame()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .background(
            // Warm, bright canvas (cream in light / near-black in dark) so white
            // cards pop — the Monarch / Apple Card "premium dashboard" feel.
            AppColors.dashboardCanvas
                .ignoresSafeArea()
        )
        .sheet(isPresented: $showCustomization) {
            DashboardCustomizationView()
                .environmentObject(dataManager)
        }
        .sheet(isPresented: $showProfileEdit) {
            MatchlyNavigationView {
                ProfileEditView()
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == MainTabLayout.dashboardIndex {
                NotificationCenter.default.post(name: NSNotification.Name("ScrollToTop"), object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScrollToTop"))) { _ in
            // Dashboard is a single scroll view — PopToRoot handles navigation stack reset.
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PopToRoot"))) { _ in
            // Pop to root when Dashboard tab is tapped — dismisses any pushed destinations.
            heroStatDestination = nil
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    findAndPopNavigationControllers(in: rootViewController)
                }
            }
        }
        .navigationDestination(item: $heroStatDestination) { destination in
            switch destination {
            case .needDates:
                SetInterviewDatesView()
            case .needReview:
                ProgramsNeedingReviewView()
            }
        }
        .sheet(isPresented: $showAddProgram) {
            MatchlyNavigationView {
                ProgramSearchView(
                    onSelect: { _ in },
                    allowMultiSelect: true
                )
            }
            .matchlyExpandedSheet()
        }
    }

    // MARK: - Persistent Header

    /// Compact command bar that stays pinned above the swipeable pages:
    /// profile photo (opens profile editor), greeting, and the customize button.
    private var headerBar: some View {
        HStack(alignment: .top, spacing: screenLayout == .compactVertical ? 10 : 14) {
            Button(action: { showProfileEdit = true }) {
                headerAvatar
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit profile")
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: screenLayout == .compactVertical ? 2 : 4) {
                MatchlyDashboardGreeting(
                    text: getGreeting(),
                    size: screenLayout.headerGreetingFont
                )

                MatchlyFunctionalSubtitle(
                    text: headerSubtitle,
                    size: screenLayout.headerSubtitleFont
                )
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            Button(action: { showCustomization = true }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.arial(size: screenLayout == .compactVertical ? 16 : 18, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: screenLayout.headerCustomizeButtonSize, height: screenLayout.headerCustomizeButtonSize)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.clear.interactive(), in: .circle)
            .accessibilityLabel("Customize dashboard")
            .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.top, screenLayout == .compactVertical ? 8 : 10)
        .padding(.bottom, screenLayout.headerVerticalPadding + 4)
    }

    /// Profile photo if set, otherwise the user's initials in a clean tinted
    /// circle, with a single SF Symbol as a last resort when there's no name.
    @ViewBuilder
    private var headerAvatar: some View {
        let size = screenLayout.headerAvatarSize

        if let photoData = dataManager.preferences.profile.photoData,
           let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else if let initials = profileInitials {
            ZStack {
                Circle()
                    .fill(AppColors.primaryGradient)
                    .frame(width: size, height: size)
                Text(initials)
                    .font(.arial(size: size * 0.4, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
        } else {
            ZStack {
                Circle()
                    .fill(AppColors.primaryGradient)
                    .frame(width: size, height: size)
                Image(systemName: "person.fill")
                    .font(.arial(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
        }
    }

    /// Up to two uppercased initials derived from the profile name.
    private var profileInitials: String? {
        let first = dataManager.preferences.profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = dataManager.preferences.profile.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !first.isEmpty || !last.isEmpty else { return nil }

        let firstInitial = first.first.map(String.init) ?? ""
        let lastInitial = last.first.map(String.init) ?? ""
        let initials = (firstInitial + lastInitial).uppercased()
        return initials.isEmpty ? nil : initials
    }

    /// Clean, contextual subtitle under the greeting — date, motivational line, or specialty count.
    private var headerSubtitle: String {
        switch dashboardPreferences.headerSubtitleMode {
        case .motivational:
            return getMotivationalMessage()
        case .specialtyCount:
            let count = dataManager.preferences.specialties.count
            guard count > 0 else {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMMM d"
                return formatter.string(from: Date())
            }
            return "Tracking \(count) specialt\(count == 1 ? "y" : "ies")"
        case .date:
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMMM d"
            return formatter.string(from: Date())
        }
    }

    // MARK: - Dashboard Page

    private var dashboardPage: some View {
        ScrollView {
            VStack(spacing: screenLayout.dashboardSectionSpacing) {
                ForEach(dashboardSectionIDs, id: \.self) { sectionId in
                    dashboardSectionView(for: sectionId)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .padding(.bottom, screenLayout.pageBottomInset)
        }
        .matchlyScrollTabBarClearance()
        .refreshable {
            dataManager.recalculateAllScores()
            dataManager.objectWillChange.send()
        }
    }

    private var dashboardSectionIDs: [String] {
        layout.orderedSectionIDs(in: DashboardLayout.dashboardSectionIDs)
            .filter { shouldShowSection($0) }
    }

    @ViewBuilder
    private func dashboardSectionView(for sectionId: String) -> some View {
        switch sectionId {
        case "overviewHero":
            DashboardSnapshotHero(
                progress: overviewHeroProgress,
                progressCaption: overviewHeroProgressCaption,
                bigNumber: overviewHeroBigNumber,
                unit: overviewHeroUnit,
                title: "Your Interview Season",
                nextInterviewProgram: upcomingInterviews.first,
                ringSegments: overviewHeroRingSegments,
                stats: overviewHeroStats,
                accentTint: overviewHeroAccentTint,
                onStatTap: handleHeroStatTap
            )
            .dashboardCardStyle()
        case "needsAttention":
            needsAttentionCard
        case "analytics":
            analyticsSection
        case "quickActions":
            quickActionsSection
        case "programsCompare":
            programsCompareCard
        default:
            EmptyView()
        }
    }

    private var overviewFunnelCard: some View {
        VStack(alignment: .leading, spacing: screenLayout == .compactVertical ? 10 : 14) {
            DashboardSectionHeader(
                title: "Interview Pipeline",
                icon: "line.3.horizontal.decrease",
                tint: AppColors.primaryBlue
            )
            ApplicationFunnelChart(stages: funnelStages)
        }
        .dashboardCardStyle()
    }

    private var programsScoreDistributionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            DashboardSectionHeader(
                title: "Score Distribution",
                icon: "chart.bar.fill",
                tint: AppColors.accentOrange
            )
            ScoreDistributionChart(buckets: scoreBuckets, chartHeight: 120)
        }
        .dashboardCardStyle()
    }

    private var programsCompareCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            DashboardSectionHeader(
                title: "Compare Programs",
                icon: "square.grid.2x2",
                tint: AppColors.primaryBlue
            )

            NavigationLink(destination: ProgramComparisonView()) {
                HStack {
                    Text("Side-by-side scores and details for 2–4 programs")
                        .font(.arial(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.primaryBlue)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.arial(size: 12))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .dashboardCardStyle()
    }

    // MARK: - Overview: Needs Attention

    /// Hero center: total programs tracked for the season.
    private var overviewHeroBigNumber: String {
        "\(dataManager.programs.count)"
    }

    private var overviewHeroUnit: String {
        dataManager.programs.count == 1 ? "program" : "programs"
    }

    /// Ring: interview completion when dates exist; otherwise rank-list readiness.
    private var overviewHeroProgress: Double {
        let total = dataManager.programs.count
        guard total > 0 else { return 0 }

        if interviewCount > 0 {
            return min(max(Double(completedInterviewsCount) / Double(interviewCount), 0), 1)
        }

        let ranked = dataManager.programs.filter { $0.finalScore > 0 }.count
        return min(max(Double(ranked) / Double(total), 0), 1)
    }

    private var overviewHeroProgressCaption: String {
        let total = dataManager.programs.count
        if total == 0 {
            return "No invites logged yet"
        }

        if interviewCount > 0 {
            return "\(completedInterviewsCount) of \(interviewCount) interviews completed"
        }

        if programsNeedingInterviewDateCount > 0 {
            return "\(programsNeedingInterviewDateCount) of \(total) invite\(total == 1 ? "" : "s") need a date"
        }

        let ranked = dataManager.programs.filter { $0.finalScore > 0 }.count
        return "\(ranked) of \(total) scored for your rank list"
    }

    /// Overview section identity — orange, matching the Overview tab.
    private var overviewHeroAccentTint: Color {
        AppColors.accentOrange
    }

    private var overviewHeroStats: [DashboardSnapshotStat] {
        let programCount = dataManager.programs.count
        guard programCount > 0 else { return [] }

        let counts = pipelineStageCounts
        return InterviewSeasonStage.allCases.map { stage in
            let count = counts[stage] ?? 0
            return DashboardSnapshotStat(
                id: stage.rawValue,
                value: "\(count)",
                label: stage.label,
                tint: stage == .toReview && count == 0 ? .secondary : stage.color
            )
        }
    }

    private var pipelineStageCounts: [InterviewSeasonStage: Int] {
        InterviewSeasonStage.counts(for: dataManager.programs, preferences: dataManager.preferences)
    }

    private func handleHeroStatTap(_ stage: InterviewSeasonStage) {
        switch stage {
        case .needDate:
            heroStatDestination = .needDates
        case .upcoming:
            selectedTab = MainTabLayout.interviewsIndex
        case .scored:
            selectedTab = MainTabLayout.rankListIndex(isCoupleLinked: isCoupleLinked)
        case .toReview:
            heroStatDestination = .needReview
        }
    }

    /// One arc per pipeline stage; fractions sum to 100% of tracked programs.
    private var overviewHeroRingSegments: [DashboardSnapshotRingSegment] {
        let total = dataManager.programs.count
        guard total > 0 else { return [] }

        let counts = pipelineStageCounts
        return InterviewSeasonStage.allCases.compactMap { stage in
            let count = counts[stage] ?? 0
            guard count > 0 else { return nil }
            return DashboardSnapshotRingSegment(
                id: stage.rawValue,
                fraction: Double(count) / Double(total),
                color: stage.color
            )
        }
    }

    private var programsNeedingInterviewDateCount: Int {
        dataManager.programs.filter { $0.interviewDate == nil }.count
    }

    /// Invites with a past interview date but an incomplete questionnaire.
    private var postInterviewNeedingScoreCount: Int {
        let now = Date()
        let prefs = dataManager.preferences
        return dataManager.programs.filter { program in
            guard let date = program.interviewDate, date < now else { return false }
            return program.needsScoring(preferences: prefs)
        }.count
    }

    /// Invites whose questionnaire isn't fully scored yet.
    private var programsNeedingScoringCount: Int {
        let prefs = dataManager.preferences
        return dataManager.programs.filter { $0.needsScoring(preferences: prefs) }.count
    }

    /// Ring fill: share of enabled questionnaire questions answered across all programs.
    private var overallQuestionnaireProgress: Double {
        min(max(completionPercentage / 100.0, 0), 1)
    }

    private var completedInterviewsCount: Int {
        let now = Date()
        return dataManager.programs.filter { program in
            guard let date = program.interviewDate else { return false }
            return date < now
        }.count
    }

    /// Honest subtitle for the Average Score hero.
    private var averageScoreSubtitle: String {
        let count = dataManager.programs.count
        let scored = dataManager.programs.filter { $0.finalScore > 0 }.count
        if scored == 0 {
            return "Rate programs to build your average"
        }
        return "Across \(scored) scored program\(scored == 1 ? "" : "s") of \(count)"
    }

    /// Actionable to-dos surfaced from existing data, each routing to the
    /// matching existing screen. Shows an "all caught up" state when empty.
    private var needsAttentionCard: some View {
        let items = Array(getNextSteps().prefix(4))

        return VStack(alignment: .leading, spacing: 12) {
            DashboardSectionHeader(
                title: "Needs Attention",
                icon: "bell.badge.fill",
                tint: AppColors.accentOrange
            )

            if items.isEmpty {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppColors.accentGreen.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.arial(size: 20, weight: .semibold))
                            .foregroundColor(AppColors.accentGreen)
                            .symbolRenderingMode(.hierarchical)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("You're all caught up")
                            .font(.arial(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("No pending reviews or flags right now")
                            .font(.arial(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, step in
                        NavigationLink(destination: step.destination) {
                            attentionRow(step)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .dashboardCardStyle()
    }

    @ViewBuilder
    private func attentionRow(_ step: NextStep) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(step.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: step.icon)
                    .font(.arial(size: 18, weight: .semibold))
                    .foregroundColor(step.color)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .font(.arial(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                if !step.subtitle.isEmpty {
                    Text(step.subtitle)
                        .font(.arial(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(step.color.opacity(0.08))
        )
        .contentShape(Rectangle())
    }

    // MARK: - Derived Metrics for Pages
    private var matchProgress: Double {
        min(max(averageScore / 100.0, 0), 1)
    }

    private var funnelStages: [FunnelStage] {
        let programs = dataManager.programs
        let total = programs.count
        let scheduled = programs.filter { $0.interviewDate != nil }.count
        let interviewed = completedInterviewsCount
        let ranked = programs.filter { $0.finalScore > 0 }.count
        return [
            FunnelStage(label: "Invites", count: total, color: AppColors.primaryBlue),
            FunnelStage(label: "Scheduled", count: scheduled, color: AppColors.accentTeal),
            FunnelStage(label: "Interviewed", count: interviewed, color: AppColors.accentGreen),
            FunnelStage(label: "Ranked", count: ranked, color: AppColors.accentPurple)
        ]
    }

    private var scoreBuckets: [ScoreBucket] {
        scoreDistribution.map { ScoreBucket(range: $0.range, count: $0.count, color: $0.color) }
    }

    private var topProgramMaxScore: Double {
        dataManager.programs.map { $0.finalScore }.max() ?? 0
    }

    // MARK: - Welcome Header
    @ViewBuilder
    private var welcomeHeader: some View {
        let prefs = dataManager.preferences.dashboardPreferences
        
        switch prefs.welcomeHeaderStyle {
        case .compact:
            compactWelcomeHeader
        case .expanded:
            expandedWelcomeHeader
        case .stats:
            statsWelcomeHeader
        case .default:
            defaultWelcomeHeader
        }
    }
    
    private var defaultWelcomeHeader: some View {
        let prefs = dataManager.preferences.dashboardPreferences
        let hasPrograms = !dataManager.programs.isEmpty
        
        return VStack(spacing: 20) {
            // Greeting row — compact, left-aligned, so the readiness number can
            // be the visual hero below it.
            HStack(spacing: 14) {
                Button(action: {
                    showProfileEdit = true
                }) {
                    profilePhotoView(size: 52)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(getGreeting())
                        .font(.arial(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    if prefs.showMotivationalMessage {
                        Text(getMotivationalMessage())
                            .font(.arial(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } else if prefs.showSpecialtyCount && !dataManager.preferences.specialties.isEmpty {
                        Text("Tracking \(dataManager.preferences.specialties.count) specialt\(dataManager.preferences.specialties.count == 1 ? "y" : "ies")")
                            .font(.arial(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            
            if hasPrograms {
                // "North-star" hero: Match Readiness (average score) with a ring.
                HStack(spacing: 18) {
                    matchReadinessRing
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Match Readiness")
                            .font(.arial(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Average score across \(dataManager.programs.count) program\(dataManager.programs.count == 1 ? "" : "s")")
                            .font(.arial(size: 13))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                }
                
                // Quick stats row - tappable
                if prefs.showQuickStats {
                    Divider()
                        .padding(.horizontal, -4)
                    quickStatsRow
                }
            }
        }
        .dashboardCardStyle()
    }
    
    // MARK: - Match Readiness Ring (hero focal point)
    private var matchReadinessRing: some View {
        let progress = min(max(averageScore / 100.0, 0), 1)
        return ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 8)
                .frame(width: 96, height: 96)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    scoreColor(averageScore),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 96, height: 96)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            
            VStack(spacing: 0) {
                Text(String(format: "%.0f", averageScore))
                    .font(.arial(size: 30, weight: .bold))
                    .foregroundColor(.primary)
                Text("avg")
                    .font(.arial(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var compactWelcomeHeader: some View {
        let prefs = dataManager.preferences.dashboardPreferences
        
        return VStack(spacing: 8) {
            // Profile photo and greeting
            HStack(alignment: .center, spacing: 12) {
                Button(action: {
                    showProfileEdit = true
                }) {
                    profilePhotoView(size: 56)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .center, spacing: 4) {
                    Text(getGreeting())
                        .font(.arial(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                    
                    if prefs.showMotivationalMessage {
                        Text(getMotivationalMessage())
                            .font(.arial(size: 12))
                            .foregroundColor(Color(white: 0.3))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            // Quick stats row - tappable
            if prefs.showQuickStats && !dataManager.programs.isEmpty {
                quickStatsRow
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .dashboardCardStyle()
    }
    
    private var expandedWelcomeHeader: some View {
        let prefs = dataManager.preferences.dashboardPreferences
        
        return VStack(spacing: 16) {
            // Profile photo and large greeting
            HStack(alignment: .center, spacing: 18) {
                Button(action: {
                    showProfileEdit = true
                }) {
                    profilePhotoView(size: 72)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .center, spacing: 10) {
                    Text(getGreeting())
                        .font(.arial(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                    
                    if prefs.showMotivationalMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.arial(size: 14))
                                .foregroundColor(Color(white: 0.3))
                            Text(getMotivationalMessage())
                                .font(.arial(size: 15, weight: .medium))
                                .foregroundColor(Color(white: 0.3))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    
                    if prefs.showSpecialtyCount && !dataManager.preferences.specialties.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "stethoscope")
                                .font(.arial(size: 12))
                            Text("Tracking \(dataManager.preferences.specialties.count) specialt\(dataManager.preferences.specialties.count == 1 ? "y" : "ies")")
                                .font(.arial(size: 14))
                        }
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            // Quick stats row - tappable
            if prefs.showQuickStats && !dataManager.programs.isEmpty {
                quickStatsRow
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .dashboardCardStyle()
    }
    
    private var statsWelcomeHeader: some View {
        let prefs = dataManager.preferences.dashboardPreferences
        
        return VStack(spacing: 16) {
            // Profile photo and greeting
            HStack(alignment: .center, spacing: 16) {
                Button(action: {
                    showProfileEdit = true
                }) {
                    profilePhotoView(size: 60)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .center, spacing: 8) {
                    Text(getGreeting())
                        .font(.arial(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                    
                    if prefs.showMotivationalMessage {
                        Text(getMotivationalMessage())
                            .font(.arial(size: 13))
                            .foregroundColor(Color(white: 0.3))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            // Quick stats row - tappable
            if prefs.showQuickStats && !dataManager.programs.isEmpty {
                quickStatsRow
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .dashboardCardStyle()
    }
    
    // MARK: - Quick Stats Row (reusable component)
    private var quickStatsRow: some View {
        HStack(spacing: 12) {
            Button(action: {
                selectedTab = MainTabLayout.programsIndex
            }) {
                QuickStatMini(
                    value: "\(dataManager.programs.count)",
                    label: "Programs",
                    color: .blue
                )
            }
            .buttonStyle(.plain)
            
            Button(action: {
                selectedTab = MainTabLayout.interviewsIndex
            }) {
                QuickStatMini(
                    value: "\(interviewCount)",
                    label: "Interviews",
                    color: .green
                )
            }
            .buttonStyle(.plain)
            
            QuickStatMini(
                value: String(format: "%.1f", averageScore),
                label: "Avg Score",
                color: .orange
            )
            
            NavigationLink(destination: AllSignaledProgramsView()) {
                QuickStatMini(
                    value: "\(totalSignalCount)",
                    label: "Signals",
                    color: .purple
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Helper Functions
    @ViewBuilder
    private func profilePhotoView(size: CGFloat) -> some View {
        if let photoData = dataManager.preferences.profile.photoData,
           let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2.5)
                )
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 3)
        } else {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemGray5),
                            Color(.systemGray6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(Color(.separator).opacity(0.3), lineWidth: 1.5)
                )
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.arial(size: size * 0.45, weight: .medium))
                        .foregroundColor(Color(.systemGray))
                )
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
    }
    
    private func getGreeting() -> String {
        let prefs = dashboardPreferences
        let name = dataManager.preferences.profile.greetingFirstName
        
        switch prefs.greetingStyle {
        case .timeBased:
            let hour = Calendar.current.component(.hour, from: Date())
            let timeGreeting: String
            if hour < 12 {
                timeGreeting = "Good morning"
            } else if hour < 17 {
                timeGreeting = "Good afternoon"
            } else {
                timeGreeting = "Good evening"
            }
            return name.isEmpty ? "\(timeGreeting)!" : "\(timeGreeting), \(name)!"
            
        case .casual:
            return name.isEmpty ? "Hey there!" : "Hey, \(name)!"
            
        case .formal:
            return name.isEmpty ? "Welcome" : "Welcome, \(name)"
            
        case .motivational:
            let messages = [
                name.isEmpty ? "You've got this!" : "You've got this, \(name)!",
                name.isEmpty ? "Let's make progress!" : "Let's make progress, \(name)!",
                name.isEmpty ? "Ready to rank?" : "Ready to rank, \(name)?"
            ]
            return messages[Self.stableDailyIndex % messages.count]
        }
    }
    
    /// A stable index that changes once per calendar day. Used to pick a
    /// "random-feeling" message that stays consistent across view re-renders
    /// (avoids text flickering on every refresh).
    private static var stableDailyIndex: Int {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return abs(day)
    }
    
    private func getMotivationalMessage() -> String {
        let messages = [
            "Keep tracking your progress!",
            "Every program review brings you closer to your match.",
            "You're building a strong rank list!",
            "Stay organized and focused!",
            "Your future residency is taking shape!",
            "Every step forward counts!",
            "You've got this!",
            "Believe in yourself and your journey!",
            "Success is built one program at a time.",
            "Your hard work will pay off!",
            "Stay positive and keep moving forward!",
            "You're on the right path!",
            "Trust the process!",
            "Your dedication will lead to success!",
            "Keep pushing forward!"
        ]
        return messages[Self.stableDailyIndex % messages.count]
    }
    
    // MARK: - Quick Stats
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionHeader(title: "Key Metrics", icon: "chart.bar.fill", tint: AppColors.primaryBlue)
            
            // Compact grid layout with better spacing
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                // Total Programs - Primary KPI (top-left priority)
                Button(action: {
                    selectedTab = MainTabLayout.programsIndex
                }) {
                    StatCard(
                        title: "Total Programs",
                        value: "\(dataManager.programs.count)",
                        icon: "list.bullet.rectangle",
                        color: AppColors.primaryBlue,
                        subtitle: "\(programsWithData) with data"
                    )
                }
                .buttonStyle(.plain)
                
                // Needs Review - Warning indicator (red for attention needed)
                NavigationLink(destination: ProgramsNeedingReviewView()) {
                    StatCard(
                        title: "Needs Review",
                        value: "\(programsNeedingReview)",
                        icon: "exclamationmark.triangle.fill",
                        color: programsNeedingReview > 0 ? .red : .secondary,
                        subtitle: programsNeedingReview > 0 ? "action required" : "all complete"
                    )
                }
                .buttonStyle(.plain)
                
                // Interviews - Success indicator (green for positive status)
                Button(action: {
                    selectedTab = MainTabLayout.interviewsIndex
                }) {
                    StatCard(
                        title: "Interviews",
                        value: "\(interviewCount)",
                        icon: "calendar.badge.clock",
                        color: interviewCount > 0 ? .green : .secondary,
                        subtitle: "\(upcomingInterviews.count) upcoming"
                    )
                }
                .buttonStyle(.plain)
                
                // Top Program - Compact version matching StatCard style
                if let topProgram = dataManager.getRankedPrograms().first {
                    NavigationLink(destination: ProgramEntryView(program: topProgram)) {
                        StatCard(
                            title: "Top Program",
                            value: topProgramName,
                            icon: "trophy.fill",
                            color: AppColors.primaryBlue,
                            subtitle: String(format: "Score: %.1f", topProgramScore),
                            isLongText: true
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    StatCard(
                        title: "Top Program",
                        value: "None",
                        icon: "trophy.fill",
                        color: AppColors.primaryBlue,
                        subtitle: "No programs yet",
                        isLongText: true
                    )
                }
            }
        }
        .dashboardCardStyle()
    }
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DashboardSectionHeader(title: "Quick Actions", icon: "bolt.fill", tint: AppColors.accentOrange)
            
            HStack(spacing: 8) {
                QuickActionButton(
                    title: "Add Program",
                    icon: "plus.circle.fill",
                    color: AppColors.accentPink,
                    action: { showAddProgram = true }
                )
                
                Button(action: {
                    selectedTab = MainTabLayout.programsIndex
                }) {
                    QuickActionContent(
                        title: "My Programs",
                        icon: "list.bullet.rectangle",
                        color: AppColors.accentGreen
                    )
                }
                
                Button(action: {
                    selectedTab = MainTabLayout.rankListIndex(isCoupleLinked: isCoupleLinked)
                }) {
                    QuickActionContent(
                        title: "Rank List",
                        icon: "chart.bar.fill",
                        color: AppColors.primaryBlue
                    )
                }
            }
        }
        .dashboardCardStyle()
    }
    
    
    // MARK: - Top Programs
    private var topProgramsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DashboardSectionHeader(title: "Top Programs", icon: "trophy.fill", tint: AppColors.accentOrange) {
                NavigationLink(destination: RankListView()) {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.arial(size: 15, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.arial(size: 11))
                    }
                    .foregroundColor(AppColors.primaryBlue)
                }
            }
            
            VStack(spacing: 6) {
                ForEach(Array(topPrograms.prefix(3).enumerated()), id: \.element.id) { index, program in
                    NavigationLink(destination: ProgramEntryView(program: program)) {
                        TopProgramRow(program: program, rank: index + 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .dashboardCardStyle()
    }
    
    // MARK: - Empty State
    private var emptyStateSection: some View {
        Group {
            if MatchlyDeviceLayout.isPad && horizontalSizeClass == .regular {
                iPadEmptyStateSection
            } else {
                phoneEmptyStateSection
            }
        }
    }

    private var phoneEmptyStateSection: some View {
        VStack(spacing: 22) {
            MatchlyBrandMark(size: .feature)

            MatchlyBrandHairline(width: 44)

            VStack(spacing: 12) {
                Text("Get Started")
                    .font(.arial(size: 24, weight: .light))
                    .foregroundColor(.primary)
                    .kerning(1)

                MatchlyEditorialBody(
                    text: "Add your first residency program to begin building your rank list."
                )
                .padding(.horizontal, 28)
            }

            emptyStateAddButton
        }
        .padding(.vertical, 50)
    }

    private var iPadEmptyStateSection: some View {
        HStack(alignment: .center, spacing: 40) {
            MatchlyBrandMark(size: .onboarding)

            VStack(alignment: .leading, spacing: 16) {
                Text("Get Started")
                    .font(.arial(size: 28, weight: .light))
                    .foregroundColor(.primary)
                    .kerning(1)

                MatchlyEditorialBody(
                    text: "Add your first residency program to begin building your rank list.",
                    alignment: .leading
                )
                .frame(maxWidth: 420, alignment: .leading)

                emptyStateAddButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
    }

    private var emptyStateAddButton: some View {
        Button(action: {
            showAddProgram = true
        }) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.arial(size: 18, weight: .medium))
                Text("Add Your First Program")
                    .font(.arial(size: 17, weight: .semibold))
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 15)
        }
        .buttonStyle(.glassProminent)
        .tint(AppColors.primaryBlue)
    }
    
    // MARK: - Computed Properties
    private var interviewCount: Int {
        dataManager.programs.filter { $0.interviewDate != nil }.count
    }
    
    private var averageScore: Double {
        let scores = dataManager.programs.map { $0.finalScore }
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }
    
    private var topProgramName: String {
        guard let top = dataManager.getRankedPrograms().first else {
            return "None"
        }
        let name = top.hospital.isEmpty ? top.name : top.hospital
        return HospitalNameFormatter.format(name)
    }
    
    private var topPrograms: [Program] {
        Array(dataManager.getRankedPrograms().prefix(5))
    }
    
    private var upcomingInterviews: [Program] {
        let now = Date()
        return dataManager.programs
            .filter { program in
                guard let date = program.interviewDate else { return false }
                return date >= now
            }
            .sorted { ($0.interviewDate ?? now) < ($1.interviewDate ?? now) }
    }

    private var completedInterviews: [Program] {
        let now = Date()
        return dataManager.programs
            .filter { program in
                guard let date = program.interviewDate else { return false }
                return date < now
            }
            .sorted { ($0.interviewDate ?? now) > ($1.interviewDate ?? now) }
    }
    
    private var goldSignalCount: Int {
        dataManager.programs.filter { program in
            program.signalType == .gold && SignalLimits.isTiered(for: program.specialty)
        }.count
    }
    
    private var silverSignalCount: Int {
        dataManager.programs.filter { program in
            program.signalType == .silver && SignalLimits.isTiered(for: program.specialty)
        }.count
    }
    
    private var singleLevelSignalCount: Int {
        dataManager.programs.filter { program in
            program.signalType == .gold && !SignalLimits.isTiered(for: program.specialty)
        }.count
    }
    
    private var totalSignalCount: Int {
        goldSignalCount + silverSignalCount + singleLevelSignalCount
    }
    
    // Check if user has any tiered signal programs
    private var hasTieredSignals: Bool {
        dataManager.programs.contains { program in
            (program.signalType == .gold || program.signalType == .silver) && SignalLimits.isTiered(for: program.specialty)
        }
    }
    
    // Check if user has any single-level signal programs
    private var hasSingleLevelSignals: Bool {
        dataManager.programs.contains { program in
            program.signalType == .gold && !SignalLimits.isTiered(for: program.specialty)
        }
    }
    
    // MARK: - Programs Tab: Signals & Status
    private var signalBudgetSummaries: [DataManager.SignalBudgetSummary] {
        dataManager.signalBudgetSummaries()
    }

    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DashboardSectionHeader(
                title: "Signals & Status",
                icon: "star.circle.fill",
                tint: AppColors.accentOrange
            )

            if !signalBudgetSummaries.isEmpty {
                DashboardSignalsDetailBlock(summaries: signalBudgetSummaries)
            }

            if programsNeedingReview > 0 {
                if !signalBudgetSummaries.isEmpty {
                    Divider()
                        .padding(.vertical, 2)
                }
                NavigationLink(destination: ProgramsNeedingReviewView()) {
                    programsStatusRow(
                        title: "\(programsNeedingReview) Program\(programsNeedingReview == 1 ? "" : "s") Need Review",
                        subtitle: "Questionnaires still incomplete after interviews",
                        icon: "exclamationmark.triangle.fill",
                        tint: .orange
                    )
                }
                .buttonStyle(.plain)
            }

            if redFlaggedProgramsCount > 0 {
                NavigationLink(destination: RedFlaggedProgramsView()) {
                    programsStatusRow(
                        title: "\(redFlaggedProgramsCount) Program\(redFlaggedProgramsCount == 1 ? "" : "s") with Red Flags",
                        subtitle: "Review flagged concerns before ranking",
                        icon: "flag.fill",
                        tint: .red
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .dashboardCardStyle()
    }

    private func programsStatusRow(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.arial(size: 14, weight: .semibold))
                    .foregroundColor(tint)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.arial(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.arial(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
    
    // MARK: - Next Steps Section
    private var nextStepsSection: some View {
        let nextSteps = getNextSteps()
        
        guard !nextSteps.isEmpty else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                DashboardSectionHeader(title: "Next Steps", icon: "checklist", tint: AppColors.accentPurple)
                
                VStack(spacing: 8) {
                    ForEach(Array(nextSteps.prefix(3).enumerated()), id: \.offset) { index, step in
                        NavigationLink(destination: step.destination) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(step.color.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: step.icon)
                                        .font(.arial(size: 18, weight: .semibold))
                                        .foregroundColor(step.color)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(step.title)
                                        .font(.arial(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    if !step.subtitle.isEmpty {
                                        Text(step.subtitle)
                                            .font(.arial(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.arial(size: 12))
                                    .foregroundColor(.secondary.opacity(0.4))
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(step.color.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .dashboardCardStyle()
        )
    }
    
    // MARK: - Recent Activity Section
    private var recentActivitySection: some View {
        let recentPrograms = getRecentPrograms()
        
        guard !recentPrograms.isEmpty else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                DashboardSectionHeader(title: "Recent Activity", icon: "clock.fill", tint: AppColors.accentPurple)
                
                VStack(spacing: 8) {
                    ForEach(Array(recentPrograms.prefix(3)), id: \.id) { program in
                        NavigationLink(destination: ProgramEntryView(program: program)) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.primaryBlue.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: "plus.circle.fill")
                                        .font(.arial(size: 18, weight: .semibold))
                                        .foregroundColor(AppColors.primaryBlue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(HospitalNameFormatter.format(program.hospital.isEmpty ? program.name : program.hospital))
                                        .font(.arial(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    Text("Added recently")
                                        .font(.arial(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.arial(size: 12))
                                    .foregroundColor(.secondary.opacity(0.4))
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .dashboardCardStyle()
        )
    }
    
    // MARK: - Helper Methods for Next Steps
    private func getNextSteps() -> [NextStep] {
        var steps: [NextStep] = []

        // Invites missing an interview date — the most common first step after adding a program.
        let programsWithoutInterviews = dataManager.programs.filter { $0.interviewDate == nil }
        if !programsWithoutInterviews.isEmpty {
            steps.append(NextStep(
                title: programsWithoutInterviews.count == 1 ? "Set interview date" : "Set interview dates",
                subtitle: "\(programsWithoutInterviews.count) invite\(programsWithoutInterviews.count == 1 ? "" : "s") missing a date",
                icon: "calendar.badge.plus",
                color: AppColors.accentOrange,
                destination: AnyView(SetInterviewDatesView())
            ))
        }

        // Scoring to-dos — post-interview first, then partial, then never started.
        if postInterviewNeedingScoreCount > 0 {
            steps.append(NextStep(
                title: "Score \(postInterviewNeedingScoreCount) interview\(postInterviewNeedingScoreCount == 1 ? "" : "s")",
                subtitle: "Complete questionnaires after your visit",
                icon: "list.star",
                color: AppColors.primaryBlue,
                destination: AnyView(ProgramsNeedingReviewView())
            ))
        } else if programsNeedingScoringCount > 0 {
            steps.append(NextStep(
                title: "Finish scoring \(programsNeedingScoringCount) program\(programsNeedingScoringCount == 1 ? "" : "s")",
                subtitle: "Complete questionnaires for your rank list",
                icon: "square.and.pencil",
                color: AppColors.primaryBlue,
                destination: AnyView(ProgramsNeedingReviewView())
            ))
        }

        // Upcoming interview within the next week.
        if let soon = upcomingInterviewsThisWeek.first, let date = soon.interviewDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            let name = HospitalNameFormatter.format(soon.hospital.isEmpty ? soon.name : soon.hospital)
            steps.append(NextStep(
                title: "Prep for \(name)",
                subtitle: "Interview \(Calendar.current.isDateInToday(date) ? "today" : "on \(formatter.string(from: date))")",
                icon: "calendar.badge.clock",
                color: AppColors.accentGreen,
                destination: AnyView(InterviewPrepView(program: soon))
            ))
        }

        return steps
    }

    private var upcomingInterviewsThisWeek: [Program] {
        let now = Date()
        guard let weekOut = Calendar.current.date(byAdding: .day, value: 7, to: now) else {
            return upcomingInterviews
        }
        return upcomingInterviews.filter { program in
            guard let date = program.interviewDate else { return false }
            return date <= weekOut
        }
    }
    
    private func getRecentPrograms() -> [Program] {
        // Programs are appended in the order they're added, so the tail of the
        // array is the most recently added. Reverse so newest appears first.
        return Array(dataManager.programs.suffix(5).reversed())
    }
    
    // MARK: - Analytics Computed Properties
    private var programsWithData: Int {
        dataManager.programs.filter { program in
            program.questionnaire.sections.contains { section in
                section.items.contains { $0.programRating > 0 }
            }
        }.count
    }
    
    private var programsNeedingReview: Int {
        programsNeedingScoringCount
    }
    
    private var topProgramScore: Double {
        dataManager.getRankedPrograms().first?.finalScore ?? 0
    }
    
    private var scoreDistribution: [(range: String, count: Int, color: Color)] {
        let programs = dataManager.programs
        guard !programs.isEmpty else { return [] }
        
        var buckets: [String: Int] = [
            "0-19": 0,
            "20-39": 0,
            "40-59": 0,
            "60-79": 0,
            "80-100": 0
        ]
        
        for program in programs {
            let score = program.finalScore
            switch score {
            case 0..<20: buckets["0-19"]? += 1
            case 20..<40: buckets["20-39"]? += 1
            case 40..<60: buckets["40-59"]? += 1
            case 60..<80: buckets["60-79"]? += 1
            default: buckets["80-100"]? += 1
            }
        }
        
        return [
            ("0-19", buckets["0-19"] ?? 0, .red),
            ("20-39", buckets["20-39"] ?? 0, .orange),
            ("40-59", buckets["40-59"] ?? 0, .yellow),
            ("60-79", buckets["60-79"] ?? 0, .blue),
            ("80-100", buckets["80-100"] ?? 0, .green)
        ]
    }
    
    private var ratedProgramsCount: Int {
        programsWithData
    }
    
    private var redFlaggedProgramsCount: Int {
        dataManager.programs.filter { $0.hasRedFlags() }.count
    }
    
    private var completionPercentage: Double {
        let programs = dataManager.programs
        guard !programs.isEmpty else { return 0 }
        let prefs = dataManager.preferences

        let ratios = programs.map { $0.questionnaireCompletionRatio(preferences: prefs) }
        return (ratios.reduce(0, +) / Double(ratios.count)) * 100
    }
    
    private func getSignalProgress() -> Double {
        let summaries = dataManager.signalBudgetSummaries()
        guard !summaries.isEmpty else { return 0 }

        let totalUsed = summaries.reduce(0) { $0 + $1.goldUsed + $1.silverUsed }
        let totalAvailable = summaries.reduce(0) { partial, summary in
            partial + summary.goldLimit + summary.silverLimit
        }

        guard totalAvailable > 0 else { return 0 }
        return min(Double(totalUsed) / Double(totalAvailable), 1.0)
    }
    
    // MARK: - Dashboard Layout Helpers

    private func shouldShowSection(_ sectionId: String) -> Bool {
        guard layout.isSectionEnabled(sectionId) else { return false }

        switch sectionId {
        case "needsAttention", "overviewHero", "quickActions":
            return true
        case "analytics":
            let hasStatus = programsNeedingReview > 0 || redFlaggedProgramsCount > 0
            return !signalBudgetSummaries.isEmpty || (!dataManager.programs.isEmpty && hasStatus)
        case "programsCompare":
            return dataManager.programs.count >= 2
        default:
            return false
        }
    }
    
}

// MARK: - Supporting Views

/// Unified dashboard section header: a neutral, high-contrast title paired with
/// a small tinted icon chip. Replaces the previous multi-colored titles for a
/// calmer, more premium look (Monarch / QuickBooks style).
struct DashboardSectionHeader<Trailing: View>: View {
    let title: String
    let icon: String
    let tint: Color
    @ViewBuilder var trailing: () -> Trailing
    
    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.arial(size: 16, weight: .semibold))
                    .foregroundColor(tint)
                    .symbolRenderingMode(.hierarchical)
            }
            
            Text(title)
                .font(MatchlyEditorialTypography.displayFont(size: 16))
                .foregroundColor(.primary)
                .kerning(MatchlyEditorialTypography.heroTitleKerning(for: 16))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            
            Spacer(minLength: 8)
            
            trailing()
        }
        .padding(.bottom, 4)
    }
}

extension DashboardSectionHeader where Trailing == EmptyView {
    init(title: String, icon: String, tint: Color) {
        self.init(title: title, icon: icon, tint: tint) { EmptyView() }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let subtitle: String
    let isLongText: Bool // For "Top Program" which has long hospital names
    
    init(title: String, value: String, icon: String, color: Color, subtitle: String, isLongText: Bool = false) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.subtitle = subtitle
        self.isLongText = isLongText
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.arial(size: 18, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.arial(size: isLongText ? 15 : 24, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(isLongText ? 2 : 1)
                .minimumScaleFactor(isLongText ? 0.7 : 0.8)
            
            Text(title)
                .font(.arial(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.arial(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 110, maxHeight: 110, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .contentShape(Rectangle()) // Makes entire card tappable
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            QuickActionContent(title: title, icon: icon, color: color)
        }
    }
}

struct QuickActionContent: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.arial(size: 18, weight: .semibold))
                    .foregroundColor(color)
                    .symbolRenderingMode(.hierarchical)
            }
            
            Text(title)
                .font(.arial(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
    }
}

struct SpecialtyBreakdownRow: View {
    let specialty: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack {
            HStack(spacing: 5) {
                Image(systemName: "stethoscope")
                    .font(.arial(size: 11))
                    .foregroundColor(color)
                Text("\(specialty) (\(SpecialtyFormatter.abbreviation(for: specialty)))")
                    .font(.arial(size: 13, weight: .medium))
            }
            
            Spacer()
            
            Text("\(count)")
                .font(.arial(size: 14, weight: .bold))
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.12))
                .cornerRadius(6)
        }
        .padding(.vertical, 5)
    }
}

struct TopProgramRow: View {
    let program: Program
    let rank: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank indicator - cleaner and more vibrant
            ZStack {
                Circle()
                    .fill(scoreColor(program.finalScore).opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Text("\(rank)")
                    .font(.arial(size: 16, weight: .bold))
                    .foregroundColor(scoreColor(program.finalScore))
            }
            
            // Program info
            VStack(alignment: .leading, spacing: 4) {
                Text(HospitalNameFormatter.format(program.hospital.isEmpty ? program.name : program.hospital))
                    .font(.arial(size: 15, weight: .semibold))
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 6) {
                    if !program.city.isEmpty && !program.state.isEmpty {
                        Text("\(program.city), \(program.state)")
                            .font(.arial(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.arial(size: 10))
                        Text(String(format: "%.1f", program.finalScore))
                            .font(.arial(size: 13, weight: .semibold))
                    }
                    .foregroundColor(scoreColor(program.finalScore))

                    ProgramVoiceMemoBadge(program: program, iconSize: 9, textSize: 11)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.arial(size: 12))
                .foregroundColor(.secondary.opacity(0.4))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }
    
}

// MARK: - Helper Functions
extension DashboardView {
    private func findAndPopNavigationControllers(in viewController: UIViewController) {
        if let navController = viewController as? UINavigationController {
            navController.popToRootViewController(animated: true)
        }
        
        for child in viewController.children {
            findAndPopNavigationControllers(in: child)
        }
        
        if let presented = viewController.presentedViewController {
            findAndPopNavigationControllers(in: presented)
        }
    }
}

struct NextStep {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let destination: AnyView
}

struct QuickStatMini: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.arial(size: 16, weight: .bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.arial(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DashboardView()
        .environmentObject(DataManager.shared)
}

