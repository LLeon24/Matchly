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
    /// Matchly brand typeface (Arial), with system fallback when Arial is unavailable.
    static func arial(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Font {
        if design != .default {
            return .system(size: size, weight: weight, design: design)
        }

        let uiWeight = UIFont.Weight(arialWeight: weight)
        if let descriptor = UIFont(name: "Arial", size: size)?.fontDescriptor
            .addingAttributes([
                .traits: [UIFontDescriptor.TraitKey.weight: uiWeight]
            ]),
           UIFont(descriptor: descriptor, size: size).fontName.lowercased().contains("arial") {
            return Font(UIFont(descriptor: descriptor, size: size))
        }

        if let base = UIFont(name: "Arial", size: size) {
            return Font(base)
        }

        return .system(size: size, weight: weight, design: .default)
    }
}

private extension UIFont.Weight {
    init(arialWeight: Font.Weight) {
        switch arialWeight {
        case .ultraLight: self = .ultraLight
        case .thin: self = .thin
        case .light: self = .light
        case .regular: self = .regular
        case .medium: self = .medium
        case .semibold: self = .semibold
        case .bold: self = .bold
        case .heavy: self = .heavy
        case .black: self = .black
        default: self = .regular
        }
    }
}

extension View {
    /// Applies Matchly's default Arial environment font.
    func arialFont() -> some View {
        environment(\.font, Font.arial(size: 17, weight: .regular))
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
    var sectionTabFont: CGFloat { self == .compactVertical ? 13 : 16 }
    var sectionTabSpacing: CGFloat { self == .compactVertical ? 6 : 9 }
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
    var dashboardSectionSpacing: CGFloat { self == .compactVertical ? 10 : 14 }
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

