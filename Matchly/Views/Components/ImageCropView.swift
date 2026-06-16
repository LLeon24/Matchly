//
//  ImageCropView.swift
//  Matchly
//
//  Created on 12/7/25.
//

import SwiftUI
import UIKit

struct ImageCropView: View {
    let image: UIImage
    var onCrop: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var baseScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero

    @State private var geometrySize: CGSize = .zero
    @State private var imageFittedSize: CGSize = .zero

    private let cropSize: CGFloat = 300

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                GeometryReader { geometry in
                    let fittedSize = fittedImageSize(in: geometry.size)

                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: fittedSize.width * scale, height: fittedSize.height * scale)
                            .position(
                                x: geometry.size.width / 2 + offset.width + dragOffset.width,
                                y: geometry.size.height / 2 + offset.height + dragOffset.height
                            )

                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(cropGestures(fittedSize: fittedSize, geometry: geometry))
                    }
                    .onAppear {
                        geometrySize = geometry.size
                        imageFittedSize = fittedSize
                        initializeTransform(fittedSize: fittedSize)
                    }
                    .onChange(of: geometry.size) { _, newValue in
                        geometrySize = newValue
                        let newFitted = fittedImageSize(in: newValue)
                        imageFittedSize = newFitted
                        initializeTransform(fittedSize: newFitted)
                    }
                }

                cropOverlay
            }
            .navigationTitle("Crop Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        cropImage()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var cropOverlay: some View {
        VStack {
            Spacer()

            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .mask(
                        ZStack {
                            Rectangle()
                            Circle()
                                .frame(width: cropSize, height: cropSize)
                                .blendMode(.destinationOut)
                        }
                    )

                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cropSize, height: cropSize)
            }
            .frame(height: cropSize)
            .allowsHitTesting(false)

            Spacer()

            VStack(spacing: 8) {
                Text("Pinch to zoom • Drag to move")
                    .font(.arial(size: 14))
                    .foregroundColor(.white.opacity(0.8))

                Text("Position your photo in the circle")
                    .font(.arial(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.bottom, 40)
            .allowsHitTesting(false)
        }
        .allowsHitTesting(false)
    }

    private func cropGestures(fittedSize: CGSize, geometry: GeometryProxy) -> some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    let minimum = minScale(for: fittedSize)
                    scale = min(max(baseScale * value, minimum), 4.0)
                }
                .onEnded { _ in
                    baseScale = scale
                    constrainImage(fittedSize: fittedSize)
                },
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    offset = CGSize(
                        width: offset.width + value.translation.width,
                        height: offset.height + value.translation.height
                    )
                    dragOffset = .zero
                    constrainImage(fittedSize: fittedSize)
                }
        )
    }

    private func fittedImageSize(in viewSize: CGSize) -> CGSize {
        guard viewSize.width > 0, viewSize.height > 0 else { return .zero }
        let imageAspectRatio = image.size.width / image.size.height
        let viewAspectRatio = viewSize.width / viewSize.height

        if imageAspectRatio > viewAspectRatio {
            return CGSize(width: viewSize.width, height: viewSize.width / imageAspectRatio)
        }
        return CGSize(width: viewSize.height * imageAspectRatio, height: viewSize.height)
    }

    private func minScale(for fittedSize: CGSize) -> CGFloat {
        guard fittedSize.width > 0, fittedSize.height > 0 else { return 1.0 }
        return max(cropSize / fittedSize.width, cropSize / fittedSize.height, 1.0)
    }

    private func initializeTransform(fittedSize: CGSize) {
        let minimum = minScale(for: fittedSize)
        scale = minimum
        baseScale = minimum
        offset = .zero
        dragOffset = .zero
    }

    private func constrainImage(fittedSize: CGSize) {
        let scaledWidth = fittedSize.width * scale
        let scaledHeight = fittedSize.height * scale

        let maxOffsetX = max(0, (scaledWidth - cropSize) / 2)
        let maxOffsetY = max(0, (scaledHeight - cropSize) / 2)

        offset.width = min(max(offset.width, -maxOffsetX), maxOffsetX)
        offset.height = min(max(offset.height, -maxOffsetY), maxOffsetY)
    }

    private func cropImage() {
        let viewSize = geometrySize.width > 0 ? geometrySize : CGSize(width: 393, height: 852)
        let fittedSize: CGSize = {
            if imageFittedSize.width > 0 { return imageFittedSize }
            return fittedImageSize(in: viewSize)
        }()

        guard let cgImage = image.cgImage else {
            onCrop(image)
            dismiss()
            return
        }

        let actualImageWidth = CGFloat(cgImage.width)
        let actualImageHeight = CGFloat(cgImage.height)

        let scaledImageWidth = fittedSize.width * scale
        let scaledImageHeight = fittedSize.height * scale

        let totalOffset = CGSize(
            width: offset.width + dragOffset.width,
            height: offset.height + dragOffset.height
        )

        let cropCenterX = viewSize.width / 2
        let cropCenterY = viewSize.height / 2

        let imageCenterX = cropCenterX + totalOffset.width
        let imageCenterY = cropCenterY + totalOffset.height

        let imageTopLeftX = imageCenterX - scaledImageWidth / 2
        let imageTopLeftY = imageCenterY - scaledImageHeight / 2

        let cropLeft = cropCenterX - cropSize / 2
        let cropTop = cropCenterY - cropSize / 2
        let cropRight = cropCenterX + cropSize / 2
        let cropBottom = cropCenterY + cropSize / 2

        let visibleLeft = max(cropLeft, imageTopLeftX)
        let visibleTop = max(cropTop, imageTopLeftY)
        let visibleRight = min(cropRight, imageTopLeftX + scaledImageWidth)
        let visibleBottom = min(cropBottom, imageTopLeftY + scaledImageHeight)

        let scaleX = actualImageWidth / scaledImageWidth
        let scaleY = actualImageHeight / scaledImageHeight

        let sourceX = max(0, (visibleLeft - imageTopLeftX) * scaleX)
        let sourceY = max(0, (visibleTop - imageTopLeftY) * scaleY)
        let sourceWidth = min((visibleRight - visibleLeft) * scaleX, actualImageWidth - sourceX)
        let sourceHeight = min((visibleBottom - visibleTop) * scaleY, actualImageHeight - sourceY)

        let sourceRect = CGRect(x: sourceX, y: sourceY, width: sourceWidth, height: sourceHeight)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropSize, height: cropSize))

        let croppedImage = renderer.image { context in
            let outputRect = CGRect(origin: .zero, size: CGSize(width: cropSize, height: cropSize))
            context.cgContext.addEllipse(in: outputRect)
            context.cgContext.clip()

            if let croppedCGImage = cgImage.cropping(to: sourceRect) {
                let croppedUIImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: .up)
                croppedUIImage.draw(in: outputRect)
            } else {
                image.draw(in: outputRect)
            }
        }

        onCrop(croppedImage)
        dismiss()
    }
}

#Preview {
    ImageCropView(
        image: UIImage(systemName: "person.fill")!,
        onCrop: { _ in }
    )
}
