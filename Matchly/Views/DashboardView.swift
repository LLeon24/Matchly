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

struct DashboardView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showAddProgram = false
    @Binding var selectedTab: Int
    
    init(selectedTab: Binding<Int> = .constant(0)) {
        _selectedTab = selectedTab
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    // Welcome Header
                    welcomeHeader
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Quick Stats Cards
                    quickStatsSection
                    
                    // Analytics Section - Always visible when there are programs
                    if !dataManager.programs.isEmpty {
                        analyticsSection
                    }
                    
                    // Top Programs Preview
                    if !topPrograms.isEmpty {
                        topProgramsSection
                    }
                    
                    // Upcoming Interviews
                    if !upcomingInterviews.isEmpty {
                        upcomingInterviewsSection
                    }
                    
                    // Recent Activity or Empty State
                    if dataManager.programs.isEmpty {
                        emptyStateSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 90) // Space for custom tab bar
                .id("top") // ID for scrolling to top
            }
            .navigationTitle("Dashboard")
            .background(Color(.systemGroupedBackground))
            .onAppear {
                // Only recalculate scores if preferences changed (optimization)
                // Full recalculation happens on data load, so we skip it here to prevent lag
                // Uncomment if you need real-time score updates:
                // dataManager.recalculateAllScores()
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                // When dashboard tab is selected, scroll to top
                if newValue == 0 {
                    withAnimation {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScrollToTop"))) { _ in
                withAnimation {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PopToRoot"))) { _ in
                // Pop to root when Dashboard tab is tapped
                // This will dismiss any NavigationLink destinations (like Signals view)
                DispatchQueue.main.async {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootViewController = window.rootViewController {
                        findAndPopNavigationControllers(in: rootViewController)
                    }
                }
            }
            .refreshable {
                dataManager.recalculateAllScores()
                dataManager.objectWillChange.send()
            }
        }
        .sheet(isPresented: $showAddProgram) {
            NavigationView {
                ProgramSearchView(
                    onSelect: { programInfo in
                        let newProgram = Program(
                            specialty: programInfo.specialty,
                            name: programInfo.name,
                            hospital: HospitalNameFormatter.format(programInfo.hospital),
                            city: programInfo.city,
                            state: programInfo.state,
                            address: programInfo.address,
                            type: programInfo.type,
                            accreditationID: programInfo.accreditationID,
                            websiteURL: programInfo.websiteURL,
                            contactEmail: programInfo.contactEmail,
                            contactPhone: programInfo.contactPhone,
                            programCoordinator: programInfo.programCoordinator,
                            isIMGFriendly: programInfo.isIMGFriendly
                        )
                        dataManager.addProgram(newProgram)
                    },
                    allowMultiSelect: true
                )
            }
        }
    }
    
    // MARK: - Welcome Header
    private var welcomeHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Matchly app icon - personalized branding
                Image("MatchlyIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .cornerRadius(11) // iOS app icon corner radius
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                
                VStack(alignment: .leading, spacing: 3) {
                    if !dataManager.preferences.profile.name.isEmpty {
                        Text("Welcome back, \(dataManager.preferences.profile.name)!")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                    } else {
                        Text("Welcome back!")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    
                    if !dataManager.preferences.specialties.isEmpty {
                        Text("Tracking \(dataManager.preferences.specialties.count) specialt\(dataManager.preferences.specialties.count == 1 ? "y" : "ies")")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Profile photo or icon - tappable to edit
                NavigationLink(destination: ProfileEditView()) {
                    ZStack {
                        if let photoData = dataManager.preferences.profile.photoData,
                           let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.0, green: 0.48, blue: 0.65).opacity(0.12))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "person.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(Color(red: 0.0, green: 0.48, blue: 0.65))
                            }
                        }
                        
                        // Edit indicator - only show if no photo (remove plus sign when photo exists)
                        if dataManager.preferences.profile.photoData == nil {
                            VStack {
                                HStack {
                                    Spacer()
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 18, height: 18)
                                        
                                        Image(systemName: "plus")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    .offset(x: 2, y: -2)
                                }
                                Spacer()
                            }
                            .frame(width: 44, height: 44)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
    }
    
    // MARK: - Quick Stats
    private var quickStatsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            // Total Programs - Navigate to My Programs tab
            Button(action: {
                selectedTab = 1 // My Programs tab
            }) {
                StatCard(
                    title: "Total Programs",
                    value: "\(dataManager.programs.count)",
                    icon: "list.bullet.rectangle",
                    color: .blue,
                    subtitle: "\(programsWithData) with data"
                )
            }
            .buttonStyle(.plain)
            
            // Needs Review - Navigate to ProgramsNeedingReviewView
            NavigationLink(destination: ProgramsNeedingReviewView()) {
                StatCard(
                    title: "Needs Review",
                    value: "\(programsNeedingReview)",
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    subtitle: "incomplete data"
                )
            }
            .buttonStyle(.plain)
            
            // Interviews - Navigate to InterviewsView
            NavigationLink(destination: InterviewsView()) {
                StatCard(
                    title: "Interviews",
                    value: "\(interviewCount)",
                    icon: "calendar.badge.clock",
                    color: .green,
                    subtitle: "\(upcomingInterviews.count) upcoming"
                )
            }
            .buttonStyle(.plain)
            
            // Top Program - Navigate to program detail
            if let topProgram = dataManager.getRankedPrograms().first {
                NavigationLink(destination: ProgramEntryView(program: topProgram)) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.primaryBlue)
                                .frame(width: 16, height: 16)
                            Spacer()
                        }
                        
                        Text(topProgramName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        
                        Text("Top Program")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: "Score: %.1f", topProgramScore))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.7))
                            
                            // Accreditation ID - subtle, no background
                            if let acgmeID = topProgram.accreditationID {
                                HStack(spacing: 2) {
                                    Image(systemName: "number.circle.fill")
                                        .font(.system(size: 8))
                                    Text("ID:")
                                        .font(.system(size: 9, weight: .medium))
                                    Text(acgmeID)
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 110, maxHeight: 110, alignment: .leading)
                    .background(
                        ZStack {
                            // Lighter glass effect with more white
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.6),
                                                    Color.white.opacity(0.3)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                            
                            // Subtle gradient border
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.5),
                                            Color.white.opacity(0.2),
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        }
                    )
                    .shadow(color: Color.white.opacity(0.3), radius: 10, x: 0, y: -2)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
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
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Actions")
                .font(.system(size: 17, weight: .semibold))
                .padding(.horizontal, 2)
            
            HStack(spacing: 10) {
                QuickActionButton(
                    title: "Add Program",
                    icon: "plus.circle.fill",
                    color: AppColors.accentPink,
                    action: { showAddProgram = true }
                )
                
                Button(action: {
                    selectedTab = 1 // My Programs tab
                }) {
                    QuickActionContent(
                        title: "My Programs",
                        icon: "list.bullet.rectangle",
                        color: AppColors.accentGreen
                    )
                }
                
                Button(action: {
                    selectedTab = 2 // Rank List tab
                }) {
                    QuickActionContent(
                        title: "Rank List",
                        icon: "chart.bar.fill",
                        color: AppColors.primaryBlue
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
    }
    
    
    // MARK: - Top Programs
    private var topProgramsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Top Programs")
                    .font(.system(size: 17, weight: .semibold))
                
                Spacer()
                
                NavigationLink(destination: RankListView()) {
                    Text("View All")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.primaryBlue)
                }
            }
            .padding(.horizontal, 2)
            
            VStack(spacing: 6) {
                ForEach(Array(topPrograms.prefix(3).enumerated()), id: \.element.id) { index, program in
                    NavigationLink(destination: ProgramEntryView(program: program)) {
                        TopProgramRow(program: program, rank: index + 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
    }
    
    // MARK: - Upcoming Interviews
    private var upcomingInterviewsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Upcoming Interviews")
                .font(.system(size: 17, weight: .semibold))
                .padding(.horizontal, 2)
            
            VStack(spacing: 6) {
                ForEach(Array(upcomingInterviews.prefix(3)), id: \.id) { program in
                    NavigationLink(destination: ProgramEntryView(program: program)) {
                        UpcomingInterviewRow(program: program)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
    }
    
    // MARK: - Empty State
    private var emptyStateSection: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.0, green: 0.48, blue: 0.65).opacity(0.08))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(Color(red: 0.0, green: 0.48, blue: 0.65))
            }
            
            VStack(spacing: 10) {
                Text("Get Started")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Add your first residency program to begin building your rank list")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineSpacing(2)
            }
            
            Button(action: {
                showAddProgram = true
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                    Text("Add Your First Program")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 15)
                .background(Color(red: 0.0, green: 0.48, blue: 0.65))
                .cornerRadius(12)
            }
        }
        .padding(.vertical, 50)
    }
    
    // MARK: - Computed Properties
    private var rankedProgramsCount: Int {
        dataManager.getRankedPrograms().count
    }
    
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
    
    private var specialtyBreakdown: [String: Int] {
        Dictionary(grouping: dataManager.programs, by: { $0.specialty })
            .mapValues { $0.count }
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
    
    // MARK: - Analytics Section
    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header - more compact
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 0.0, green: 0.48, blue: 0.65))
                
                Text("Analytics & Insights")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
            }
            
            // Key Metrics Row - moved to top, more compact
            HStack(spacing: 8) {
                AnalyticsStatCard(
                    title: "Avg Score",
                    value: String(format: "%.1f", averageScore),
                    icon: "star.fill",
                    color: .orange
                )
                
                AnalyticsStatCard(
                    title: "Complete",
                    value: "\(Int(completionPercentage))%",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                AnalyticsStatCard(
                    title: "Rated",
                    value: "\(ratedProgramsCount)/\(dataManager.programs.count)",
                    icon: "chart.bar.fill",
                    color: .blue
                )
            }
            
            // Red Flags Warning - show if any programs have red flags
            if redFlaggedProgramsCount > 0 {
                NavigationLink(destination: RedFlaggedProgramsView()) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                        Text("\(redFlaggedProgramsCount) program\(redFlaggedProgramsCount == 1 ? "" : "s") with red flags")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red)
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            // Signal Tracking - All, Gold, and Silver (always show)
            VStack(spacing: 8) {
                // All Signals - full width
                NavigationLink(destination: AllSignaledProgramsView()) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                            .frame(width: 22)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Signals")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("\(totalSignalCount) program\(totalSignalCount == 1 ? "" : "s") total")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            // Show tiered signals (Gold/Silver) if user has any tiered signal programs
                            if hasTieredSignals {
                                if goldSignalCount > 0 {
                                    HStack(spacing: 2) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 9))
                                        Text("\(goldSignalCount)")
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .foregroundColor(.yellow)
                                }
                                
                                if silverSignalCount > 0 {
                                    HStack(spacing: 2) {
                                        Image(systemName: "star")
                                            .font(.system(size: 9))
                                        Text("\(silverSignalCount)")
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .foregroundColor(.gray)
                                }
                            }
                            
                            // Show single-level signals if user has any single-level signal programs
                            if hasSingleLevelSignals && singleLevelSignalCount > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 9))
                                    Text("\(singleLevelSignalCount)")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundColor(.blue)
                            }
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.ultraThinMaterial)
                            
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(totalSignalCount > 0 ? 0.08 : 0.04))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(totalSignalCount > 0 ? 0.25 : 0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Programs Needing Attention - more compact
            if programsNeedingReview > 0 {
                NavigationLink(destination: ProgramsNeedingReviewView()) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .frame(width: 20)
                        
                        Text("\(programsNeedingReview) need review")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            // Specialty Breakdown - horizontal compact layout
            if !specialtyBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("By Specialty")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    // Horizontal scrollable specialty chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(specialtyBreakdown.sorted(by: { $0.value > $1.value }).prefix(5)), id: \.key) { specialty, count in
                                HStack(spacing: 4) {
                                    Image(systemName: "stethoscope")
                                        .font(.system(size: 10))
                                        .foregroundColor(SpecialtyFormatter.color(for: specialty))
                                    
                                    Text(SpecialtyFormatter.abbreviation(for: specialty))
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(SpecialtyFormatter.color(for: specialty))
                                    
                                    Text("\(count)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(SpecialtyFormatter.color(for: specialty).opacity(0.12))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
            }
            
            // Score Distribution - more compact
            if !scoreDistribution.isEmpty && scoreDistribution.contains(where: { $0.count > 0 }) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Score Distribution")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(scoreDistribution, id: \.range) { bucket in
                            VStack(spacing: 3) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(bucket.color)
                                    .frame(height: max(2, CGFloat(bucket.count) * 4))
                                
                                Text("\(bucket.count)")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundColor(.secondary)
                                
                                Text(bucket.range)
                                    .font(.system(size: 7))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 50)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
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
        dataManager.programs.filter { program in
            // Program has no questionnaire data or very incomplete data
            let hasAnyRating = program.questionnaire.sections.contains { section in
                section.items.contains { $0.programRating > 0 }
            }
            return !hasAnyRating
        }.count
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
        
        var totalQuestions = 0
        var answeredQuestions = 0
        
        for program in programs {
            for section in program.questionnaire.sections {
                if section.title.contains("Red flags") { continue }
                for item in section.items {
                    totalQuestions += 1
                    if item.programRating > 0 {
                        answeredQuestions += 1
                    }
                }
            }
        }
        
        guard totalQuestions > 0 else { return 0 }
        return (Double(answeredQuestions) / Double(totalQuestions)) * 100
    }
    
}

