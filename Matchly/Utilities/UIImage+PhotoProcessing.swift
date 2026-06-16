//
//  UIImage+PhotoProcessing.swift
//  Matchly
//

import ImageIO
import UIKit

struct CropImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

enum PhotoPickerImageLoader {
    private static let maxPixelDimension: CGFloat = 2048

    static func loadPreparedImage(from data: Data) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            UIImage.preparedForCropping(from: data, maxPixelDimension: maxPixelDimension)
        }.value
    }
}

extension UIImage {
    static func preparedForCropping(from data: Data, maxPixelDimension: CGFloat) -> UIImage? {
        let image = downsampledImage(from: data, maxPixelDimension: maxPixelDimension) ?? UIImage(data: data)
        return image?.fixedOrientation()
    }

    static func downsampledImage(from data: Data, maxPixelDimension: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    func fixedOrientation() -> UIImage {
        if imageOrientation == .up {
            return self
        }

        var transform = CGAffineTransform.identity

        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: -.pi / 2)
        default:
            break
        }

        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }

        guard let cgImage, let colorSpace = cgImage.colorSpace else {
            return self
        }

        let width: Int
        let height: Int

        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            width = Int(size.height)
            height = Int(size.width)
        default:
            width = Int(size.width)
            height = Int(size.height)
        }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: cgImage.bitmapInfo.rawValue
        ) else {
            return self
        }

        context.concatenate(transform)

        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
        default:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }

        guard let cgImageFixed = context.makeImage() else {
            return self
        }

        return UIImage(cgImage: cgImageFixed, scale: scale, orientation: .up)
    }
}
