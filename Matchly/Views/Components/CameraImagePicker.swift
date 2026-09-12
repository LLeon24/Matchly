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
