//
//  AppGuideView.swift
//  Matchly
//
//  Reusable walkthrough of Matchly's main areas — used in onboarding and Settings.
//

import SwiftUI

struct AppGuidePage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let tint: Color
}

enum AppGuidePages {
    static let all: [AppGuidePage] = [
        AppGuidePage(
            icon: "house.fill",
            title: "Dashboard",
            description: "Your home base: upcoming interviews, signals, programs needing review, and quick links to what matters most during match season.",
            tint: AppColors.primaryBlue
        ),
        AppGuidePage(
            icon: "list.bullet",
            title: "My Programs",
            description: "Add programs from search, rate each one with the questionnaire, and track signals, red flags, and interview details in one place.",
            tint: AppColors.accentGreen
        ),
        AppGuidePage(
            icon: "chart.bar.fill",
            title: "Rank List",
            description: "Build your personal NRMP rank list from scored programs. Export when you're ready and reorder anytime as you learn more.",
            tint: AppColors.accentPink
        ),
        AppGuidePage(
            icon: "map.fill",
            title: "Map",
            description: "See programs geographically, compare distances, and visualize where you and your partner might end up.",
            tint: AppColors.accentTeal
        ),
        AppGuidePage(
            icon: "heart.fill",
            title: "Couple Match",
            description: "Link with your partner to chat, share rank lists, and generate a suggested couples rank list using NRMP-style pairing rules.",
            tint: .pink
        ),
        AppGuidePage(
            icon: "gearshape.fill",
            title: "Settings",
            description: "Adjust specialties, questionnaire weights, calendar sync, dashboard layout, and couples preferences anytime.",
            tint: AppColors.accentPurple
        )
    ]
}

struct AppGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var showsNavigationChrome: Bool = false
    var onFinish: (() -> Void)?

    @State private var pageIndex = 0

    private var isLastPage: Bool {
        pageIndex >= AppGuidePages.all.count - 1
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $pageIndex) {
                ForEach(Array(AppGuidePages.all.enumerated()), id: \.offset) { index, page in
                    guidePage(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            if onFinish != nil {
                Button(action: advance) {
                    Text(isLastPage ? "Continue Setup" : "Next")
                        .font(.arial(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.glassProminent)
                .tint(AppColors.primaryBlue)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            } else {
                Button(action: { dismiss() }) {
                    Text("Done")
                        .font(.arial(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.glassProminent)
                .tint(AppColors.primaryBlue)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(showsNavigationChrome ? "How to Use Matchly" : "")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func guidePage(_ page: AppGuidePage) -> some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.tint.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: page.icon)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(page.tint)
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.arial(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.arial(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
            Spacer()
        }
        .padding(.top, 24)
    }

    private func advance() {
        if isLastPage {
            onFinish?()
        } else {
            withAnimation {
                pageIndex += 1
            }
        }
    }
}

#Preview {
    AppGuideView(onFinish: {})
}
