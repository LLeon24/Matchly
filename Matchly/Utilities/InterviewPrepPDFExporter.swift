//
//  InterviewPrepPDFExporter.swift
//  Matchly
//
//  Branded interview-prep sheet export, styled to match RankListPDFExporter.
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

        let data = renderer.pdfData { context in
            var state = PrepDrawState(
                pageRect: pageRect,
                margin: 44,
                context: context,
                configuration: configuration
            )
            state.drawDocument()
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

// MARK: - Drawing

private struct PrepDrawState {
    let pageRect: CGRect
    let margin: CGFloat
    let context: UIGraphicsPDFRendererContext
    let configuration: InterviewPrepPDFExporter.Configuration

    var contentWidth: CGFloat { pageRect.width - margin * 2 }
    var y: CGFloat = 0
    var pageNumber = 0

    mutating func drawDocument() {
        beginPage()
        drawHeader()

        if !configuration.priorityQuestions.isEmpty {
            drawSectionHeader(title: "Must-Ask Questions", accent: Colors.gold, icon: "star.fill")
            for (index, item) in configuration.priorityQuestions.enumerated() {
                drawQuestionCard(
                    question: item.question,
                    caption: "Must-Ask #\(index + 1)" + (item.sectionTitle.isEmpty ? "" : "  •  \(shortSectionTitle(item.sectionTitle))"),
                    checked: item.asked,
                    accent: Colors.gold,
                    showsAccentBar: true
                )
            }
        }

        if !configuration.otherSelectedQuestions.isEmpty {
            drawSectionHeader(title: "Questions to Ask", accent: Colors.green, icon: "text.bubble.fill")
            for item in configuration.otherSelectedQuestions {
                drawQuestionCard(
                    question: item.question,
                    caption: shortSectionTitle(item.sectionTitle),
                    checked: item.asked,
                    accent: Colors.green,
                    showsAccentBar: false
                )
            }
        }

        if !configuration.checklistItems.isEmpty {
            drawSectionHeader(title: "Day-Before Checklist", accent: Colors.brandBlue, icon: "checklist")
            for item in configuration.checklistItems {
                drawQuestionCard(
                    question: item.title,
                    caption: "",
                    checked: item.checked,
                    accent: Colors.brandBlue,
                    showsAccentBar: false
                )
            }
        }

        if let notes = configuration.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            drawSectionHeader(title: "Notes", accent: Colors.secondaryText, icon: "note.text")
            drawNotesCard(notes)
        }

        drawFooter()
    }

    // MARK: Page management

    mutating func beginPage() {
        context.beginPage()
        pageNumber += 1
        y = margin

        let background = UIBezierPath(rect: pageRect)
        Colors.pageBackground.setFill()
        background.fill()
    }

    mutating func ensureSpace(_ height: CGFloat) {
        let footerReserve: CGFloat = 36
        if y + height > pageRect.height - margin - footerReserve {
            drawFooter()
            beginPage()
        }
    }

    // MARK: Header

    mutating func drawHeader() {
        let hospital = HospitalNameFormatter.format(configuration.hospitalName)
        let metaLine = [configuration.specialty, configuration.location]
            .filter { !$0.isEmpty }
            .joined(separator: "  •  ")
        let dateLine: String? = configuration.interviewDate.map {
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            formatter.timeStyle = .short
            return "Interview: \(formatter.string(from: $0))"
        }

        let detailLineCount = 1 + (metaLine.isEmpty ? 0 : 1) + (dateLine == nil ? 0 : 1)
        let headerHeight: CGFloat = 88 + CGFloat(detailLineCount) * 16
        let headerRect = CGRect(x: margin, y: y, width: contentWidth, height: headerHeight)

        guard let cgContext = UIGraphicsGetCurrentContext() else { return }
        cgContext.saveGState()
        drawHeaderBackground(in: headerRect, cornerRadius: 14)

        let logoSize: CGFloat = 52
        let logoRect = CGRect(
            x: headerRect.minX + 18,
            y: headerRect.midY - logoSize / 2,
            width: logoSize,
            height: logoSize
        )
        if let image = UIImage(named: "MatchlyGlyph") {
            image.draw(in: logoRect)
        }

        let textX = logoRect.maxX + 14
        let textWidth = headerRect.maxX - textX - 12

        "MATCHLY".draw(
            at: CGPoint(x: textX, y: headerRect.minY + 18),
            withAttributes: [
                .font: Fonts.regular(17),
                .foregroundColor: Colors.primaryText,
                .kern: 3.5
            ]
        )
        "INTERVIEW PREP".draw(
            at: CGPoint(x: textX, y: headerRect.minY + 40),
            withAttributes: [
                .font: Fonts.regular(10),
                .foregroundColor: Colors.secondaryText,
                .kern: 1.4
            ]
        )

        var detailY = headerRect.minY + 58
        hospital.draw(
            in: CGRect(x: textX, y: detailY, width: textWidth, height: 14),
            withAttributes: [
                .font: Fonts.semibold(11),
                .foregroundColor: Colors.primaryText
            ]
        )
        detailY += 16

        if !metaLine.isEmpty {
            metaLine.draw(
                in: CGRect(x: textX, y: detailY, width: textWidth, height: 14),
                withAttributes: [
                    .font: Fonts.regular(10),
                    .foregroundColor: Colors.secondaryText
                ]
            )
            detailY += 16
        }

        if let dateLine {
            dateLine.draw(
                in: CGRect(x: textX, y: detailY, width: textWidth, height: 14),
                withAttributes: [
                    .font: Fonts.semibold(10),
                    .foregroundColor: Colors.brandBlue
                ]
            )
            detailY += 16
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        let questionCount = configuration.priorityQuestions.count + configuration.otherSelectedQuestions.count
        let meta = "Generated \(dateFormatter.string(from: configuration.generatedAt))  •  \(questionCount) question\(questionCount == 1 ? "" : "s")"
        meta.draw(
            in: CGRect(x: textX, y: headerRect.maxY - 20, width: textWidth, height: 16),
            withAttributes: [
                .font: Fonts.regular(9),
                .foregroundColor: Colors.secondaryText
            ]
        )

        cgContext.restoreGState()
        y += headerHeight + 16
    }

    func drawHeaderBackground(in rect: CGRect, cornerRadius: CGFloat) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        Colors.cardBackground.setFill()
        path.fill()

        Colors.headerBorder.setStroke()
        path.lineWidth = 0.5
        path.stroke()

        let accentRect = CGRect(
            x: rect.minX + 10,
            y: rect.minY + 12,
            width: 3,
            height: rect.height - 24
        )
        let accent = UIBezierPath(roundedRect: accentRect, cornerRadius: 1.5)
        Colors.brandBlue.setFill()
        accent.fill()
    }

    // MARK: Sections

    mutating func drawSectionHeader(title: String, accent: UIColor, icon: String) {
        ensureSpace(30)
        y += 4
        PDFSymbolRenderer.draw(
            systemName: icon,
            pointSize: 11,
            color: accent,
            in: CGRect(x: margin, y: y + 1, width: 14, height: 14)
        )
        title.draw(
            at: CGPoint(x: margin + 18, y: y),
            withAttributes: [
                .font: Fonts.semibold(12),
                .foregroundColor: accent
            ]
        )
        y += 22
    }

    // MARK: Cards

    mutating func drawQuestionCard(
        question: String,
        caption: String,
        checked: Bool,
        accent: UIColor,
        showsAccentBar: Bool
    ) {
        let questionAttributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.regular(10),
            .foregroundColor: Colors.primaryText
        ]
        let captionAttributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.semibold(7.5),
            .foregroundColor: Colors.secondaryText
        ]

        let textX: CGFloat = 34
        let textWidth = contentWidth - textX - 12
        let questionHeight = height(for: question, width: textWidth, attributes: questionAttributes)
        let captionHeight: CGFloat = caption.isEmpty ? 0 : 12
        let cardHeight = 10 + questionHeight + (captionHeight > 0 ? 3 + captionHeight : 0) + 10

        ensureSpace(cardHeight + 6)

        let rect = CGRect(x: margin, y: y, width: contentWidth, height: cardHeight)
        let card = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        Colors.cardBackground.setFill()
        card.fill()

        if showsAccentBar {
            let bar = UIBezierPath(
                roundedRect: CGRect(x: rect.minX, y: rect.minY, width: 3.5, height: rect.height),
                byRoundingCorners: [.topLeft, .bottomLeft],
                cornerRadii: CGSize(width: 8, height: 8)
            )
            accent.setFill()
            bar.fill()
        }

        drawCheckbox(at: CGPoint(x: rect.minX + 12, y: rect.minY + 10), checked: checked, accent: accent)

        question.draw(
            in: CGRect(x: rect.minX + textX, y: rect.minY + 10, width: textWidth, height: questionHeight + 2),
            withAttributes: questionAttributes
        )

        if !caption.isEmpty {
            caption.uppercased().draw(
                in: CGRect(
                    x: rect.minX + textX,
                    y: rect.minY + 10 + questionHeight + 3,
                    width: textWidth,
                    height: captionHeight
                ),
                withAttributes: captionAttributes
            )
        }

        y += cardHeight + 6
    }

    mutating func drawNotesCard(_ notes: String) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.regular(10),
            .foregroundColor: Colors.primaryText
        ]
        let textWidth = contentWidth - 24
        let textHeight = height(for: notes, width: textWidth, attributes: attributes)
        let cardHeight = 12 + textHeight + 12

        ensureSpace(cardHeight + 6)

        let rect = CGRect(x: margin, y: y, width: contentWidth, height: cardHeight)
        let card = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        Colors.cardBackground.setFill()
        card.fill()

        notes.draw(
            in: CGRect(x: rect.minX + 12, y: rect.minY + 12, width: textWidth, height: textHeight + 2),
            withAttributes: attributes
        )

        y += cardHeight + 6
    }

    func drawCheckbox(at origin: CGPoint, checked: Bool, accent: UIColor) {
        let rect = CGRect(x: origin.x, y: origin.y, width: 12, height: 12)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 3)
        if checked {
            accent.setFill()
            path.fill()
            PDFSymbolRenderer.draw(
                systemName: "checkmark",
                pointSize: 7,
                color: .white,
                in: rect.insetBy(dx: 2.5, dy: 2.5)
            )
        } else {
            Colors.checkboxBorder.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    // MARK: Footer

    mutating func drawFooter() {
        let footerY = pageRect.height - margin + 8
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.regular(9),
            .foregroundColor: Colors.secondaryText
        ]
        let left = "MATCHLY — INTERVIEW PREP"
        let right = "Page \(pageNumber)"
        left.draw(at: CGPoint(x: margin, y: footerY), withAttributes: attributes)
        let rightSize = right.size(withAttributes: attributes)
        right.draw(at: CGPoint(x: pageRect.width - margin - rightSize.width, y: footerY), withAttributes: attributes)
    }

    // MARK: Helpers

    func shortSectionTitle(_ title: String) -> String {
        if let range = title.range(of: " — ") {
            return String(title[range.upperBound...])
        }
        return title
    }

    func height(for text: String, width: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        let rect = CGRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude)
        return ceil(text.boundingRect(with: rect.size, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil).height)
    }
}

