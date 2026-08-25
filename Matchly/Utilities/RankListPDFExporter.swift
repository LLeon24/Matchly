//
//  RankListPDFExporter.swift
//  Matchly
//

import UIKit
import SwiftUI

enum RankListPDFExporter {
    struct Configuration {
        let orderedPrograms: [Program]
        let applicantName: String?
        let aamcID: String?
        let generatedAt: Date

        init(
            orderedPrograms: [Program],
            applicantName: String? = nil,
            aamcID: String? = nil,
            generatedAt: Date = Date()
        ) {
            self.orderedPrograms = orderedPrograms
            self.applicantName = applicantName
            self.aamcID = aamcID
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

        let programs = configuration.orderedPrograms
        for (index, program) in programs.enumerated() {
            if shouldShowSpecialtyHeader(at: index, in: programs) {
                let specialty = program.specialty
                let displayName = specialty.isEmpty
                    ? "Programs"
                    : SpecialtyFormatter.displayNameWithAbbreviation(specialty)
                drawSectionHeader(title: displayName, accent: specialtyUIColor(for: specialty), icon: "stethoscope")
            }

            if shouldShowRedFlaggedBanner(at: index, in: programs) {
                y += 2
                drawSectionHeader(title: "Red Flagged Programs", accent: Colors.red, icon: "exclamationmark.triangle.fill")
            }

            let elevated = elevatedRedFlag(at: index, in: programs)
            drawProgramRow(
                rank: index + 1,
                program: program,
                isRedFlagged: program.hasRedFlags(),
                showsElevatedRedFlag: elevated
            )
        }

        drawFooter()
    }

    private func shouldShowSpecialtyHeader(at index: Int, in programs: [Program]) -> Bool {
        let program = programs[index]
        guard !program.hasRedFlags() else { return false }
        guard !program.specialty.isEmpty else { return false }
        if index == 0 { return true }
        let previous = programs[index - 1]
        if previous.hasRedFlags() { return true }
        return previous.specialty != program.specialty
    }

    private func shouldShowRedFlaggedBanner(at index: Int, in programs: [Program]) -> Bool {
        guard programs[index].hasRedFlags() else { return false }
        guard index > 0 else { return false }
        guard !programs[index - 1].hasRedFlags() else { return false }
        return programs[index...].allSatisfy { $0.hasRedFlags() }
    }

    private func elevatedRedFlag(at index: Int, in programs: [Program]) -> Bool {
        guard programs[index].hasRedFlags() else { return false }
        return programs[(index + 1)...].contains { !$0.hasRedFlags() }
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
        }
    }