// MARK: - Supporting Views

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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 16, height: 16)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: isLongText ? 14 : 24, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(isLongText ? 2 : 1)
                .minimumScaleFactor(isLongText ? 0.7 : 0.8)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 110, maxHeight: 110, alignment: .leading)
        .background(
            ZStack {
                // Lighter glass effect with more white
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                
                // Subtle gradient border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .shadow(color: Color.white.opacity(0.3), radius: 10, x: 0, y: -2)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
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
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                color.opacity(0.3),
                                color.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .shadow(color: color.opacity(0.2), radius: 10, x: 0, y: 4)
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
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text("\(specialty) (\(SpecialtyFormatter.abbreviation(for: specialty)))")
                    .font(.system(size: 13, weight: .medium))
            }
            
            Spacer()
            
            Text("\(count)")
                .font(.system(size: 14, weight: .bold))
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
        HStack(spacing: 10) {
            // Rank indicator - smaller
            ZStack {
                Circle()
                    .fill(scoreColor(program.finalScore).opacity(0.12))
                    .frame(width: 32, height: 32)
                
                Text("\(rank)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(scoreColor(program.finalScore))
            }
            
            // Program info
            VStack(alignment: .leading, spacing: 2) {
                Text(HospitalNameFormatter.format(program.hospital.isEmpty ? program.name : program.hospital))
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                
                HStack(spacing: 5) {
                    if !program.city.isEmpty && !program.state.isEmpty {
                        Text("\(program.city), \(program.state)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                        Text(String(format: "%.1f", program.finalScore))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(scoreColor(program.finalScore))
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.3))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 2)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .blue }
        if score >= 40 { return .orange }
        return .red
    }
}

struct UpcomingInterviewRow: View {
    let program: Program
    
    var body: some View {
        HStack(spacing: 10) {
            // Calendar icon - smaller
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
            }
            
            // Program info
            VStack(alignment: .leading, spacing: 2) {
                Text(HospitalNameFormatter.format(program.hospital.isEmpty ? program.name : program.hospital))
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                
                if let interviewDate = program.interviewDate {
                    Text(interviewDate, style: .date)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.3))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 2)
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

struct AnalyticsStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(height: 16)
            
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.08))
        )
    }
}

#Preview {
    DashboardView()
        .environmentObject(DataManager.shared)
}

