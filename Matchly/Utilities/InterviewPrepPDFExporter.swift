//
//  InterviewPrepPDFExporter.swift
//  Matchly
//

import UIKit

enum InterviewPrepPDFExporter {
    struct Configuration {
        let hospitalName: String
        let specialty: String
        let location: String
        let interviewDate: Date?
        let priorityQuestions: [(sectionTitle: String, question: String, asked: Bool)]
        let otherSelectedQuestions: [(sectionTitle: String, question: String, asked: Bool)]
        let checklistItems: [(title: String, checked: Bool)]
        let notes: String?
        let generatedAt: Date
    }

    static func temporaryFileURL(hospitalName: String, generatedAt: Date = Date()) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let stamp = formatter.string(from: generatedAt)
        let safeName = hospitalName
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("Matchly_Interview_Prep_\(safeName)_\(stamp).pdf")
    }

    static func generatePDF(configuration: Configuration) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let margin: CGFloat = 44
        let contentWidth = pageRect.width - margin * 2

        let data = renderer.pdfData { context in
            var y = margin

            func beginPageIfNeeded(requiredHeight: CGFloat) {
                if y + requiredHeight > pageRect.height - margin {
                    context.beginPage()
                    y = margin
                }
            }

            func drawLine(_ height: CGFloat = 18) {
                beginPageIfNeeded(requiredHeight: height)
                y += height
            }

            func drawTitle(_ text: String) {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 22),
                    .foregroundColor: UIColor.black
                ]
                let rect = CGRect(x: margin, y: y, width: contentWidth, height: 28)
                beginPageIfNeeded(requiredHeight: 32)
                (text as NSString).draw(in: rect, withAttributes: attrs)
                y += 30
            }

            func drawSubtitle(_ text: String) {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.darkGray
                ]
                let rect = CGRect(x: margin, y: y, width: contentWidth, height: 16)
                beginPageIfNeeded(requiredHeight: 20)
                (text as NSString).draw(in: rect, withAttributes: attrs)
                y += 18
            }

            func drawSectionHeader(_ text: String) {
                drawLine(8)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 14),
                    .foregroundColor: UIColor.black
                ]
                let rect = CGRect(x: margin, y: y, width: contentWidth, height: 18)
                beginPageIfNeeded(requiredHeight: 22)
                (text as NSString).draw(in: rect, withAttributes: attrs)
                y += 22
            }

            func drawWrappedText(_ text: String, prefix: String = "• ", fontSize: CGFloat = 12) {
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineBreakMode = .byWordWrapping
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: fontSize),
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: paragraph
                ]
                let full = prefix + text
                let bounding = (full as NSString).boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attrs,
                    context: nil
                )
                beginPageIfNeeded(requiredHeight: bounding.height + 6)
                (full as NSString).draw(
                    in: CGRect(x: margin, y: y, width: contentWidth, height: ceil(bounding.height)),
                    withAttributes: attrs
                )
                y += ceil(bounding.height) + 6
            }

            context.beginPage()

            drawTitle("Interview Prep")
            drawSubtitle(configuration.hospitalName)
            if !configuration.specialty.isEmpty {
                drawSubtitle(configuration.specialty)
            }
            if !configuration.location.isEmpty {
                drawSubtitle(configuration.location)
            }
            if let date = configuration.interviewDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .full
                formatter.timeStyle = .short
                drawSubtitle(formatter.string(from: date))
            }

            if !configuration.priorityQuestions.isEmpty {
                drawSectionHeader("Top Must-Ask Questions")
                for (index, item) in configuration.priorityQuestions.enumerated() {
                    let marker = item.asked ? "☑" : "☐"
                    drawWrappedText(item.question, prefix: "\(marker) \(index + 1). ")
                }
            }

            if !configuration.otherSelectedQuestions.isEmpty {
                drawSectionHeader("Other Selected Questions")
                for item in configuration.otherSelectedQuestions {
                    let marker = item.asked ? "☑" : "☐"
                    drawWrappedText(item.question, prefix: "\(marker) ")
                }
            }

            if !configuration.checklistItems.isEmpty {
                drawSectionHeader("Day-Before Checklist")
                for item in configuration.checklistItems {
                    let marker = item.checked ? "☑" : "☐"
                    drawWrappedText(item.title, prefix: "\(marker) ")
                }
            }

            if let notes = configuration.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                drawSectionHeader("Notes")
                drawWrappedText(notes, prefix: "")
            }

            let footerFormatter = DateFormatter()
            footerFormatter.dateStyle = .medium
            footerFormatter.timeStyle = .short
            drawLine(12)
            drawSubtitle("Generated by Matchly · \(footerFormatter.string(from: configuration.generatedAt))")
        }

        let url = temporaryFileURL(hospitalName: configuration.hospitalName, generatedAt: configuration.generatedAt)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
