//
//  ProfileAvatarPresetPicker.swift
//  Matchly
//

import SwiftUI

struct ProfileAvatarPresetPicker: View {
    let selectedPresetID: String?
    var onSelect: (ProfileAvatarPreset, Data) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Or choose an avatar")
                .font(.arial(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(ProfileAvatarPresets.all) { preset in
                        Button {
                            if let data = preset.jpegData() {
                                onSelect(preset, data)
                            }
                        } label: {
                            presetButton(for: preset)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Avatar preset")
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
    }

    private func presetButton(for preset: ProfileAvatarPreset) -> some View {
        let isSelected = selectedPresetID == preset.id

        return ZStack {
            if let image = preset.renderImage(size: 128) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 58)
                    .clipShape(Circle())
            }

            Circle()
                .strokeBorder(isSelected ? AppColors.primaryBlue : Color.clear, lineWidth: 3)
                .frame(width: 64, height: 64)
        }
        .frame(width: 64, height: 64)
    }
}
