//
//  WidgetSetupGuideSheet.swift
//  Matchly
//

import SwiftUI
import WidgetKit

struct WidgetSetupGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var widgetAlreadyAdded = false
    @State private var checkedForWidget = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("See your next interview on your Home Screen or Lock Screen without opening Matchly.")
                        .font(.arial(size: 15))
                        .foregroundColor(.secondary)

                    widgetPreview

                    VStack(alignment: .leading, spacing: 12) {
                        setupStep(number: 1, text: "Leave Matchly and go to your iPhone Home Screen")
                        setupStep(number: 2, text: "Touch and hold an empty area until the icons jiggle")
                        setupStep(number: 3, text: "Tap Edit, then Add Widget")
                        setupStep(number: 4, text: "Search for Matchly and choose a size")
                        setupStep(number: 5, text: "Tap Add Widget, then Done")
                    }

                    Text("Apple requires widgets to be added from the Home Screen — apps cannot install them automatically.")
                        .font(.arial(size: 13))
                        .foregroundColor(.secondary)

                    if widgetAlreadyAdded {
                        Label("Matchly widget detected on your Home Screen", systemImage: "checkmark.circle.fill")
                            .font(.arial(size: 14, weight: .medium))
                            .foregroundColor(.green)
                    } else if checkedForWidget {
                        Text("No Matchly widget found yet. Follow the steps above, then check again.")
                            .font(.arial(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Button(action: checkForWidget) {
                        Label("Check if Widget Is Added", systemImage: "arrow.clockwise")
                            .font(.arial(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.glass)
                }
                .padding(24)
            }
            .navigationTitle("Add Matchly Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            DataManager.shared.publishWidgetSnapshot()
        }
    }

    private var widgetPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preview")
                .font(.arial(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.primaryBlue)
                    Text("Upcoming Interviews")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Text("Tomorrow")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColors.primaryBlue)

                Text("Orlando Health")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)

                Text("Sat, Sep 7")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.dashboardCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.2), lineWidth: 1)
            }
        }
    }

    private func setupStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.arial(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(AppColors.primaryBlue))
            Text(text)
                .font(.arial(size: 15))
                .foregroundColor(.primary)
        }
    }

    private func checkForWidget() {
        checkedForWidget = true
        WidgetCenter.shared.getCurrentConfigurations { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let configurations):
                    widgetAlreadyAdded = configurations.contains { $0.kind == DataManager.widgetKind }
                case .failure:
                    widgetAlreadyAdded = false
                }
            }
        }
    }
}
