//
//  RankListPDFExporter.swift
//  Matchly
//

import UIKit

enum RankListPDFExporter {
    struct Configuration {
        let programs: [Program]
        let redFlaggedPrograms: [Program]
        let applicantName: String?
        let generatedAt: Date

        init(
            programs: [Program],
            redFlaggedPrograms: [Program] = [],
            applicantName: String? = nil,
            generatedAt: Date = Date()
        ) {
            self.programs = programs
            self.redFlaggedPrograms = redFlaggedPrograms
            self.applicantName = applicantName
            self.generatedAt = generatedAt
        }
    }

    static func temporaryFileURL(generatedAt: Date = Date()) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let stamp = formatter.string(from: generatedAt)
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("Matchly_Rank_List_\(stamp).pdf")
    }

    static func generatePDF(configuration: Configuration) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            var state = DrawState(
                pageRect: pageRect,
                margin: 44,
                context: context,
                configuration: configuration
            )
            state.drawDocument()
        }

        let url = temporaryFileURL(generatedAt: configuration.generatedAt)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - Drawing

private struct DrawState {
    let pageRect: CGRect
    let margin: CGFloat
    let context: UIGraphicsPDFRendererContext
    let configuration: RankListPDFExporter.Configuration

    var contentWidth: CGFloat { pageRect.width - margin * 2 }
    var y: CGFloat = 0
    var pageNumber = 0

    mutating func drawDocument() {
        beginPage()
        drawHeader()
        drawTableHeader()

        for (index, program) in configuration.programs.enumerated() {
            drawProgramRow(rank: index + 1, program: program, isRedFlagged: false)
        }

        if !configuration.redFlaggedPrograms.isEmpty {
            drawSectionTitle("Red Flagged Programs", color: Colors.red)
            for (index, program) in configuration.redFlaggedPrograms.enumerated() {
                let rank = configuration.programs.count + index + 1
                drawProgramRow(rank: rank, program: program, isRedFlagged: true)
            }
        }

        drawFooter()
    }

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
            drawTableHeader()
        }
    }

    mutating func drawHeader() {
        let headerHeight: CGFloat = 92
        let headerRect = CGRect(x: margin, y: y, width: contentWidth, height: headerHeight)
        let path = UIBezierPath(roundedRect: headerRect, cornerRadius: 12)
        Colors.brandBlue.setFill()
        path.fill()

        let title = "Matchly"
        let subtitle = "Residency Rank List"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.bold(22),
            .foregroundColor: UIColor.white
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.regular(13),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]
        title.draw(at: CGPoint(x: headerRect.minX + 18, y: headerRect.minY + 16), withAttributes: titleAttributes)
        subtitle.draw(at: CGPoint(x: headerRect.minX + 18, y: headerRect.minY + 44), withAttributes: subtitleAttributes)

        var metaLines: [String] = []
        let trimmedName = configuration.applicantName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedName.isEmpty {
            metaLines.append(trimmedName)
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        metaLines.append("Generated \(dateFormatter.string(from: configuration.generatedAt))")
        let totalCount = configuration.programs.count + configuration.redFlaggedPrograms.count
        metaLines.append("\(totalCount) program\(totalCount == 1 ? "" : "s")")

        let meta = metaLines.joined(separator: "  •  ")
        let metaAttributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.regular(10),
            .foregroundColor: UIColor.white.withAlphaComponent(0.85)
        ]
        let metaRect = CGRect(x: headerRect.minX + 18, y: headerRect.maxY - 24, width: headerRect.width - 36, height: 16)
        meta.draw(in: metaRect, withAttributes: metaAttributes)

        y += headerHeight + 18
    }

    mutating func drawTableHeader() {
        ensureSpace(28)
        let rowHeight: CGFloat = 24
        let rect = CGRect(x: margin, y: y, width: contentWidth, height: rowHeight)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 6)
        Colors.tableHeaderBackground.setFill()
        path.fill()

        drawColumnHeaders(in: rect)
        y += rowHeight + 6
    }

    func drawColumnHeaders(in rect: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.semibold(10),
            .foregroundColor: Colors.secondaryText
        ]
        "Rank".draw(in: CGRect(x: rect.minX + 10, y: rect.minY + 6, width: 34, height: 14), withAttributes: attributes)
        "Program".draw(in: CGRect(x: rect.minX + 48, y: rect.minY + 6, width: 280, height: 14), withAttributes: attributes)
        "Location".draw(in: CGRect(x: rect.minX + 330, y: rect.minY + 6, width: 150, height: 14), withAttributes: attributes)
        "Score".draw(in: CGRect(x: rect.maxX - 58, y: rect.minY + 6, width: 48, height: 14), withAttributes: attributes)
    }

    mutating func drawSectionTitle(_ title: String, color: UIColor) {
        ensureSpace(34)
        y += 8
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.semibold(12),
            .foregroundColor: color
        ]
        title.draw(at: CGPoint(x: margin, y: y), withAttributes: attributes)
        y += 22
    }

    mutating func drawProgramRow(rank: Int, program: Program, isRedFlagged: Bool) {
        let hospital = HospitalNameFormatter.format(
            program.hospital.isEmpty ? (program.name.isEmpty ? "Unnamed Program" : program.name) : program.hospital
        )
        let location = formattedLocation(for: program)
        let detail = formattedDetailLine(for: program, isRedFlagged: isRedFlagged)

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.semibold(11),
            .foregroundColor: Colors.primaryText
        ]
        let detailAttributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.regular(9),
            .foregroundColor: Colors.secondaryText
        ]
        let locationAttributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.regular(10),
            .foregroundColor: Colors.secondaryText
        ]
        let scoreAttributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.bold(12),
            .foregroundColor: scoreUIColor(program.finalScore)
        ]
        let rankAttributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.bold(13),
            .foregroundColor: rankUIColor(rank)
        ]

        let titleHeight = height(for: hospital, width: 270, attributes: titleAttributes)
        let detailHeight = detail.isEmpty ? 0 : height(for: detail, width: 270, attributes: detailAttributes) + 2
        let rowHeight = max(44, titleHeight + detailHeight + 16)

        ensureSpace(rowHeight + 4)

        let rect = CGRect(x: margin, y: y, width: contentWidth, height: rowHeight)
        let background = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        (rank % 2 == 0 ? Colors.rowBackgroundEven : Colors.rowBackgroundOdd).setFill()
        background.fill()

        if isRedFlagged {
            let accent = UIBezierPath(
                roundedRect: CGRect(x: rect.minX, y: rect.minY, width: 4, height: rect.height),
                cornerRadius: 2
            )
            Colors.red.setFill()
            accent.fill()
        }

        "\(rank)".draw(
            in: CGRect(x: rect.minX + 10, y: rect.minY + 12, width: 30, height: 18),
            withAttributes: rankAttributes
        )

        hospital.draw(
            in: CGRect(x: rect.minX + 48, y: rect.minY + 10, width: 270, height: titleHeight + 2),
            withAttributes: titleAttributes
        )

        if !detail.isEmpty {
            detail.draw(
                in: CGRect(x: rect.minX + 48, y: rect.minY + 12 + titleHeight, width: 270, height: detailHeight),
                withAttributes: detailAttributes
            )
        }

        location.draw(
            in: CGRect(x: rect.minX + 330, y: rect.minY + 12, width: 150, height: rowHeight - 16),
            withAttributes: locationAttributes
        )

        NSString(format: "%.1f", program.finalScore).draw(
            in: CGRect(x: rect.maxX - 58, y: rect.minY + 12, width: 48, height: 18),
            withAttributes: scoreAttributes
        )

        y += rowHeight + 4
    }

    mutating func drawFooter() {
        let footerY = pageRect.height - margin + 8
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.regular(9),
            .foregroundColor: Colors.secondaryText
        ]
        let left = "Matchly — Confidential rank list"
        let right = "Page \(pageNumber)"
        left.draw(at: CGPoint(x: margin, y: footerY), withAttributes: attributes)
        let rightSize = right.size(withAttributes: attributes)
        right.draw(at: CGPoint(x: pageRect.width - margin - rightSize.width, y: footerY), withAttributes: attributes)
    }

    func formattedLocation(for program: Program) -> String {
        if !program.city.isEmpty, !program.state.isEmpty {
            return "\(program.city), \(program.state)"
        }
        if !program.state.isEmpty { return program.state }
        if !program.city.isEmpty { return program.city }
        return "—"
    }

    func formattedDetailLine(for program: Program, isRedFlagged: Bool) -> String {
        var parts: [String] = []
        if !program.specialty.isEmpty {
            parts.append(SpecialtyFormatter.displayNameWithAbbreviation(program.specialty))
        }
        if let acgmeID = program.accreditationID, !acgmeID.isEmpty {
            parts.append("ID \(acgmeID)")
        }
        if program.signalType != .none {
            let isTiered = SignalLimits.isTiered(for: program.specialty)
            if isTiered {
                parts.append(program.signalType == .gold ? "Gold Signal" : "Silver Signal")
            } else {
                parts.append("Signal")
            }
        }
        if isRedFlagged || program.hasRedFlags() {
            parts.append("Red Flag")
        }
        let imgDisplay = IMGStatusDisplay.forSavedProgram(program)
        if imgDisplay != .none {
            parts.append(imgDisplay.label)
        }
        return parts.joined(separator: "  •  ")
    }

    func height(for text: String, width: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        let rect = CGRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude)
        return ceil(text.boundingRect(with: rect.size, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil).height)
    }
}

