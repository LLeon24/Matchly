//
//  ProfilePhotoView.swift
//  Matchly
//

import SwiftUI
import UIKit

struct ProfilePhotoView: View {
    var photoData: Data?
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage.fixedOrientation())
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.42, weight: .medium))
                            .foregroundStyle(Color(.systemGray))
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(Color(.separator).opacity(0.25), lineWidth: 1)
        }
    }
}
