//
//  AppFeatureTourOverlay.swift
//  Matchly
//
//  Interactive coach-mark tour with spotlight highlights and sketch-style arrows.
//

import SwiftUI

enum FeatureTourAnchorID {
    static let dashboardTab = "tour.tab.dashboard"
    static let programsTab = "tour.tab.programs"
    static let interviewsTab = "tour.tab.interviews"
    static let rankListTab = "tour.tab.rankList"
    static let coupleTab = "tour.tab.couple"
    static let mapTab = "tour.tab.map"
    static let settingsTab = "tour.tab.settings"
}

struct FeatureTourAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct FeatureTourStep: Identifiable {
    let id: String
    let tabIndex: Int
    let anchorID: String?
    let title: String
    let message: String
    let placesBubbleAboveSpotlight: Bool

    var isIntroOrOutro: Bool { anchorID == nil }
}

enum AppFeatureTourSteps {
    static func steps(isCoupleLinked: Bool) -> [FeatureTourStep] {
        let showCouple = FeatureFlags.couplesMatchEnabled && isCoupleLinked

        var steps: [FeatureTourStep] = [
            FeatureTourStep(
                id: "intro",
                tabIndex: MainTabLayout.dashboardIndex,
                anchorID: nil,
                title: "Welcome to your tour",
                message: "We'll point at the real tabs and explain what each area does. Tap Next to follow along — or Skip anytime.",
                placesBubbleAboveSpotlight: true
            ),
            FeatureTourStep(
                id: "dashboard",
                tabIndex: MainTabLayout.dashboardIndex,
                anchorID: FeatureTourAnchorID.dashboardTab,
                title: "Dashboard",
                message: "Your home base during match season: interview season progress, signals, programs needing review, and quick next steps.",
                placesBubbleAboveSpotlight: true
            ),
            FeatureTourStep(
                id: "programs",
                tabIndex: MainTabLayout.programsIndex,
                anchorID: FeatureTourAnchorID.programsTab,
                title: "My Programs",
                message: "Search and add programs, complete questionnaires after interviews, and open Interview Prep to build question lists for each visit.",
                placesBubbleAboveSpotlight: true
            ),
            FeatureTourStep(
                id: "interviews",
                tabIndex: MainTabLayout.interviewsIndex,
                anchorID: FeatureTourAnchorID.interviewsTab,
                title: "Interviews",
                message: "See upcoming and past interviews in a list or calendar, set missing dates, sync to your device calendar, and use Interview Prep for each program.",
                placesBubbleAboveSpotlight: true
            ),
            FeatureTourStep(
                id: "rankList",
                tabIndex: MainTabLayout.rankListIndex(isCoupleLinked: showCouple),
                anchorID: FeatureTourAnchorID.rankListTab,
                title: "Rank List",
                message: "Build your personal NRMP rank list from scored programs. Reorder as you learn more and export when you're ready.",
                placesBubbleAboveSpotlight: true
            )
        ]

        if showCouple {
            steps.append(
                FeatureTourStep(
                    id: "couple",
                    tabIndex: MainTabLayout.coupleHubIndex(isCoupleLinked: true) ?? 4,
                    anchorID: FeatureTourAnchorID.coupleTab,
                    title: "Couple Match",
                    message: "Chat with your partner, share rank lists, and generate a suggested couples rank list together.",
                    placesBubbleAboveSpotlight: true
                )
            )
        }

        if FeatureFlags.programsMapEnabled, let mapIndex = MainTabLayout.mapIndex(isCoupleLinked: showCouple) {
            steps.append(
                FeatureTourStep(
                    id: "map",
                    tabIndex: mapIndex,
                    anchorID: FeatureTourAnchorID.mapTab,
                    title: "Map",
                    message: showCouple
                        ? "See programs geographically and compare distances — helpful for geography and couples planning."
                        : "See programs geographically and compare distances as you plan where you want to train.",
                    placesBubbleAboveSpotlight: true
                )
            )
        }

        let settingsIndex = MainTabLayout.settingsIndex(isCoupleLinked: showCouple)
        steps.append(contentsOf: [
            FeatureTourStep(
                id: "settings",
                tabIndex: settingsIndex,
                anchorID: FeatureTourAnchorID.settingsTab,
                title: "Settings",
                message: showCouple
                    ? "Adjust specialties, questionnaire sections, dashboard layout, calendar sync, and couples preferences."
                    : "Adjust specialties, questionnaire sections, dashboard layout, and calendar sync.",
                placesBubbleAboveSpotlight: true
            ),
            FeatureTourStep(
                id: "outro",
                tabIndex: MainTabLayout.dashboardIndex,
                anchorID: nil,
                title: "You're ready to go",
                message: "Replay this tour anytime from Settings → Replay Guided Tour. Good luck this match season!",
                placesBubbleAboveSpotlight: true
            )
        ])

        return steps
    }

    /// Shown when couples matching is activated after the main app tour was already completed.
    static func coupleMatchSteps() -> [FeatureTourStep] {
        guard FeatureFlags.couplesMatchEnabled else { return [] }
        let coupleIndex = MainTabLayout.coupleHubIndex(isCoupleLinked: true) ?? 4
        return [
            FeatureTourStep(
                id: "couple-intro",
                tabIndex: coupleIndex,
                anchorID: nil,
                title: "Couple Match is on",
                message: "You're linked with your partner. We'll highlight the new Couple tab where you coordinate rank lists together.",
                placesBubbleAboveSpotlight: true
            ),
            FeatureTourStep(
                id: "couple",
                tabIndex: coupleIndex,
                anchorID: FeatureTourAnchorID.coupleTab,
                title: "Couple Match",
                message: "Chat with your partner, share rank lists, and generate a suggested couples rank list together.",
                placesBubbleAboveSpotlight: true
            ),
            FeatureTourStep(
                id: "couple-outro",
                tabIndex: coupleIndex,
                anchorID: nil,
                title: "Happy matching together",
                message: "Open Couple Match anytime to compare lists and stay aligned during match season.",
                placesBubbleAboveSpotlight: true
            )
        ]
    }
}

