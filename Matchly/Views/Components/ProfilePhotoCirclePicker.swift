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

    var diameter: CGFloat = 140

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var cropImageItem: CropImageItem?
    @State private var showCamera = false
    @State private var pendingCameraImage: UIImage?
    @State private var isLoadingPhoto = false
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
            Text("After taking or choosing a photo, pinch and drag to center it.")
        }
        .photosPicker(isPresented: $showPhotoLibrary, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            isLoadingPhoto = true
            Task {
                let preparedImage = await PhotoPickerImageLoader.loadPreparedImage(from: newItem)
                await MainActor.run {
                    isLoadingPhoto = false
                    if let preparedImage {
                        cropImageItem = CropImageItem(image: preparedImage)
                    } else {
                        selectedPhoto = nil
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera, onDismiss: presentPendingCameraCrop) {
            CameraImagePicker { image in
                pendingCameraImage = image
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $cropImageItem, onDismiss: {
            selectedPhoto = nil
        }) { item in
            ImageCropView(image: item.image) { croppedImage in
                if let data = croppedImage.jpegData(compressionQuality: 0.92) {
                    photoData = data
                    avatarPresetID = nil
                }
                selectedPhoto = nil
            }
        }
    }

    private func presentPendingCameraCrop() {
        guard let pendingCameraImage else { return }
        cropImageItem = CropImageItem(image: pendingCameraImage)
        self.pendingCameraImage = nil
    }

    private func presentCropForCurrentPhoto() {
        guard let photoData, let image = UIImage(data: photoData)?.fixedOrientation() else { return }
        cropImageItem = CropImageItem(image: image)
    }
}
