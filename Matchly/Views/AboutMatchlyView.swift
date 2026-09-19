//
//  AboutMatchlyView.swift
//  Matchly
//

import SwiftUI

struct AboutMatchlyView: View {
    var body: some View {
        Form {
            Section {
                VStack(spacing: 20) {
                    MatchlyBrandInlineWordmark(glyphSize: .hero)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text(AboutMatchlyCopy.description)
                        .font(.arial(size: MatchlyEditorialTypography.captionSize, weight: .light))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(MatchlyBuildInfo.version)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Link(destination: MatchlyLegalURLs.privacyPolicy) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
                Link(destination: MatchlyLegalURLs.termsOfService) {
                    Label("Terms of Service", systemImage: "doc.text")
                }
                Link(destination: MatchlyLegalURLs.support) {
                    Label("Support", systemImage: "questionmark.circle")
                }
            } header: {
                Text("Legal & Support")
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .appCanvasBackground()
    }
}

private enum AboutMatchlyCopy {
    static let description =
        "Matchly helps medical students and physicians organize residency and fellowship interview information and generate personalized rank lists."
}

#Preview {
    MatchlyNavigationView {
        AboutMatchlyView()
    }
}