// MARK: - Symbol rendering

/// Renders SF Symbols crisply in PDF output (small direct draws often appear as solid blobs).
private enum PDFSymbolRenderer {
    static func draw(systemName: String, pointSize: CGFloat, color: UIColor, in rect: CGRect) {
        guard let image = renderedImage(systemName: systemName, pointSize: pointSize, color: color) else { return }
        image.draw(in: rect)
    }

    private static func renderedImage(systemName: String, pointSize: CGFloat, color: UIColor) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        guard let symbol = UIImage(systemName: systemName, withConfiguration: config) else {
            return nil
        }

        let size = symbol.size
        guard size.width > 0, size.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 4
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            symbol.withTintColor(color, renderingMode: .alwaysOriginal)
                .draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Style helpers (mirrors RankListPDFExporter)

private enum Colors {
    static let brandBlue = UIColor(red: 0.0, green: 0.48, blue: 0.65, alpha: 1.0)
    static let pageBackground = UIColor(white: 0.98, alpha: 1.0)
    static let cardBackground = UIColor.white
    static let headerBorder = UIColor(white: 0.82, alpha: 1.0)
    static let checkboxBorder = UIColor(white: 0.72, alpha: 1.0)
    static let primaryText = UIColor(white: 0.12, alpha: 1.0)
    static let secondaryText = UIColor(white: 0.45, alpha: 1.0)
    static let gold = UIColor(red: 0.85, green: 0.62, blue: 0.09, alpha: 1.0)
    static let green = UIColor(red: 0.18, green: 0.62, blue: 0.38, alpha: 1.0)
}

private enum Fonts {
    static func regular(_ size: CGFloat) -> UIFont {
        UIFont(name: "Arial", size: size) ?? .systemFont(ofSize: size)
    }

    static func semibold(_ size: CGFloat) -> UIFont {
        UIFont(name: "Arial-BoldMT", size: size) ?? .boldSystemFont(ofSize: size)
    }
}