    mutating func drawHeader() {
        let trimmedName = configuration.applicantName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedAAMC = configuration.aamcID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let applicantLineCount = (!trimmedName.isEmpty ? 1 : 0) + (!trimmedAAMC.isEmpty ? 1 : 0)
        let headerHeight: CGFloat = 88 + CGFloat(applicantLineCount) * 16
        let headerRect = CGRect(x: margin, y: y, width: contentWidth, height: headerHeight)

        guard let cgContext = UIGraphicsGetCurrentContext() else { return }
        cgContext.saveGState()
        drawExportHeaderBackground(in: headerRect, cornerRadius: 14)

        let logoSize: CGFloat = 52
        let logoRect = CGRect(
            x: headerRect.minX + 18,
            y: headerRect.midY - logoSize / 2,
            width: logoSize,
            height: logoSize
        )
        drawMatchlyLogo(in: logoRect)

        let textX = logoRect.maxX + 14
        let textWidth = headerRect.maxX - textX - 12
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.regular(17),
            .foregroundColor: Colors.primaryText,
            .kern: 3.5
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.regular(10),
            .foregroundColor: Colors.secondaryText,
            .kern: 1.4
        ]
        let applicantAttributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.semibold(11),
            .foregroundColor: Colors.primaryText
        ]
        let aamcAttributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.regular(10),
            .foregroundColor: Colors.secondaryText
        ]

        "MATCHLY".draw(at: CGPoint(x: textX, y: headerRect.minY + 18), withAttributes: titleAttributes)
        "RESIDENCY RANK LIST".draw(at: CGPoint(x: textX, y: headerRect.minY + 40), withAttributes: subtitleAttributes)

        var detailY = headerRect.minY + 58
        if !trimmedName.isEmpty {
            trimmedName.draw(
                in: CGRect(x: textX, y: detailY, width: textWidth, height: 14),
                withAttributes: applicantAttributes
            )
            detailY += 16
        }
        if !trimmedAAMC.isEmpty {
            "AAMC ID: \(trimmedAAMC)".draw(
                in: CGRect(x: textX, y: detailY, width: textWidth, height: 14),
                withAttributes: aamcAttributes
            )
            detailY += 16
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        let totalCount = configuration.orderedPrograms.count
        let meta = "Generated \(dateFormatter.string(from: configuration.generatedAt))  •  \(totalCount) program\(totalCount == 1 ? "" : "s")"
        let metaAttributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.regular(9),
            .foregroundColor: Colors.secondaryText
        ]
        let metaRect = CGRect(x: textX, y: headerRect.maxY - 20, width: textWidth, height: 16)
        meta.draw(in: metaRect, withAttributes: metaAttributes)

        cgContext.restoreGState()
        y += headerHeight + 16
    }

    mutating func drawSectionHeader(title: String, accent: UIColor, icon: String) {
        ensureSpace(30)
        y += 4
        PDFSymbolRenderer.draw(
            systemName: icon,
            pointSize: 11,
            color: accent,
            in: CGRect(x: margin, y: y + 1, width: 14, height: 14)
        )
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.semibold(12),
            .foregroundColor: accent
        ]
        title.draw(at: CGPoint(x: margin + 18, y: y), withAttributes: attributes)
        y += 22
    }

    mutating func drawProgramRow(rank: Int, program: Program, isRedFlagged: Bool, showsElevatedRedFlag: Bool = false) {
        let hospital = HospitalNameFormatter.format(
            program.hospital.isEmpty ? (program.name.isEmpty ? "Unnamed Program" : program.name) : program.hospital
        )
        let location = formattedLocation(for: program)
        let metaLine = formattedMetaLine(for: program, isRedFlagged: isRedFlagged)

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.semibold(11),
            .foregroundColor: Colors.primaryText
        ]
        let metaAttributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.regular(9),
            .foregroundColor: Colors.secondaryText
        ]
        let scoreAttributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.bold(13),
            .foregroundColor: scoreUIColor(program.finalScore)
        ]
        let ptsAttributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.regular(8),
            .foregroundColor: Colors.secondaryText
        ]

        let badgeColumnWidth: CGFloat = 56
        let titleWidth = contentWidth - badgeColumnWidth - 24
        let titleHeight = height(for: hospital, width: titleWidth, attributes: titleAttributes)
        let metaHeight = metaLine.isEmpty ? 0 : height(for: metaLine, width: titleWidth, attributes: metaAttributes) + 2
        let specialtyPillHeight: CGFloat = program.specialty.isEmpty ? 0 : 18
        let rowHeight = max(showsElevatedRedFlag ? 92 : 78, 14 + titleHeight + specialtyPillHeight + metaHeight + 14)

        ensureSpace(rowHeight + 6)

        let rect = CGRect(x: margin, y: y, width: contentWidth, height: rowHeight)
        let background = UIBezierPath(roundedRect: rect, cornerRadius: 10)
        Colors.cardBackground.setFill()
        background.fill()

        if isRedFlagged {
            let accent = UIBezierPath(
                roundedRect: CGRect(x: rect.minX, y: rect.minY, width: 4, height: rect.height),
                byRoundingCorners: [.topLeft, .bottomLeft],
                cornerRadii: CGSize(width: 10, height: 10)
            )
            (showsElevatedRedFlag ? Colors.red : Colors.red.withAlphaComponent(0.85)).setFill()
            accent.fill()
        }

        if showsElevatedRedFlag {
            let bannerRect = CGRect(x: rect.minX + 8, y: rect.minY + 6, width: contentWidth - 16, height: 14)
            let banner = UIBezierPath(roundedRect: bannerRect, cornerRadius: 4)
            Colors.red.withAlphaComponent(0.08).setFill()
            banner.fill()
            let bannerAttributes: [NSAttributedString.Key: Any] = [
                .font: Fonts.semibold(8),
                .foregroundColor: Colors.red.withAlphaComponent(0.9)
            ]
            "Flagged program".draw(
                in: bannerRect.insetBy(dx: 6, dy: 2),
                withAttributes: bannerAttributes
            )
        }

        let badgeOriginY = rect.minY + (showsElevatedRedFlag ? 24 : 10)
        _ = drawRankBadgeColumn(rank: rank, originX: rect.minX + 8, originY: badgeOriginY)

        let scoreText = String(format: "%.1f", program.finalScore)
        let scoreSize = scoreText.size(withAttributes: scoreAttributes)
        let scoreCenterX = rect.minX + 8 + badgeColumnWidth / 2
        let scoreY = badgeOriginY + 52
        scoreText.draw(
            at: CGPoint(x: scoreCenterX - scoreSize.width / 2, y: scoreY),
            withAttributes: scoreAttributes
        )
        let ptsText = "pts"
        let ptsSize = ptsText.size(withAttributes: ptsAttributes)
        ptsText.draw(
            at: CGPoint(x: scoreCenterX - ptsSize.width / 2, y: scoreY + 14),
            withAttributes: ptsAttributes
        )

        var textY = rect.minY + (showsElevatedRedFlag ? 24 : 12)
        let textX = rect.minX + badgeColumnWidth + 12
        hospital.draw(
            in: CGRect(x: textX, y: textY, width: titleWidth, height: titleHeight + 2),
            withAttributes: titleAttributes
        )
        textY += titleHeight + 4

        if !program.specialty.isEmpty {
            let pillWidth = drawSpecialtyPill(
                specialty: program.specialty,
                origin: CGPoint(x: textX, y: textY)
            )
            textY += specialtyPillHeight + 4
            _ = pillWidth
        }

        if !metaLine.isEmpty {
            metaLine.draw(
                in: CGRect(x: textX, y: textY, width: titleWidth, height: metaHeight),
                withAttributes: metaAttributes
            )
        }

        if !location.isEmpty && location != "—" {
            let locationAttributes: [NSAttributedString.Key: Any] = [
                .font: Fonts.regular(9),
                .foregroundColor: Colors.secondaryText
            ]
            let locationSize = location.size(withAttributes: locationAttributes)
            location.draw(
                at: CGPoint(x: rect.maxX - locationSize.width - 12, y: rect.minY + 12),
                withAttributes: locationAttributes
            )
        }

        y += rowHeight + 6
    }

    @discardableResult
    func drawRankBadgeColumn(rank: Int, originX: CGFloat, originY: CGFloat) -> CGFloat {
        let columnWidth: CGFloat = 56
        let circleCenter = CGPoint(x: originX + columnWidth / 2, y: originY + 22)
        let radius: CGFloat = 22
        let badgeColor = rankUIColor(rank)

        let circle = UIBezierPath(
            arcCenter: circleCenter,
            radius: radius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        )
        badgeColor.withAlphaComponent(0.15).setFill()
        circle.fill()

        let symbolName = rank <= 3 ? "trophy.fill" : "star.fill"
        let iconSize: CGFloat = 12
        PDFSymbolRenderer.draw(
            systemName: symbolName,
            pointSize: 11,
            color: badgeColor,
            in: CGRect(
                x: circleCenter.x - iconSize / 2,
                y: circleCenter.y - 13,
                width: iconSize,
                height: iconSize
            )
        )

        let rankAttributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.bold(14),
            .foregroundColor: badgeColor
        ]
        let rankText = "\(rank)"
        let rankSize = rankText.size(withAttributes: rankAttributes)
        rankText.draw(
            at: CGPoint(x: circleCenter.x - rankSize.width / 2, y: circleCenter.y + 1),
            withAttributes: rankAttributes
        )

        return columnWidth
    }

    @discardableResult
    func drawSpecialtyPill(specialty: String, origin: CGPoint) -> CGFloat {
        let accent = specialtyUIColor(for: specialty)
        let abbrev = SpecialtyFormatter.abbreviation(for: specialty)
        let text = "  \(abbrev)  "
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.semibold(8),
            .foregroundColor: accent
        ]
        let textSize = text.size(withAttributes: attributes)
        let pillRect = CGRect(x: origin.x, y: origin.y, width: textSize.width + 8, height: 16)
        let pill = UIBezierPath(roundedRect: pillRect, cornerRadius: 4)
        accent.withAlphaComponent(0.15).setFill()
        pill.fill()
        text.draw(at: CGPoint(x: origin.x + 4, y: origin.y + 2), withAttributes: attributes)
        return pillRect.width
    }

    func drawExportHeaderBackground(in rect: CGRect, cornerRadius: CGFloat) {
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

    func drawBrandGradient(in rect: CGRect, cornerRadius: CGFloat) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        path.addClip()
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let colors = [Colors.brandBlue.cgColor, Colors.brandTeal.cgColor] as CFArray
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 1]
        ) else { return }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.maxX, y: rect.maxY),
            options: []
        )
    }

    func drawMatchlyLogo(in rect: CGRect) {
        guard let image = UIImage(named: "MatchlyGlyph") else { return }
        image.draw(in: rect)
    }

    mutating func drawFooter() {
        let footerY = pageRect.height - margin + 8
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.regular(9),
            .foregroundColor: Colors.secondaryText
        ]
        let left = "MATCHLY — CONFIDENTIAL RANK LIST"
        let right = "Page \(pageNumber)"
        left.draw(at: CGPoint(x: margin, y: footerY), withAttributes: attributes)
        let rightSize = right.size(withAttributes: attributes)
        right.draw(at: CGPoint(x: pageRect.width - margin - rightSize.width, y: footerY), withAttributes: attributes)
    }

    func formattedLocation(for program: Program) -> String {
        if program.hasDisplayLocation {
            return program.displayCityState
        }
        if !program.state.isEmpty { return program.state }
        if !program.city.isEmpty { return program.city }
        return "—"
    }

    func formattedMetaLine(for program: Program, isRedFlagged: Bool) -> String {
        var parts: [String] = []
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

// MARK: - Style helpers

private enum Colors {
    static let brandBlue = UIColor(red: 0.0, green: 0.48, blue: 0.65, alpha: 1.0)
    static let brandTeal = UIColor(red: 0.2, green: 0.7, blue: 0.8, alpha: 1.0)
    static let pageBackground = UIColor(white: 0.98, alpha: 1.0)
    static let cardBackground = UIColor.white
    static let headerBorder = UIColor(white: 0.82, alpha: 1.0)
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