struct AppFeatureTourOverlay: View {
    let steps: [FeatureTourStep]
    let anchorRects: [String: CGRect]
    @Binding var stepIndex: Int
    @Binding var selectedTab: Int
    var onFinish: () -> Void
    var onSkip: () -> Void

    private var currentStep: FeatureTourStep {
        steps[min(max(stepIndex, 0), steps.count - 1)]
    }

    private var isLastStep: Bool {
        stepIndex >= steps.count - 1
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ZStack {
                    Color.black.opacity(0.58)
                        .ignoresSafeArea()

                    if let anchorID = currentStep.anchorID {
                        spotlightCutout(for: anchorID, in: proxy)
                    }
                }
                .compositingGroup()

                tourContent(in: proxy)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            applyStep(currentStep)
        }
        .onChange(of: stepIndex) { _, _ in
            applyStep(currentStep)
        }
    }

    @ViewBuilder
    private func spotlightCutout(for anchorID: String, in proxy: GeometryProxy) -> some View {
        if let rect = anchorRects[anchorID] {
            let padded = rect.insetBy(dx: -10, dy: -8)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .frame(width: padded.width, height: padded.height)
                .position(x: padded.midX, y: padded.midY)
                .blendMode(.destinationOut)
        }
    }

    @ViewBuilder
    private func tourContent(in proxy: GeometryProxy) -> some View {
        if currentStep.isIntroOrOutro {
            centeredCard
                .padding(.horizontal, 28)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        } else if let anchorID = currentStep.anchorID, let rect = anchorRects[anchorID] {
            anchoredCard(spotlightRect: rect, in: proxy.size)
        }
    }

    private var centeredCard: some View {
        VStack(spacing: 18) {
            stepCard(showProgress: true)

            HStack(spacing: 12) {
                Button("Skip Tour", action: onSkip)
                    .font(.arial(size: 15, weight: .medium))
                    .foregroundColor(Color(white: 0.35))

                Spacer()

                Button(action: advance) {
                    Text(isLastStep ? "Start Using Matchly" : "Next")
                        .font(.arial(size: 16, weight: .semibold))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(AppColors.primaryBlue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(22)
        .background(tourCardBackground(cornerRadius: 22))
    }

    private func anchoredCard(spotlightRect: CGRect, in size: CGSize) -> some View {
        let bubbleMaxWidth = min(size.width - 40, 340)
        let bubbleCenterY = max(120, spotlightRect.minY - 118)
        let bubbleCenter = CGPoint(x: size.width / 2, y: bubbleCenterY)

        return ZStack {
            SketchTourArrow(from: CGPoint(x: bubbleCenter.x, y: bubbleCenter.y + 58), to: CGPoint(x: spotlightRect.midX, y: spotlightRect.minY - 6))
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)

            VStack(spacing: 14) {
                stepCard(showProgress: true)

                HStack(spacing: 12) {
                    Button("Skip", action: onSkip)
                        .font(.arial(size: 14, weight: .medium))
                        .foregroundColor(Color(white: 0.35))

                    Spacer()

                    Button(action: advance) {
                        Text(isLastStep ? "Done" : "Next")
                            .font(.arial(size: 15, weight: .semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(AppColors.primaryBlue)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
            }
            .frame(maxWidth: bubbleMaxWidth)
            .padding(18)
            .background(tourCardBackground(cornerRadius: 20))
            .position(bubbleCenter)
        }
    }

    private func tourCardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white)
            .shadow(color: .black.opacity(0.32), radius: 18, y: 8)
    }

    @ViewBuilder
    private func stepCard(showProgress: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if showProgress {
                HStack(spacing: 6) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, _ in
                        Capsule()
                            .fill(index <= stepIndex ? AppColors.primaryBlue : Color(white: 0.82))
                            .frame(width: index == stepIndex ? 18 : 8, height: 4)
                    }
                }
            }

            Text(currentStep.title)
                .font(.arial(size: 22, weight: .bold))
                .foregroundColor(.black)

            Text(currentStep.message)
                .font(.arial(size: 16))
                .foregroundColor(Color(white: 0.22))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func advance() {
        if isLastStep {
            onFinish()
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                stepIndex += 1
            }
        }
    }

    private func applyStep(_ step: FeatureTourStep) {
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedTab = step.tabIndex
        }
    }
}

private struct SketchTourArrow: Shape {
    let from: CGPoint
    let to: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)

        let control = CGPoint(
            x: from.x + (to.x - from.x) * 0.35,
            y: from.y + (to.y - from.y) * 0.55
        )
        path.addQuadCurve(to: to, control: control)

        let angle = atan2(to.y - control.y, to.x - control.x)
        let headLength: CGFloat = 14
        let headAngle: CGFloat = .pi / 7

        path.move(to: to)
        path.addLine(to: CGPoint(
            x: to.x - headLength * cos(angle - headAngle),
            y: to.y - headLength * sin(angle - headAngle)
        ))
        path.move(to: to)
        path.addLine(to: CGPoint(
            x: to.x - headLength * cos(angle + headAngle),
            y: to.y - headLength * sin(angle + headAngle)
        ))

        return path
    }
}
