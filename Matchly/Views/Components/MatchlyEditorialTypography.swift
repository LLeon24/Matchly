//
//  MatchlyEditorialTypography.swift
//  Matchly
//
//  Two tiers:
//  • Brand — splash-aligned (light weight, tracking, hairlines). Fixed copy only.
//  • Functional — standard sentence/title case with scaling for dynamic text.
//

import SwiftUI

enum MatchlyEditorialTypography {
    // Brand
    static let pageTitleSize: CGFloat = 24
    static let pageTitleKerning: CGFloat = 2

    static let sectionHeaderSize: CGFloat = 11
    static let sectionHeaderKerning: CGFloat = 2.2

    static let bodyLightSize: CGFloat = 15
    static let captionSize: CGFloat = 12

    // Functional
    static let functionalSubtitleSize: CGFloat = 14
    static let functionalHeadlineSize: CGFloat = 17

    static let heroTitleSize: CGFloat = 24
    static let greetingKerning: CGFloat = 0.6

    /// Tracking for light display titles — scales slightly with point size.
    static func heroTitleKerning(for size: CGFloat) -> CGFloat {
        size <= 17 ? 0.5 : (size <= 20 ? 0.6 : 0.8)
    }

    static func displayFont(size: CGFloat) -> Font {
        .arial(size: size, weight: .light)
    }

    static func headlineFont(size: CGFloat) -> Font {
        .arial(size: size, weight: .regular)
    }
}

// MARK: - Brand (splash-aligned)

/// List-tab page title — semibold, title case.
struct MatchlyPageTitleText: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.arial(size: MatchlyEditorialTypography.pageTitleSize, weight: .semibold))
            .foregroundStyle(AppColors.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }
}

/// Settings / form section label — small tracked caps.
struct MatchlySectionHeaderText: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.arial(size: MatchlyEditorialTypography.sectionHeaderSize, weight: .regular))
            .foregroundStyle(AppColors.secondaryText)
            .kerning(MatchlyEditorialTypography.sectionHeaderKerning)
    }
}

struct MatchlyEditorialBody: View {
    let text: String
    var alignment: TextAlignment = .center

    var body: some View {
        Text(text)
            .font(.arial(size: MatchlyEditorialTypography.bodyLightSize, weight: .light))
            .foregroundStyle(AppColors.secondaryText)
            .multilineTextAlignment(alignment)
            .lineSpacing(3)
    }
}

/// Page title + hairline for Settings, Programs, Rank List, etc.
struct MatchlyEditorialPageHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                MatchlyPageTitleText(title: title)
                Spacer(minLength: 8)
                trailing()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            MatchlyBrandHairline(fullWidth: true)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
        }
    }
}

extension MatchlyEditorialPageHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

/// Dashboard greeting — semibold for clear hierarchy above the subtitle.
struct MatchlyDashboardGreeting: View {
    let text: String
    var size: CGFloat

    var body: some View {
        Group {
            if let split = greetingSplit {
                VStack(alignment: .leading, spacing: 2) {
                    greetingLine(split.lead, lineLimit: 1)
                    greetingLine(split.trail, lineLimit: 2)
                }
            } else {
                greetingLine(text, lineLimit: 2)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Splits "Good afternoon, Name!" so the salutation and name can wrap independently.
    private var greetingSplit: (lead: String, trail: String)? {
        guard let comma = text.firstIndex(of: ",") else { return nil }
        let lead = String(text[...comma])
        let trailStart = text.index(after: comma)
        let trail = String(text[trailStart...]).trimmingCharacters(in: .whitespaces)
        guard !trail.isEmpty else { return nil }
        return (lead, trail)
    }

    private func greetingLine(_ string: String, lineLimit: Int) -> some View {
        Text(string)
            .font(.arial(size: size, weight: .bold))
            .foregroundStyle(AppColors.primaryText)
            .kerning(MatchlyEditorialTypography.greetingKerning)
            .multilineTextAlignment(.leading)
            .lineLimit(lineLimit)
            .minimumScaleFactor(0.75)
            .allowsTightening(true)
    }
}

/// Dashboard hero titles ("Your Interview Season") — same light voice as the greeting.
struct MatchlyHeroTitle: View {
    let title: String
    var size: CGFloat = MatchlyEditorialTypography.heroTitleSize
    var alignment: TextAlignment = .center
    var lineLimit: Int = 2

    var body: some View {
        Text(title)
            .font(MatchlyEditorialTypography.displayFont(size: size))
            .foregroundStyle(AppColors.primaryText)
            .kerning(MatchlyEditorialTypography.heroTitleKerning(for: size))
            .multilineTextAlignment(alignment)
            .lineLimit(lineLimit)
            .minimumScaleFactor(0.85)
    }
}

// MARK: - Functional (dynamic copy — scales to fit)

/// Greeting lines, motivational quotes, dates — never forced to all caps.
struct MatchlyFunctionalSubtitle: View {
    let text: String
    var size: CGFloat = MatchlyEditorialTypography.functionalSubtitleSize

    var body: some View {
        Text(text)
            .font(.arial(size: size, weight: .medium))
            .foregroundStyle(AppColors.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .allowsTightening(true)
    }
}

/// In-content section titles on dashboard cards.
struct MatchlyContentSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.arial(size: MatchlyEditorialTypography.functionalHeadlineSize, weight: .regular))
            .foregroundStyle(AppColors.primaryText)
            .kerning(0.4)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 28) {
        MatchlyEditorialPageHeader(title: "Settings")
        MatchlySectionHeaderText(title: "Profile")
        MatchlyDashboardGreeting(text: "Good afternoon, Christopher Alexander Montgomery!", size: 24)
        MatchlyFunctionalSubtitle(text: "Believe in yourself and your journey!")
        MatchlyHeroTitle(title: "Your Interview Season", alignment: .leading)
        MatchlyContentSectionTitle(title: "Key Metrics")
        MatchlyEditorialBody(text: "Add your first residency program to begin building your rank list.")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .appCanvasBackground()
}
