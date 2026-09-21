//
//  ProgramRedFlagLeadingStripe.swift
//  Matchly
//
//  Slim leading indicator for red-flagged programs in list rows.
//

import SwiftUI

enum ProgramRedFlagLeadingStripeMetrics {
    static let width: CGFloat = 2.5
    static let color = Color.red.opacity(0.88)
}

private struct ProgramRedFlagLeadingStripeModifier: ViewModifier {
    let isRedFlagged: Bool
    let listLeadingInset: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .leading) {
                if isRedFlagged {
                    ProgramRedFlagLeadingStripeMetrics.color
                        .frame(width: ProgramRedFlagLeadingStripeMetrics.width)
                        .frame(maxHeight: .infinity)
                        .offset(x: -(listLeadingInset - 2))
                }
            }
    }
}

extension View {
    /// Draws a slim red line at the list row’s leading edge without shifting row content.
    func programRedFlagLeadingStripe(isRedFlagged: Bool, listLeadingInset: CGFloat) -> some View {
        modifier(ProgramRedFlagLeadingStripeModifier(isRedFlagged: isRedFlagged, listLeadingInset: listLeadingInset))
    }
}
