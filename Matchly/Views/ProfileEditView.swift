//
//  ProfileEditView.swift
//  Matchly
//
//  Created on 11/14/25.
//

import SwiftUI
import PhotosUI
import Combine

struct ProfileEditView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var aamcID: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    
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
                                        .font(.system(size: 50))
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
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                Text(photoData != nil || dataManager.preferences.profile.photoData != nil ? "Change" : "Add Photo")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                
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
            }
        }
        .onAppear {
            loadProfile()
        }
        .onChange(of: selectedPhoto) { oldValue, newItem in
            Task {
                if let newItem = newItem {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            photoData = data
                        }
                    }
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

#Preview {
    NavigationView {
        ProfileEditView()
            .environmentObject(DataManager.shared)
    }
}

