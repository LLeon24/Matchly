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
    private enum ProfileEditField: Hashable {
        case firstName
        case lastName
        case aamcID
    }

    @EnvironmentObject var dataManager: DataManager
    @ObservedObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) var dismiss
    @FocusState private var focusedField: ProfileEditField?
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var aamcID: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var avatarPresetID: String?
    @State private var cropImageItem: CropImageItem?
    @State private var isLoadingPhoto = false
    @State private var keyboardHeight: CGFloat = 0
    
    var body: some View {
        ScrollViewReader { proxy in
            Form {
                profilePhotoSection
                personalInformationSection
                aamcSection

                if keyboardHeight > 0 {
                    Color.clear
                        .frame(height: max(24, keyboardHeight * 0.35))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: focusedField) { _, field in
                scrollToField(field, using: proxy)
            }
            .onChange(of: keyboardHeight) { _, height in
                guard height > 0, let field = focusedField else { return }
                scrollToField(field, using: proxy)
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
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = keyboardFrame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = 0
            }
        }
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

    private var profilePhotoSection: some View {
        Section {
            // Profile Photo
            VStack(spacing: 16) {
                ZStack {
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
                    .disabled(isLoadingPhoto)
                    
                    if isLoadingPhoto {
                        Circle()
                            .fill(Color.black.opacity(0.45))
                            .frame(width: 120, height: 120)
                        ProgressView()
                            .tint(.white)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
            .padding(.bottom, 8)

            ProfileAvatarPresetPicker(selectedPresetID: avatarPresetID) { preset, data in
                selectedPhoto = nil
                photoData = data
                avatarPresetID = preset.id
            }
            .padding(.bottom, 12)
            
            if photoData != nil || dataManager.preferences.profile.photoData != nil {
                Button(role: .destructive, action: {
                    photoData = nil
                    avatarPresetID = nil
                    selectedPhoto = nil
                    dataManager.preferences.profile.photoData = nil
                    dataManager.preferences.profile.avatarPresetID = nil
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
    }

    private var personalInformationSection: some View {
        Section {
            ClearableTextFieldRow<ProfileEditField>(
                "First Name",
                text: $firstName,
                focus: $focusedField,
                equals: .firstName,
                textContentType: .givenName
            )
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: .capsule)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .id(ProfileEditField.firstName)

            ClearableTextFieldRow<ProfileEditField>(
                "Last Name",
                text: $lastName,
                focus: $focusedField,
                equals: .lastName,
                textContentType: .familyName
            )
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: .capsule)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .id(ProfileEditField.lastName)
        } header: {
            Text("Personal Information")
        }
    }

    private var aamcSection: some View {
        Section {
            ClearableTextFieldRow<ProfileEditField>(
                "AAMC ID (Optional)",
                text: $aamcID,
                focus: $focusedField,
                equals: .aamcID
            )
                .keyboardType(.default)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: .capsule)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .id(ProfileEditField.aamcID)
        } header: {
            Text("AAMC Information")
        }
    }
    
    private func scrollToField(_ field: ProfileEditField?, using proxy: ScrollViewProxy) {
        guard let field else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(field, anchor: .center)
            }
        }
    }

    private func loadProfile() {
        firstName = dataManager.preferences.profile.firstName
        lastName = dataManager.preferences.profile.lastName
        aamcID = dataManager.preferences.profile.aamcID ?? ""
        photoData = dataManager.preferences.profile.photoData
        avatarPresetID = dataManager.preferences.profile.avatarPresetID
    }
    
    private func saveProfile() {
        dataManager.preferences.profile.firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        dataManager.preferences.profile.lastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        dataManager.preferences.profile.aamcID = aamcID.trimmingCharacters(in: .whitespaces).isEmpty ? nil : aamcID.trimmingCharacters(in: .whitespaces)
        // Always save the photoData if it exists, even if it's nil (to allow removal)
        if photoData != nil {
            dataManager.preferences.profile.photoData = photoData
            dataManager.preferences.profile.avatarPresetID = avatarPresetID
        } else if photoData == nil && dataManager.preferences.profile.photoData != nil && selectedPhoto == nil {
            // Only clear if user explicitly removed it
            dataManager.preferences.profile.photoData = nil
            dataManager.preferences.profile.avatarPresetID = nil
        }
        dataManager.savePreferences()
        dataManager.scheduleCoupleCloudPublish()
        authManager.updateDisplayName(dataManager.preferences.profile.name)
        dataManager.objectWillChange.send() // Force UI refresh
        dismiss()
    }
}

#Preview {
    MatchlyNavigationView {
        ProfileEditView()
            .environmentObject(DataManager.shared)
    }
}

