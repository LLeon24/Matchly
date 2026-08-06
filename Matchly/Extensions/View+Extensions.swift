//
//  View+Extensions.swift
//  Matchly
//
//  Created on 12/6/25.
//

import SwiftUI
import UIKit

// MARK: - Arial font

extension Font {
    /// App-wide Arial helper used by Matchly views.
    /// Falls back to the system font when Arial is unavailable.
    static func arial(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Font {
        if design != .default {
            return .system(size: size, weight: weight, design: design)
        }

        let uiWeight = uiFontWeight(for: weight)
        if let fontName = arialPostScriptName(for: uiWeight),
           UIFont(name: fontName, size: size) != nil {
            return .custom(fontName, size: size)
        }

        if let arialBase = UIFont(name: "ArialMT", size: size)
            ?? UIFont(name: "Arial", size: size) {
            let descriptor = arialBase.fontDescriptor.addingAttributes([
                .traits: [UIFontDescriptor.TraitKey.weight: uiWeight]
            ])
            return Font(UIFont(descriptor: descriptor, size: size))
        }

        return .system(size: size, weight: weight, design: .default)
    }

    private static func uiFontWeight(for weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }

    private static func arialPostScriptName(for weight: UIFont.Weight) -> String? {
        switch weight {
        case .bold, .heavy, .black, .semibold:
            return "Arial-BoldMT"
        case .regular, .medium, .light, .thin, .ultraLight:
            return "ArialMT"
        default:
            return "ArialMT"
        }
    }
}

extension View {
    /// Applies Matchly's default Arial environment font.
    func arialFont() -> some View {
        environment(\.font, Font.arial(size: 17, weight: .regular))
    }
}

// MARK: - Form section headers

/// Black, left-aligned section title for Settings and Backup & Sync forms.
/// Uses 17pt bold so titles match (not shrink below) primary form row text.
struct MatchlyFormSectionHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.arial(size: 17, weight: .bold))
                .foregroundStyle(Color.black)
                .textCase(nil)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Counteract Form's default section-header inset so titles sit flush
        // with the leading edge of the grouped card below.
        .padding(.leading, -16)
    }
}

/// Colored specialty label for grouped program lists (My Programs, Rank List).
struct MatchlySpecialtySectionHeader: View {
    let specialty: String
    var showFullName: Bool = true

    var body: some View {
        let color = SpecialtyFormatter.color(for: specialty)
        HStack(spacing: 6) {
            Image(systemName: "stethoscope")
                .font(.arial(size: 12))
                .foregroundColor(color)
            Text(
                showFullName
                    ? SpecialtyFormatter.displayNameWithAbbreviation(specialty)
                    : SpecialtyFormatter.abbreviation(for: specialty)
            )
            .font(.arial(size: 13, weight: .semibold))
            .foregroundColor(color)
        }
    }
}

// MARK: - Device layout

enum MatchlyDeviceLayout {
    static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    /// Max content width on iPad; phones stay edge-to-edge unless capped elsewhere.
    static var readableContentMaxWidth: CGFloat { isPad ? 1180 : 960 }
}

// MARK: - Adaptive layout (landscape / compact height)

enum MatchlyLayoutStyle: Equatable {
    case standard
    case compactVertical

    var heroRingSize: CGFloat { self == .compactVertical ? 118 : 210 }
    var heroRingLineWidth: CGFloat { self == .compactVertical ? 10 : 16 }
    var heroBigNumberFont: CGFloat { self == .compactVertical ? 42 : 80 }
    var heroUnitFont: CGFloat { self == .compactVertical ? 11 : 13 }
    var heroTitleFont: CGFloat { self == .compactVertical ? 17 : 24 }
    var heroSubtitleFont: CGFloat { self == .compactVertical ? 12 : 14 }
    var heroCaptionFont: CGFloat { self == .compactVertical ? 11 : 12 }
    var heroStatValueFont: CGFloat { self == .compactVertical ? 16 : 20 }
    var heroStatLabelFont: CGFloat { self == .compactVertical ? 10 : 11 }
    var numberHeroIconSize: CGFloat { self == .compactVertical ? 56 : 76 }
    var numberHeroIconFont: CGFloat { self == .compactVertical ? 24 : 34 }
    var sectionTabFont: CGFloat { self == .compactVertical ? 14 : 17 }
    var sectionTabIconFont: CGFloat { self == .compactVertical ? 15 : 18 }
    var sectionTabSpacing: CGFloat { self == .compactVertical ? 5 : 7 }
    var headerGreetingFont: CGFloat { self == .compactVertical ? 18 : 24 }
    var headerSubtitleFont: CGFloat { self == .compactVertical ? 12 : 14 }
    var headerAvatarSize: CGFloat { self == .compactVertical ? 36 : 48 }
    var headerCustomizeButtonSize: CGFloat { self == .compactVertical ? 34 : 40 }
    var headerVerticalPadding: CGFloat { self == .compactVertical ? 8 : 16 }
    var cardVerticalPadding: CGFloat { self == .compactVertical ? 12 : 20 }
    var cardHorizontalPadding: CGFloat { self == .compactVertical ? 14 : 20 }
    var pageBottomInset: CGFloat { self == .compactVertical ? 12 : 16 }
    /// Space to keep scroll content above the floating tab bar.
    var tabBarScrollClearance: CGFloat { self == .compactVertical ? 84 : 110 }
    var dashboardSectionSpacing: CGFloat { self == .compactVertical ? 12 : 16 }
    var tabBarIconFont: CGFloat { self == .compactVertical ? 18 : 22 }
    var tabBarTitleFont: CGFloat { self == .compactVertical ? 9 : 10 }
    var tabBarVerticalPadding: CGFloat { self == .compactVertical ? 6 : 10 }
}

