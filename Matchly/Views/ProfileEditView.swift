//
//  ProfileEditView.swift
//  Matchly
//
//  Created on 11/14/25.
//

import SwiftUI
import PhotosUI
import Combine
import UIKit

struct ProfileEditView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var aamcID: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showImageCrop: Bool = false
    @State private var imageToCrop: UIImage?
    
    var body: some View {
        Form {
            Section {
                // Profile Photo
                VStack(spacing: 16) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        ZStack {
                            if let photoData = photoData,
                               let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                            } else if let existingPhotoData = dataManager.preferences.profile.photoData,
                                      let uiImage = UIImage(data: existingPhotoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 120, height: 120)
                                    
                                    Image(systemName: "person.fill")
                                        .font(.arial(size: 50))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                            }
                            
                            // Edit overlay
                            Circle()
                                .fill(Color.black.opacity(0.4))
                                .frame(width: 120, height: 120)
                            
                            VStack(spacing: 4) {
                                Image(systemName: "camera.fill")
                                    .font(.arial(size: 24))
                                    .foregroundColor(.white)
                                Text(photoData != nil || dataManager.preferences.profile.photoData != nil ? "Change" : "Add Photo")
                                    .font(.arial(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24) // Increased padding for Dynamic Island
                .padding(.bottom, 20) // Increased bottom padding
                
                if photoData != nil || dataManager.preferences.profile.photoData != nil {
                    Button(role: .destructive, action: {
                        photoData = nil
                        selectedPhoto = nil
                        // Immediately update UI
                        dataManager.preferences.profile.photoData = nil
                    }) {
                        HStack {
                            Spacer()
                            Text("Remove Photo")
                            Spacer()
                        }
                    }
                }
            } header: {
                Text("Profile Photo")
            }
            
            Section {
                TextField("Name", text: $name)
                    .autocapitalization(.words)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: .capsule)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            } header: {
                Text("Personal Information")
            } footer: {
                Text("Your name will be displayed in the dashboard welcome message")
            }
            
            Section {
                TextField("AAMC ID (Optional)", text: $aamcID)
                    .keyboardType(.default)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: .capsule)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            } header: {
                Text("AAMC Information")
            } footer: {
                Text("Your AAMC ID helps us provide better program matching")
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveProfile()
                }
                .fontWeight(.semibold)
                .buttonStyle(.glassProminent)
                .tint(AppColors.primaryBlue)
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvasBackground()
        .onAppear {
            loadProfile()
        }
        .onChange(of: selectedPhoto) { oldValue, newItem in
            Task {
                if let newItem = newItem {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            // Fix orientation before showing crop view
                            imageToCrop = uiImage.fixedOrientation()
                            showImageCrop = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showImageCrop) {
            if let imageToCrop = imageToCrop {
                ImageCropView(image: imageToCrop) { croppedImage in
                    // Save the cropped image with proper orientation
                    // Use JPEG with high quality to preserve image quality
                    if let data = croppedImage.jpegData(compressionQuality: 0.9) {
                        photoData = data
                    }
                    // Clear the image to crop
                    self.imageToCrop = nil
                }
            }
        }
    }
    
    private func loadProfile() {
        name = dataManager.preferences.profile.name
        aamcID = dataManager.preferences.profile.aamcID ?? ""
        photoData = dataManager.preferences.profile.photoData
    }
    
    private func saveProfile() {
        dataManager.preferences.profile.name = name.trimmingCharacters(in: .whitespaces)
        dataManager.preferences.profile.aamcID = aamcID.trimmingCharacters(in: .whitespaces).isEmpty ? nil : aamcID.trimmingCharacters(in: .whitespaces)
        // Always save the photoData if it exists, even if it's nil (to allow removal)
        if photoData != nil {
            dataManager.preferences.profile.photoData = photoData
        } else if photoData == nil && dataManager.preferences.profile.photoData != nil && selectedPhoto == nil {
            // Only clear if user explicitly removed it
            dataManager.preferences.profile.photoData = nil
        }
        dataManager.savePreferences()
        dataManager.objectWillChange.send() // Force UI refresh
        dismiss()
    }
}

// MARK: - UIImage Extension for Orientation Fix
extension UIImage {
    /// Fixes image orientation by redrawing the image in the correct orientation
    func fixedOrientation() -> UIImage {
        // If orientation is already up, return self
        if imageOrientation == .up {
            return self
        }
        
        // Calculate the proper transform to make the image upright
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
        
        // Now we draw the underlying CGImage into a new context, applying the transform
        guard let cgImage = cgImage else {
            return self
        }
        
        guard let colorSpace = cgImage.colorSpace else {
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

#Preview {
    NavigationView {
        ProfileEditView()
            .environmentObject(DataManager.shared)
    }
}

