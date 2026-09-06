//
//  CameraImagePicker.swift
//  Matchly
//

import SwiftUI
import UIKit

struct CameraImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var cameraDevice: UIImagePickerController.CameraDevice = .front
    var onImagePicked: (UIImage) -> Void

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = cameraDevice
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        picker.showsCameraControls = true

        let overlay = FaceGuideCameraOverlayView()
        overlay.frame = UIScreen.main.bounds
        picker.cameraOverlayView = overlay

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraImagePicker

        init(parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image.fixedOrientation())
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Face guide overlay

private final class FaceGuideCameraOverlayView: UIView {
    private let guideLayer = CAShapeLayer()
    private let instructionLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear

        guideLayer.fillRule = .evenOdd
        guideLayer.fillColor = UIColor.black.withAlphaComponent(0.35).cgColor
        layer.addSublayer(guideLayer)

        instructionLabel.text = "Position your face in the oval"
        instructionLabel.font = .systemFont(ofSize: 15, weight: .medium)
        instructionLabel.textColor = .white
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 2
        addSubview(instructionLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let ovalWidth = bounds.width * 0.58
        let ovalHeight = bounds.height * 0.34
        let ovalRect = CGRect(
            x: (bounds.width - ovalWidth) / 2,
            y: bounds.height * 0.22,
            width: ovalWidth,
            height: ovalHeight
        )

        let path = UIBezierPath(rect: bounds)
        path.append(UIBezierPath(ovalIn: ovalRect))
        guideLayer.path = path.cgPath
        guideLayer.strokeColor = UIColor.white.withAlphaComponent(0.85).cgColor
        guideLayer.lineWidth = 2
        guideLayer.lineDashPattern = [8, 6]

        instructionLabel.frame = CGRect(
            x: 24,
            y: ovalRect.maxY + 16,
            width: bounds.width - 48,
            height: 44
        )
    }
}