private struct MatchlyLayoutStyleKey: EnvironmentKey {
    static let defaultValue: MatchlyLayoutStyle = .standard
}

extension EnvironmentValues {
    var matchlyLayout: MatchlyLayoutStyle {
        get { self[MatchlyLayoutStyleKey.self] }
        set { self[MatchlyLayoutStyleKey.self] = newValue }
    }
}

private struct MatchlyAdaptiveLayoutModifier: ViewModifier {
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    func body(content: Content) -> some View {
        content
            .environment(
                \.matchlyLayout,
                verticalSizeClass == .compact ? .compactVertical : .standard
            )
    }
}

extension View {
    /// Applies compact sizing when vertical space is limited (e.g. iPhone landscape).
    func matchlyAdaptiveLayout() -> some View {
        modifier(MatchlyAdaptiveLayoutModifier())
    }
}

// MARK: - Navigation (iPad-safe)

/// Single-column navigation on all devices. Prevents the blank detail pane that
/// appears when `NavigationView` uses the iPad split style in landscape.
struct MatchlyNavigationView<Content: View>: View {
    @ViewBuilder private var content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        NavigationView {
            content()
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Liquid Glass (iOS 26)

extension View {
    /// Primary elevated surface — dashboard cards, panels, map cards.
    func glassCardStyle(cornerRadius: CGFloat = 24) -> some View {
        modifier(GlassCardStyle(cornerRadius: cornerRadius))
    }

    /// Compact inset panel — search rows, form sections, list tiles.
    func glassPanelStyle(cornerRadius: CGFloat = 16) -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }

    /// Circular icon control floating over content.
    func glassCircleButtonStyle(interactive: Bool = true) -> some View {
        let style: Glass = interactive ? .regular.interactive() : .regular
        return glassEffect(style, in: .circle)
    }

    /// Capsule chip — filters, tags, segmented pills.
    func glassChipStyle(tint: Color? = nil, interactive: Bool = true) -> some View {
        let base: Glass = interactive ? .regular.interactive() : .regular
        let style: Glass = {
            if let tint {
                return .regular.tint(tint.opacity(0.18)).interactive()
            }
            return base
        }()
        return glassEffect(style, in: .capsule)
    }

    /// Full-screen app canvas so glass chrome has content to refract.
    func appCanvasBackground() -> some View {
        background(AppColors.dashboardCanvas.ignoresSafeArea())
    }

    /// Ensures tab roots and empty states expand to fill the screen in every orientation.
    func matchlyRootContentFrame() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Centers readable-width content on iPad / wide landscape while still filling the canvas.
    func matchlyReadableWidth(_ maxWidth: CGFloat? = nil) -> some View {
        modifier(MatchlyReadableWidthModifier(maxWidth: maxWidth))
    }

    /// Full-height sheet on iPhone; page-sized sheet on iPad instead of the narrow centered card.
    func matchlyExpandedSheet() -> some View {
        presentationDetents([.large])
            .presentationSizing(.page)
            .presentationDragIndicator(.visible)
    }

    /// Ensures scrollable tab content can scroll fully above the floating tab bar.
    func matchlyScrollTabBarClearance() -> some View {
        modifier(MatchlyScrollTabBarClearanceModifier())
    }
}

private struct MatchlyScrollTabBarClearanceModifier: ViewModifier {
    @Environment(\.matchlyLayout) private var layout

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: layout.tabBarScrollClearance)
                .accessibilityHidden(true)
        }
    }
}

private struct MatchlyReadableWidthModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let maxWidth: CGFloat?

    private var resolvedMaxWidth: CGFloat {
        maxWidth ?? MatchlyDeviceLayout.readableContentMaxWidth
    }

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: horizontalSizeClass == .regular ? resolvedMaxWidth : .infinity)
            .frame(maxWidth: .infinity)
    }
}

struct GlassCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 24
    @Environment(\.matchlyLayout) private var layout

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, layout.cardHorizontalPadding)
            .padding(.vertical, layout.cardVerticalPadding)
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

// MARK: - Dashboard Card Style (alias — uses native Liquid Glass)
extension View {
    func dashboardCardStyle() -> some View {
        glassCardStyle(cornerRadius: 24)
    }
}

// Legacy name kept for any call sites; routes to glass card.
struct DashboardCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.modifier(GlassCardStyle(cornerRadius: 24))
    }
}

// MARK: - Keyboard Dismissal
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Corner Radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - List page toolbar policy

/// Shared rule for list-style tabs: hide Sort / Add / Edit toolbar chrome on empty
/// states; show it once there is content. Use this for new list pages too.
enum MatchlyListPageToolbar {
    static func showsActions(hasContent: Bool) -> Bool { hasContent }
}

/// Capsule chip label for sort menus — matches Rank List filter styling.
struct MatchlyToolbarSortChipLabel: View {
    let valueLabel: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.arial(size: 11, weight: .semibold))
            Text("Sort: \(valueLabel)")
                .font(.arial(size: 12, weight: .medium))
            Image(systemName: "chevron.down")
                .font(.arial(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

/// Primary add action for list page toolbars.
struct MatchlyToolbarAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.arial(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .glassEffect(.regular.tint(AppColors.primaryBlue.opacity(0.35)).interactive(), in: .circle)
        }
        .accessibilityLabel("Add")
    }
}

