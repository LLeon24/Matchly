//
//  CoupleQRCodeView.swift
//  Matchly
//

import CoreImage.CIFilterBuiltins
import SwiftUI

enum CoupleQRCodeImage {
    static func makeImage(for code: String) -> UIImage? {
        let payload = Couple.qrPayload(for: code)
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let scale = 240.0 / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct CoupleQRCodeView: View {
    let code: String
    var size: CGFloat = 220

    private var qrImage: UIImage? {
        CoupleQRCodeImage.makeImage(for: code)
    }

    var body: some View {
        VStack(spacing: 12) {
            if let qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemGray5))
                    .frame(width: size, height: size)
                    .overlay {
                        ProgressView()
                    }
            }

            Text(code.uppercased())
                .font(.arial(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.primaryBlue)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Couple code \(code.uppercased())")
    }
}
