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

extension AppearanceMode {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .auto: return nil
        case .light: return .light
        case .dark: return .dark
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

/// Small tracked section labels for Settings and grouped forms.
struct MatchlyFormSectionHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: 0) {
            MatchlySectionHeaderText(title: title)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, -16)
        .padding(.bottom, 2)
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
            .kerning(0.3)
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

    var heroRingSize: CGFloat { self == .compactVertical ? 82 : 144 }
    var heroRingLineWidth: CGFloat { self == .compactVertical ? 8 : 11 }
    var heroBigNumberFont: CGFloat { self == .compactVertical ? 30 : 52 }
    var heroUnitFont: CGFloat { self == .compactVertical ? 10 : 12 }
    var heroTitleFont: CGFloat { self == .compactVertical ? 17 : 24 }
    /// Section label under the progress ring (e.g. “Your Interview Season”).
    var heroSectionTitleFont: CGFloat { self == .compactVertical ? 15 : 18 }
    var heroSubtitleFont: CGFloat { self == .compactVertical ? 12 : 14 }
    var heroCaptionFont: CGFloat { self == .compactVertical ? 11 : 12 }
    var heroStatValueFont: CGFloat { self == .compactVertical ? 16 : 20 }
    var heroStatLabelFont: CGFloat { self == .compactVertical ? 10 : 11 }
    var numberHeroIconSize: CGFloat { self == .compactVertical ? 56 : 76 }
    var numberHeroIconFont: CGFloat { self == .compactVertical ? 24 : 34 }
    var sectionTabFont: CGFloat { self == .compactVertical ? 15 : 18 }
    var sectionTabIconFont: CGFloat { self == .compactVertical ? 16 : 19 }
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

/// Single-column navigation on all devices. Uses `NavigationStack` so pushed
/// destinations work with modern `navigationDestination` APIs.
struct MatchlyNavigationView<Content: View>: View {
    @ViewBuilder private var content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        NavigationStack {
            content()
        }
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
        modifier(GlassPanelStyleModifier(cornerRadius: cornerRadius, nestedInsideGlass: false))
    }

    /// Inset panel meant to sit inside an outer `.glassEffect` container.
    /// iOS 26 renders nested Liquid Glass as a muddy gray box and can widen layout;
    /// iOS 27+ keeps the glass inset look users expect.
    func nestedGlassPanelStyle(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassPanelStyleModifier(cornerRadius: cornerRadius, nestedInsideGlass: true))
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

private struct GlassPanelStyleModifier: ViewModifier {
    let cornerRadius: CGFloat
    let nestedInsideGlass: Bool

    func body(content: Content) -> some View {
        let padded = content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)

        if nestedInsideGlass {
            if #available(iOS 27, *) {
                padded.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            } else {
                padded
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(AppColors.dashboardCard)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        } else {
            padded.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        }
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

    /// Floating Done bar above the keyboard. Works on pushed navigation destinations where
    /// `.toolbar(placement: .keyboard)` does not.
    func matchlyKeyboardDismissOverlay() -> some View {
        modifier(MatchlyKeyboardDismissOverlayModifier())
    }

    /// Adds a keyboard accessory bar with a hide-keyboard control.
    func matchlyKeyboardDismissToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    hideKeyboard()
                }
                .font(.arial(size: 15, weight: .semibold))
            }
        }
    }
}

private struct MatchlyKeyboardDismissOverlayModifier: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if keyboardHeight > 0 {
                    keyboardAccessoryBar
                        .padding(.bottom, keyboardHeight)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1000)
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                let inset = max(0, frame.height)
                withAnimation(keyboardAnimation(from: notification)) {
                    keyboardHeight = inset
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
                withAnimation(keyboardAnimation(from: notification)) {
                    keyboardHeight = 0
                }
            }
    }

    private var keyboardAccessoryBar: some View {
        HStack(spacing: 16) {
            Spacer()
            Button {
                hideKeyboard()
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 17, weight: .medium))
            }
            .accessibilityLabel("Hide keyboard")

            Button("Done") {
                hideKeyboard()
            }
            .font(.arial(size: 17, weight: .semibold))
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func keyboardAnimation(from notification: Notification) -> Animation {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        return .easeOut(duration: duration)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
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

/// List-tab page header with luxury title + hairline.
struct MatchlyListPageTitleRow<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        MatchlyEditorialPageHeader(title: title, trailing: trailing)
    }
}

extension MatchlyListPageTitleRow where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

