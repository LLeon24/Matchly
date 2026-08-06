import SwiftUI
import UIKit

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

        // Prefer Arial via UIFont descriptor when a named face is missing.
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
    /// Applies Arial as the default environment font for the view hierarchy.
    func arialFont() -> some View {
        environment(\.font, Font.arial(size: 17, weight: .regular))
    }
}
