//
//  UIImage+PhotoProcessing.swift
//  Matchly
//

import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct CropImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Loads full-resolution image data from PhotosPicker (avoids low-res preview Data).
struct ProfilePhotoPickerImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let image = UIImage.preparedForCropping(from: data, maxPixelDimension: 4096) else {
                throw CocoaError(.coderReadCorrupt)
            }
            return ProfilePhotoPickerImage(image: image)
        }
    }
}

enum PhotoPickerImageLoader {
    private static let maxPixelDimension: CGFloat = 4096

    static func loadPreparedImage(from item: PhotosPickerItem) async -> UIImage? {
        if let picked = try? await item.loadTransferable(type: ProfilePhotoPickerImage.self) {
            return picked.image
        }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        return await loadPreparedImage(from: data)
    }

    static func loadPreparedImage(from data: Data) async -> UIImage? {
        let data = data
        let maxPixel = maxPixelDimension
        return await Task.detached(priority: .userInitiated) {
            UIImage.preparedForCropping(from: data, maxPixelDimension: maxPixel)
        }.value
    }
}

extension UIImage {
    nonisolated static func preparedForCropping(from data: Data, maxPixelDimension: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)?.fixedOrientation()
        }

        let pixelSize = imagePixelSize(from: source)
        let longestEdge = max(pixelSize.width, pixelSize.height)
        let cgImage: CGImage?

        if longestEdge > maxPixelDimension {
            let thumbOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension,
            ]
            cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary)
        } else {
            let fullOptions: [CFString: Any] = [
                kCGImageSourceShouldCacheImmediately: true,
            ]
            cgImage = CGImageSourceCreateImageAtIndex(source, 0, fullOptions as CFDictionary)
        }

        guard let cgImage else {
            return UIImage(data: data)?.fixedOrientation()
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    nonisolated private static func imagePixelSize(from source: CGImageSource) -> CGSize {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            return .zero
        }
        return CGSize(width: width, height: height)
    }

    nonisolated func fixedOrientation() -> UIImage {
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
