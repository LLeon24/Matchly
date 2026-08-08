//
//  ImageCropView.swift
//  Matchly
//

import SwiftUI
import UIKit

struct ImageCropView: View {
    let image: UIImage
    var onCrop: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var steadyScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var steadyOffset: CGSize = .zero
    @State private var minScale: CGFloat = 1
    @State private var viewSize: CGSize = .zero
    @State private var fittedSize: CGSize = .zero
    @State private var didInitializeLayout = false

    private let cropSize: CGFloat = 300

    private var cropPixelSize: CGFloat {
        cropSize * max(UIScreen.main.scale, 2)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let fitted = fittedImageSize(in: geometry.size)

                ZStack {
                    Color.black.ignoresSafeArea()

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: fitted.width, height: fitted.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .contentShape(Rectangle())
                        .gesture(dragGesture(fitted: fitted))
                        .simultaneousGesture(magnificationGesture(fitted: fitted))

                    cropOverlay
                }
                .onAppear {
                    viewSize = geometry.size
                    fittedSize = fitted
                    if !didInitializeLayout {
                        initializeTransform(fitted: fitted)
                        didInitializeLayout = true
                    }
                }
            }
            .navigationTitle("Crop Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { cropImage() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var cropOverlay: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.55))
                .mask {
                    ZStack {
                        Rectangle()
                        Circle()
                            .frame(width: cropSize, height: cropSize)
                            .blendMode(.destinationOut)
                    }
                }
                .allowsHitTesting(false)

            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: cropSize, height: cropSize)
                .allowsHitTesting(false)

            VStack {
                Spacer()
                VStack(spacing: 6) {
                    Text("Pinch to zoom • Drag to move")
                        .font(.arial(size: 14))
                    Text("Position your photo in the circle")
                        .font(.arial(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.bottom, 36)
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - Gestures

    private func dragGesture(fitted: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                offset = CGSize(
                    width: steadyOffset.width + value.translation.width,
                    height: steadyOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                steadyOffset = offset
                constrainOffset(fitted: fitted)
            }
    }

    private func magnificationGesture(fitted: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(steadyScale * value, minScale), minScale * 4)
                constrainOffset(fitted: fitted)
            }
            .onEnded { _ in
                steadyScale = scale
                constrainOffset(fitted: fitted)
            }
    }

    // MARK: - Layout

    private func fittedImageSize(in container: CGSize) -> CGSize {
        guard container.width > 0, container.height > 0 else { return .zero }
        let imageAspect = image.size.width / image.size.height
        let viewAspect = container.width / container.height
        if imageAspect > viewAspect {
            return CGSize(width: container.width, height: container.width / imageAspect)
        }
        return CGSize(width: container.height * imageAspect, height: container.height)
    }

    private func initializeTransform(fitted: CGSize) {
        guard fitted.width > 0, fitted.height > 0 else { return }
        let fillScale = max(cropSize / fitted.width, cropSize / fitted.height, 1)
        minScale = fillScale
        scale = fillScale
        steadyScale = fillScale
        offset = .zero
        steadyOffset = .zero
        constrainOffset(fitted: fitted)
    }

    private func constrainOffset(fitted: CGSize) {
        let scaledWidth = fitted.width * scale
        let scaledHeight = fitted.height * scale
        let maxOffsetX = max(0, (scaledWidth - cropSize) / 2)
        let maxOffsetY = max(0, (scaledHeight - cropSize) / 2)

        offset.width = min(max(offset.width, -maxOffsetX), maxOffsetX)
        offset.height = min(max(offset.height, -maxOffsetY), maxOffsetY)
        steadyOffset = offset
    }

    // MARK: - Crop

    private func cropImage() {
        let container = viewSize.width > 0 ? viewSize : CGSize(width: 393, height: 852)
        let fitted = fittedSize.width > 0 ? fittedSize : fittedImageSize(in: container)

        guard let cgImage = image.cgImage else {
            onCrop(image)
            dismiss()
            return
        }

        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)
        let scaledWidth = fitted.width * scale
        let scaledHeight = fitted.height * scale

        let cropCenter = CGPoint(x: container.width / 2, y: container.height / 2)
        let imageCenter = CGPoint(x: cropCenter.x + offset.width, y: cropCenter.y + offset.height)

        let imageTopLeft = CGPoint(
            x: imageCenter.x - scaledWidth / 2,
            y: imageCenter.y - scaledHeight / 2
        )

        let cropRect = CGRect(
            x: cropCenter.x - cropSize / 2,
            y: cropCenter.y - cropSize / 2,
            width: cropSize,
            height: cropSize
        )

        let visible = cropRect.intersection(
            CGRect(x: imageTopLeft.x, y: imageTopLeft.y, width: scaledWidth, height: scaledHeight)
        )

        let scaleX = pixelWidth / scaledWidth
        let scaleY = pixelHeight / scaledHeight

        var source = CGRect(
            x: (visible.minX - imageTopLeft.x) * scaleX,
            y: (visible.minY - imageTopLeft.y) * scaleY,
            width: visible.width * scaleX,
            height: visible.height * scaleY
        )

        source.origin.x = max(0, source.origin.x)
        source.origin.y = max(0, source.origin.y)
        source.size.width = min(source.width, pixelWidth - source.origin.x)
        source.size.height = min(source.height, pixelHeight - source.origin.y)

        let outputSize = CGSize(width: cropPixelSize, height: cropPixelSize)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)

        let cropped = renderer.image { context in
            let outputRect = CGRect(origin: .zero, size: outputSize)
            context.cgContext.addEllipse(in: outputRect)
            context.cgContext.clip()

            if let croppedCG = cgImage.cropping(to: source) {
                UIImage(cgImage: croppedCG, scale: image.scale, orientation: .up)
                    .draw(in: outputRect)
            } else {
                image.draw(in: outputRect)
            }
        }

        onCrop(cropped)
        dismiss()
    }
}

#Preview {
    ImageCropView(
        image: UIImage(systemName: "person.fill")!,
        onCrop: { _ in }
    )
}
