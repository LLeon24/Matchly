//
//  InterviewDateSchedulingContent.swift
//  Matchly
//

import SwiftUI

struct InterviewDateSchedulingContent: View {
    let programTitle: String
    var institutionSubtitle: String?
    var locationLine: String?
    @Binding var interviewDate: Date

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(programTitle)
                        .font(.arial(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let institutionSubtitle, !institutionSubtitle.isEmpty {
                        Text(institutionSubtitle)
                            .font(.arial(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let locationLine, !locationLine.isEmpty {
                        Label(locationLine, systemImage: "mappin.circle.fill")
                            .font(.arial(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Date")
                        .font(.arial(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    DatePicker(
                        "Interview date",
                        selection: $interviewDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }
                .padding(14)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Time")
                        .font(.arial(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    DatePicker(
                        "Interview time",
                        selection: $interviewDate,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipped()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }
}
