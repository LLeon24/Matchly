//
//  ProfileAvatarPresets.swift
//  Matchly
//

import SwiftUI
import UIKit

struct ProfileAvatarPreset: Identifiable, Equatable {
    let id: String
    let symbolName: String
    let colors: [UIColor]

    func jpegData(compressionQuality: CGFloat = 0.9, size: CGFloat = 512) -> Data? {
        renderImage(size: size)?.jpegData(compressionQuality: compressionQuality)
    }

    func renderImage(size: CGFloat = 512) -> UIImage? {
        let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        let renderer = UIGraphicsImageRenderer(size: rect.size)

        return renderer.image { context in
            let cgContext = context.cgContext
            cgContext.addEllipse(in: rect)
            cgContext.clip()

            let gradientColors = colors.map { $0.cgColor } as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: gradientColors,
                locations: gradientLocations(count: colors.count)
            ) {
                cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size, y: size),
                    options: []
                )
            }

            let symbolConfig = UIImage.SymbolConfiguration(pointSize: size * 0.34, weight: .semibold)
            guard let symbol = UIImage(systemName: symbolName, withConfiguration: symbolConfig)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) else {
                return
            }

            let symbolSize = symbol.size
            let symbolOrigin = CGPoint(
                x: (size - symbolSize.width) / 2,
                y: (size - symbolSize.height) / 2
            )
            symbol.draw(at: symbolOrigin)
        }
    }

    private func gradientLocations(count: Int) -> [CGFloat] {
        guard count > 1 else { return [0] }
        return (0..<count).map { CGFloat($0) / CGFloat(count - 1) }
    }
}

enum ProfileAvatarPresets {
    static let all: [ProfileAvatarPreset] = [
        ProfileAvatarPreset(
            id: "clinical-blue",
            symbolName: "stethoscope",
            colors: [UIColor(red: 0.18, green: 0.45, blue: 0.95, alpha: 1), UIColor(red: 0.35, green: 0.75, blue: 0.98, alpha: 1)]
        ),
        ProfileAvatarPreset(
            id: "medicine-teal",
            symbolName: "cross.case.fill",
            colors: [UIColor(red: 0.05, green: 0.55, blue: 0.58, alpha: 1), UIColor(red: 0.28, green: 0.78, blue: 0.72, alpha: 1)]
        ),
        ProfileAvatarPreset(
            id: "student-purple",
            symbolName: "graduationcap.fill",
            colors: [UIColor(red: 0.45, green: 0.28, blue: 0.85, alpha: 1), UIColor(red: 0.68, green: 0.45, blue: 0.98, alpha: 1)]
        ),
        ProfileAvatarPreset(
            id: "heart-pink",
            symbolName: "heart.fill",
            colors: [UIColor(red: 0.88, green: 0.24, blue: 0.45, alpha: 1), UIColor(red: 0.98, green: 0.45, blue: 0.62, alpha: 1)]
        ),
        ProfileAvatarPreset(
            id: "mind-indigo",
            symbolName: "brain.head.profile",
            colors: [UIColor(red: 0.28, green: 0.32, blue: 0.78, alpha: 1), UIColor(red: 0.48, green: 0.52, blue: 0.95, alpha: 1)]
        ),
        ProfileAvatarPreset(
            id: "classic-gray",
            symbolName: "person.fill",
            colors: [UIColor(red: 0.35, green: 0.38, blue: 0.44, alpha: 1), UIColor(red: 0.58, green: 0.61, blue: 0.67, alpha: 1)]
        )
    ]

    static func preset(id: String?) -> ProfileAvatarPreset? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }
}
