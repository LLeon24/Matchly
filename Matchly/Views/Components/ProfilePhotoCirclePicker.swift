//
//  ProfilePhotoCirclePicker.swift
//  Matchly
//

import SwiftUI
import PhotosUI
import UIKit

struct ProfilePhotoCirclePicker: View {
    @Binding var photoData: Data?
    @Binding var avatarPresetID: String?
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var cropImageItem: CropImageItem?
    @Binding var showCamera: Bool

    var diameter: CGFloat = 140
    var isLoadingPhoto: Bool = false

    @State private var showPhotoSourceDialog = false
    @State private var showPhotoLibrary = false

    private var hasPhoto: Bool {
        photoData != nil
    }

    var body: some View {
        Button {
            showPhotoSourceDialog = true
        } label: {
            ZStack {
                Circle()
                    .fill(.clear)
                    .frame(width: diameter, height: diameter)
                    .glassEffect(.regular.interactive(), in: .circle)

                if let photoData,
                   let uiImage = UIImage(data: photoData)?.fixedOrientation() {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: diameter, height: diameter)
                        .clipShape(Circle())
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.arial(size: 32))
                            .foregroundColor(.blue)
                        Text("Tap to Add")
                            .font(.arial(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }

                if hasPhoto && !isLoadingPhoto {
                    Circle()
                        .fill(Color.black.opacity(0.28))
                        .frame(width: diameter, height: diameter)

                    VStack(spacing: 4) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.arial(size: 28))
                            .foregroundColor(.white)
                        Text("Edit")
                            .font(.arial(size: 13, weight: .medium))
                            .foregroundColor(.white)
                    }
                }

                if isLoadingPhoto {
                    Circle()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: diameter, height: diameter)
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoadingPhoto)
        .accessibilityLabel(hasPhoto ? "Edit profile photo" : "Add profile photo")
        .confirmationDialog(
            hasPhoto ? "Edit Profile Photo" : "Add Profile Photo",
            isPresented: $showPhotoSourceDialog,
            titleVisibility: .visible
        ) {
            if CameraImagePicker.isAvailable {
                Button("Take Photo") { showCamera = true }
            }
            Button("Choose from Library") { showPhotoLibrary = true }
            if hasPhoto {
                Button("Adjust & Crop") { presentCropForCurrentPhoto() }
                Button("Remove Photo", role: .destructive) {
                    photoData = nil
                    avatarPresetID = nil
                    selectedPhoto = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Pinch and drag to center your face after choosing a photo.")
        }
        .photosPicker(isPresented: $showPhotoLibrary, selection: $selectedPhoto, matching: .images)
    }

    private func presentCropForCurrentPhoto() {
        guard let photoData, let image = UIImage(data: photoData)?.fixedOrientation() else { return }
        cropImageItem = CropImageItem(image: image)
    }
}