/// Flat capsule chip for filter/sort menus — one layer, no nested glass.
struct MatchlyFilterChipLabel: View {
    let icon: String
    var iconColor: Color = .secondary
    let text: String
    var isActive: Bool = false
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.arial(size: 11, weight: .semibold))
                .foregroundColor(isActive ? AppColors.primaryBlue : iconColor)
            Text(text)
                .font(.arial(size: 12, weight: .medium))
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.arial(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isActive ? AppColors.primaryBlue.opacity(0.1) : Color(.tertiarySystemFill))
        )
    }
}

/// Tinted capsule tabs for All / Completed / Incomplete-style filters.
struct MatchlyColoredTabOption<ID: Hashable>: Identifiable {
    var id: ID { value }
    let value: ID
    let title: String
    let tint: Color
    var count: Int?

    var displayTitle: String {
        if let count {
            return "\(title) (\(count))"
        }
        return title
    }
}

struct MatchlyColoredTabBar<ID: Hashable>: View {
    let options: [MatchlyColoredTabOption<ID>]
    @Binding var selection: ID

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options) { option in
                tabButton(for: option)
            }
        }
        .padding(.horizontal, 16)
    }

    private func tabButton(for option: MatchlyColoredTabOption<ID>) -> some View {
        let isSelected = selection == option.value

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = option.value
            }
        } label: {
            Text(option.displayTitle)
                .font(.arial(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? option.tint : option.tint.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule()
                        .fill(option.tint.opacity(isSelected ? 0.2 : 0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(option.tint.opacity(isSelected ? 0.45 : 0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Capsule chip label for sort menus in the navigation toolbar — no inner bubble;
/// iOS already wraps toolbar items in its own chrome.
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
    }
}

/// Colored capsule for Export PDF on list title rows — obvious without nested toolbar chrome.
struct MatchlyToolbarExportPDFButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "doc.richtext")
                    .font(.arial(size: 12, weight: .semibold))
                Text("Export PDF")
                    .font(.arial(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(AppColors.primaryBlue))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Export rank list as PDF")
    }
}

/// Colored capsule for adding interview dates on the Interviews tab title row.
struct MatchlyToolbarAddInterviewDateButton: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "calendar.badge.plus")
                .font(.arial(size: 12, weight: .semibold))
            Text("Add Date")
                .font(.arial(size: 13, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(AppColors.accentTeal))
        .accessibilityLabel("Add interview dates")
    }
}

/// Specialty pill shared by program and interview list rows.
struct MatchlyProgramSpecialtyBadge: View {
    let specialty: String
    var useFullName: Bool = false

    var body: some View {
        let specialtyColor = SpecialtyFormatter.color(for: specialty)
        let label = useFullName ? specialty : SpecialtyFormatter.abbreviation(for: specialty)

        HStack(spacing: 3) {
            Image(systemName: "stethoscope")
                .font(.arial(size: 8))
            Text(label)
                .font(.arial(size: 10, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundColor(specialtyColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(specialtyColor.opacity(0.15))
        .cornerRadius(4)
    }
}

/// Location + ACGME ID line shared by program and interview list rows.
struct MatchlyProgramLocationAndIDRow: View {
    let program: Program

    private var resolved: AddressFormatter.ResolvedAddress {
        AddressFormatter.resolved(
            hospital: program.hospital,
            address: program.address,
            city: program.city,
            state: program.state,
            accreditationID: program.accreditationID
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            if !resolved.city.isEmpty && !resolved.state.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.arial(size: 9))
                    Text("\(resolved.city), \(resolved.state)")
                        .font(.arial(size: 11))
                }
                .foregroundColor(.secondary)
            }

            if let acgmeID = program.accreditationID, !acgmeID.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "number.circle.fill")
                        .font(.arial(size: 9))
                    Text("ID:")
                        .font(.arial(size: 10, weight: .medium))
                    Text(acgmeID)
                        .font(.arial(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary)
            }
        }
    }
}

/// Prominent tinted capsule for primary list-page actions (Add, Compare, Edit).
struct MatchlyActionChipLabel: View {
    let icon: String
    let text: String
    let tint: Color
    var isFilled: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.arial(size: 11, weight: .semibold))
            Text(text)
                .font(.arial(size: 12, weight: .semibold))
        }
        .foregroundColor(isFilled ? .white : tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isFilled ? tint : tint.opacity(0.12))
        )
        .overlay(
            Capsule()
                .strokeBorder(isFilled ? Color.clear : tint.opacity(0.35), lineWidth: 1)
        )
    }
}

/// Colored capsule for adding programs on the My Programs tab title row.
struct MatchlyToolbarAddProgramButton: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "plus")
                .font(.arial(size: 12, weight: .semibold))
            Text("Add Program")
                .font(.arial(size: 13, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(AppColors.primaryBlue))
        .accessibilityLabel("Add program")
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
                .background(Circle().fill(AppColors.primaryBlue))
        }
        .accessibilityLabel("Add")
    }
}

