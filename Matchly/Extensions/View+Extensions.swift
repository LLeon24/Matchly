//
//  View+Extensions.swift
//  Matchly
//
//  Created on 12/6/25.
//

import SwiftUI
import UIKit

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
    func matchlyReadableWidth(_ maxWidth: CGFloat = 960) -> some View {
        modifier(MatchlyReadableWidthModifier(maxWidth: maxWidth))
    }
}

private struct MatchlyReadableWidthModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: horizontalSizeClass == .regular ? maxWidth : .infinity)
            .frame(maxWidth: .infinity)
    }
}

struct GlassCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
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