// MARK: - Style helpers

private enum Colors {
    static let brandBlue = UIColor(red: 0.0, green: 0.48, blue: 0.65, alpha: 1.0)
    static let pageBackground = UIColor.white
    static let tableHeaderBackground = UIColor(white: 0.94, alpha: 1.0)
    static let rowBackgroundEven = UIColor(white: 0.97, alpha: 1.0)
    static let rowBackgroundOdd = UIColor.white
    static let primaryText = UIColor(white: 0.12, alpha: 1.0)
    static let secondaryText = UIColor(white: 0.45, alpha: 1.0)
    static let red = UIColor.systemRed
}

private enum Fonts {
    static func regular(_ size: CGFloat) -> UIFont {
        UIFont(name: "Arial", size: size) ?? .systemFont(ofSize: size)
    }

    static func semibold(_ size: CGFloat) -> UIFont {
        UIFont(name: "Arial-BoldMT", size: size) ?? .boldSystemFont(ofSize: size)
    }

    static func bold(_ size: CGFloat) -> UIFont {
        UIFont(name: "Arial-BoldMT", size: size) ?? .boldSystemFont(ofSize: size)
    }
}

private func scoreUIColor(_ score: Double) -> UIColor {
    if score >= 80 { return .systemGreen }
    if score >= 60 { return Colors.brandBlue }
    if score >= 40 { return .systemOrange }
    return .systemRed
}

private func rankUIColor(_ rank: Int) -> UIColor {
    if rank <= 3 { return .systemGreen }
    if rank <= 10 { return Colors.brandBlue }
    return Colors.secondaryText
}
