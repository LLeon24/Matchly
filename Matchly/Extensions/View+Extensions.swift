//
//  View+Extensions.swift
//  Matchly
//
//  Created on 12/6/25.
//

import SwiftUI
import UIKit

// MARK: - Dashboard Card Style
extension View {
    func dashboardCardStyle() -> some View {
        modifier(DashboardCardStyle())
    }
}

struct DashboardCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(
                // Elevated card surface that floats on the warm dashboard canvas:
                // pure white in light mode, elevated dark gray in dark mode so
                // sections stay clearly distinguishable against the bright canvas.
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppColors.dashboardCard)
            )
            // Soft, diffuse shadow for a premium "floating card" feel.
            .shadow(color: Color.black.opacity(0.07), radius: 18, x: 0, y: 8)
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

