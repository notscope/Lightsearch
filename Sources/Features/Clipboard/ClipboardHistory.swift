//
//  ClipboardHistory.swift
//  Lightsearch
//
// Local clipboard history models, pasteboard import/export, and encrypted
// persistence. Clipboard contents never leave this process or the local
// encrypted history file.

import AppKit
import CryptoKit
import Foundation
import ImageIO
import Security

enum ClipboardColorCodec {
    nonisolated static func normalizedHex(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits: String
        if trimmedValue.hasPrefix("#") {
            digits = String(trimmedValue.dropFirst())
        } else if trimmedValue.lowercased().hasPrefix("0x") {
            digits = String(trimmedValue.dropFirst(2))
        } else {
            return nil
        }

        guard [3, 4, 6, 8].contains(digits.count),
              digits.allSatisfy(\.isHexDigit) else {
            return nil
        }

        let expandedDigits: String
        switch digits.count {
        case 3, 4:
            expandedDigits = digits.map { "\($0)\($0)" }.joined()
        default:
            expandedDigits = digits
        }
        return "#" + expandedDigits.uppercased()
    }

    nonisolated static func color(fromHex value: String) -> NSColor? {
        guard let hex = normalizedHex(value) else { return nil }
        let digits = String(hex.dropFirst())
        let components = stride(from: 0, to: digits.count, by: 2).compactMap { index -> UInt8? in
            let start = digits.index(digits.startIndex, offsetBy: index)
            let end = digits.index(start, offsetBy: 2)
            return UInt8(digits[start..<end], radix: 16)
        }
        guard components.count == 3 || components.count == 4 else { return nil }

        return NSColor(
            srgbRed: CGFloat(components[0]) / 255,
            green: CGFloat(components[1]) / 255,
            blue: CGFloat(components[2]) / 255,
            alpha: CGFloat(components.count == 4 ? components[3] : 255) / 255
        )
    }

    nonisolated static func hex(from color: NSColor) -> String? {
        guard let color = color.usingColorSpace(.sRGB) else { return nil }

        let components = [
            color.redComponent,
            color.greenComponent,
            color.blueComponent,
            color.alphaComponent
        ].map { component in
            UInt8((min(max(component, 0), 1) * 255).rounded())
        }
        let rgbHex = components.prefix(3).map { String(format: "%02X", $0) }.joined()
        guard components[3] < 255 else { return "#" + rgbHex }
        return "#" + rgbHex + String(format: "%02X", components[3])
    }
}

enum ClipboardThumbnailGenerator {
    nonisolated static func makeThumbnail(
        from data: Data,
        maxPixelSize: Int = 160
    ) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgThumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgThumbnail)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.82])
            ?? bitmapRep.representation(using: .png, properties: [:])
    }

    nonisolated static func downsampleToThumbnail(
        from data: Data,
        maxPixelSize: Int = 96
    ) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgThumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgThumbnail, size: NSSize(width: cgThumbnail.width, height: cgThumbnail.height))
    }
}

enum ClipboardEntryKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case text
    case link
    case image
    case file
    case color

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text:
            return "Text"
        case .link:
            return "Link"
        case .image:
            return "Image"
        case .file:
            return "File"
        case .color:
            return "Color"
        }
    }

    var systemImageName: String {
        switch self {
        case .text:
            return "doc.text"
        case .link:
            return "link"
        case .image:
            return "photo"
        case .file:
            return "doc"
        case .color:
            return "eyedropper"
        }
    }
}

enum ClipboardFilter: String, CaseIterable, Codable, Identifiable, Sendable {
    case all
    case text
    case link
    case image
    case file
    case color

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All Types"
        case .text:
            return "Text"
        case .link:
            return "Links"
        case .image:
            return "Images"
        case .file:
            return "Files"
        case .color:
            return "Colors"
        }
    }

    var systemImageName: String {
        entryKind?.systemImageName ?? "list.bullet"
    }

    var entryKind: ClipboardEntryKind? {
        switch self {
        case .all:
            return nil
        case .text:
            return .text
        case .link:
            return .link
        case .image:
            return .image
        case .file:
            return .file
        case .color:
            return .color
        }
    }
}

struct ClipboardSource: Codable, Hashable, Sendable {
    let name: String
    let bundleIdentifier: String?
    let bundlePath: String?

    static let lightsearch = ClipboardSource(
        name: "Lightsearch",
        bundleIdentifier: Bundle.main.bundleIdentifier,
        bundlePath: Bundle.main.bundleURL.path
    )

    var displayName: String {
        name.isEmpty ? "Unknown Application" : name
    }
}

struct ClipboardPayload: Codable, Hashable, Sendable {
    let plainText: String?
    let urlData: Data?
    let rtfData: Data?
    let htmlData: Data?
    let imageData: Data?
    let thumbnailData: Data?
    let imageType: String?
    let colorHex: String?
    let filePaths: [String]

    init(
        plainText: String? = nil,
        urlData: Data? = nil,
        rtfData: Data? = nil,
        htmlData: Data? = nil,
        imageData: Data? = nil,
        thumbnailData: Data? = nil,
        imageType: String? = nil,
        colorHex: String? = nil,
        filePaths: [String] = []
    ) {
        self.plainText = plainText
        self.urlData = urlData
        self.rtfData = rtfData
        self.htmlData = htmlData
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.imageType = imageType
        self.colorHex = colorHex
        self.filePaths = filePaths
    }

    enum CodingKeys: String, CodingKey {
        case plainText
        case urlData
        case rtfData
        case htmlData
        case imageData
        case thumbnailData
        case imageType
        case colorHex
        case filePaths
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        plainText = try container.decodeIfPresent(String.self, forKey: .plainText)
        urlData = try container.decodeIfPresent(Data.self, forKey: .urlData)
        rtfData = try container.decodeIfPresent(Data.self, forKey: .rtfData)
        htmlData = try container.decodeIfPresent(Data.self, forKey: .htmlData)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        thumbnailData = try container.decodeIfPresent(Data.self, forKey: .thumbnailData)
        imageType = try container.decodeIfPresent(String.self, forKey: .imageType)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
        filePaths = try container.decodeIfPresent([String].self, forKey: .filePaths) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(plainText, forKey: .plainText)
        try container.encodeIfPresent(urlData, forKey: .urlData)
        try container.encodeIfPresent(rtfData, forKey: .rtfData)
        try container.encodeIfPresent(htmlData, forKey: .htmlData)
        try container.encodeIfPresent(imageData, forKey: .imageData)
        try container.encodeIfPresent(thumbnailData, forKey: .thumbnailData)
        try container.encodeIfPresent(imageType, forKey: .imageType)
        try container.encodeIfPresent(colorHex, forKey: .colorHex)
        if !filePaths.isEmpty {
            try container.encode(filePaths, forKey: .filePaths)
        }
    }

    var hasContent: Bool {
        plainText != nil
            || urlData != nil
            || rtfData != nil
            || htmlData != nil
            || imageData != nil
            || thumbnailData != nil
            || colorHex != nil
            || !filePaths.isEmpty
    }

    func withoutImageData(thumbnailData: Data? = nil) -> ClipboardPayload {
        ClipboardPayload(
            plainText: plainText,
            urlData: urlData,
            rtfData: rtfData,
            htmlData: htmlData,
            imageData: nil,
            thumbnailData: thumbnailData ?? self.thumbnailData,
            imageType: imageType,
            colorHex: colorHex,
            filePaths: filePaths
        )
    }

    func withImageData(_ imageData: Data) -> ClipboardPayload {
        ClipboardPayload(
            plainText: plainText,
            urlData: urlData,
            rtfData: rtfData,
            htmlData: htmlData,
            imageData: imageData,
            thumbnailData: thumbnailData,
            imageType: imageType,
            colorHex: colorHex,
            filePaths: filePaths
        )
    }

    func settingThumbnailData(_ thumbnailData: Data?) -> ClipboardPayload {
        ClipboardPayload(
            plainText: plainText,
            urlData: urlData,
            rtfData: rtfData,
            htmlData: htmlData,
            imageData: imageData,
            thumbnailData: thumbnailData,
            imageType: imageType,
            colorHex: colorHex,
            filePaths: filePaths
        )
    }
}

struct ClipboardSnapshot: Sendable {
    static let concealedType = "org.nspasteboard.ConcealedType"
    static let transientType = "org.nspasteboard.TransientType"
    static let autoGeneratedType = "org.nspasteboard.AutoGeneratedType"
    static let fileNamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
    static let fileURLType = NSPasteboard.PasteboardType("public.file-url")
    static let urlType = NSPasteboard.PasteboardType("public.url")
    static let utf8TextType = NSPasteboard.PasteboardType("public.utf8-plain-text")
    static let rtfType = NSPasteboard.PasteboardType("public.rtf")
    static let htmlType = NSPasteboard.PasteboardType("public.html")
    static let pngType = NSPasteboard.PasteboardType("public.png")
    static let tiffType = NSPasteboard.PasteboardType("public.tiff")
    static let colorType = NSPasteboard.PasteboardType.color

    let types: Set<String>
    let plainText: String?
    let urlData: Data?
    let rtfData: Data?
    let htmlData: Data?
    let imageData: Data?
    let imageType: String?
    let colorHex: String?
    let filePaths: [String]
    let source: ClipboardSource?
    let capturedAt: Date

    init(
        types: Set<String>,
        plainText: String? = nil,
        urlData: Data? = nil,
        rtfData: Data? = nil,
        htmlData: Data? = nil,
        imageData: Data? = nil,
        imageType: String? = nil,
        colorHex: String? = nil,
        filePaths: [String] = [],
        source: ClipboardSource? = nil,
        capturedAt: Date = Date()
    ) {
        self.types = types
        self.plainText = plainText
        self.urlData = urlData
        self.rtfData = rtfData
        self.htmlData = htmlData
        self.imageData = imageData
        self.imageType = imageType
        self.colorHex = colorHex
        self.filePaths = filePaths
        self.source = source
        self.capturedAt = capturedAt
    }

    var isPrivate: Bool {
        types.contains(Self.concealedType)
            || types.contains(Self.transientType)
            || types.contains(Self.autoGeneratedType)
    }

    static func read(
        from pasteboard: NSPasteboard,
        source: ClipboardSource?,
        capturedAt: Date = Date()
    ) -> ClipboardSnapshot? {
        guard let items = pasteboard.pasteboardItems, !items.isEmpty else {
            return nil
        }

        let types = Set(items.flatMap { item in item.types.map(\.rawValue) })
        guard !types.isEmpty else { return nil }

        var filePaths: [String] = []
        var seenFilePaths = Set<String>()

        for item in items {
            let propertyList = item.propertyList(forType: Self.fileNamesType)
            if let paths = propertyList as? [String] {
                for path in paths where seenFilePaths.insert(path).inserted {
                    filePaths.append(path)
                }
            }

            if let propertyList = propertyList as? [Any] {
                for value in propertyList {
                    let path: String?
                    if let value = value as? String {
                        path = value
                    } else if let value = value as? URL {
                        path = value.path
                    } else if let value = value as? NSURL {
                        path = value.path
                    } else {
                        path = nil
                    }

                    if let path, seenFilePaths.insert(path).inserted {
                        filePaths.append(path)
                    }
                }
            }

            if let data = item.data(forType: Self.fileURLType),
               let url = URL(dataRepresentation: data, relativeTo: nil),
               seenFilePaths.insert(url.path).inserted {
                filePaths.append(url.path)
            }
        }

        let plainText = items.lazy.compactMap { item in
            item.string(forType: .string) ?? item.string(forType: Self.utf8TextType)
        }.first

        let urlData = items.lazy.compactMap { item in
            item.data(forType: Self.urlType)
        }.first

        let rtfData = items.lazy.compactMap { item in
            item.data(forType: .rtf) ?? item.data(forType: Self.rtfType)
        }.first

        let htmlData = items.lazy.compactMap { item in
            item.data(forType: .html) ?? item.data(forType: Self.htmlType)
        }.first

        let imageData: Data?
        let imageType: String?
        if let data = items.lazy.compactMap({ $0.data(forType: Self.pngType) }).first {
            imageData = data
            imageType = Self.pngType.rawValue
        } else if let data = items.lazy.compactMap({ $0.data(forType: Self.tiffType) }).first {
            imageData = data
            imageType = Self.tiffType.rawValue
        } else {
            imageData = nil
            imageType = nil
        }

        let colorHex: String?
        if types.contains(Self.colorType.rawValue),
           let color = pasteboard.readObjects(
               forClasses: [NSColor.self],
               options: nil
           )?.first as? NSColor {
            colorHex = ClipboardColorCodec.hex(from: color)
        } else {
            colorHex = plainText.flatMap(ClipboardColorCodec.normalizedHex)
        }

        let snapshot = ClipboardSnapshot(
            types: types,
            plainText: plainText,
            urlData: urlData,
            rtfData: rtfData,
            htmlData: htmlData,
            imageData: imageData,
            imageType: imageType,
            colorHex: colorHex,
            filePaths: filePaths,
            source: source,
            capturedAt: capturedAt
        )

        guard !snapshot.isPrivate, snapshot.hasSupportedContent else {
            return nil
        }
        return snapshot
    }

    var hasSupportedContent: Bool {
        plainText != nil
            || urlData != nil
            || rtfData != nil
            || htmlData != nil
            || imageData != nil
            || colorHex != nil
            || !filePaths.isEmpty
    }

    func makeEntry() -> ClipboardEntry? {
        guard !isPrivate else { return nil }

        let sanitizedText: String?
        if let plainText {
            guard Data(plainText.utf8).count <= ClipboardEntry.maximumTextBytes else {
                return nil
            }
            sanitizedText = plainText
        } else {
            sanitizedText = nil
        }

        if let imageData, imageData.count > ClipboardEntry.maximumImageBytes {
            return nil
        }

        if let urlData, urlData.count > ClipboardEntry.maximumURLBytes {
            return nil
        }

        if let rtfData, rtfData.count > ClipboardEntry.maximumRichTextBytes {
            return nil
        }

        if let htmlData, htmlData.count > ClipboardEntry.maximumRichTextBytes {
            return nil
        }

        let normalizedColorHex = colorHex.flatMap(ClipboardColorCodec.normalizedHex)

        let thumbnailData = imageData.flatMap {
            ClipboardThumbnailGenerator.makeThumbnail(from: $0)
        }

        let payload = ClipboardPayload(
            plainText: sanitizedText,
            urlData: urlData,
            rtfData: rtfData,
            htmlData: htmlData,
            imageData: imageData,
            thumbnailData: thumbnailData,
            imageType: imageType,
            colorHex: normalizedColorHex,
            filePaths: filePaths
        )
        guard payload.hasContent else { return nil }

        let kind: ClipboardEntryKind
        if !filePaths.isEmpty {
            kind = .file
        } else if imageData != nil {
            kind = .image
        } else if normalizedColorHex != nil {
            kind = .color
        } else if (sanitizedText.map(Self.isLink) ?? false) || urlData != nil {
            kind = .link
        } else {
            kind = .text
        }

        let fingerprintData = (try? JSONEncoder().encode(payload)) ?? Data()
        let fingerprint = SHA256.hash(data: Data(kind.rawValue.utf8) + fingerprintData)
            .map { String(format: "%02x", $0) }
            .joined()

        let dimensions = imageData.flatMap { Self.imageDimensions(for: $0) }
        var byteCount = 0
        if let sanitizedText {
            byteCount += Data(sanitizedText.utf8).count
        }
        byteCount += urlData?.count ?? 0
        byteCount += rtfData?.count ?? 0
        byteCount += htmlData?.count ?? 0
        byteCount += imageData?.count ?? 0
        byteCount += normalizedColorHex?.utf8.count ?? 0
        byteCount += filePaths.reduce(0) { $0 + $1.utf8.count }

        return ClipboardEntry(
            id: UUID(),
            kind: kind,
            payload: payload,
            fingerprint: fingerprint,
            source: source,
            firstCopiedAt: capturedAt,
            lastCopiedAt: capturedAt,
            copyCount: 1,
            isPinned: false,
            byteCount: byteCount,
            imageWidth: dimensions?.width,
            imageHeight: dimensions?.height
        )
    }

    private nonisolated static func isLink(_ text: String) -> Bool {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased() else {
            return false
        }
        return ["http", "https", "mailto"].contains(scheme)
    }

    private nonisolated static func imageDimensions(for data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as NSDictionary?,
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
            return nil
        }
        return (width.intValue, height.intValue)
    }
}

struct ClipboardEntry: Codable, Hashable, Identifiable, Sendable {
    static let maximumTextBytes = 4 * 1024 * 1024
    static let maximumURLBytes = 4 * 1024 * 1024
    static let maximumRichTextBytes = 4 * 1024 * 1024
    static let maximumImageBytes = 20 * 1024 * 1024
    static let maximumHistoryBytes = 100 * 1024 * 1024
    static let maximumHistoryEntries = 200

    let id: UUID
    let kind: ClipboardEntryKind
    let payload: ClipboardPayload
    let fingerprint: String
    var source: ClipboardSource?
    let firstCopiedAt: Date
    var lastCopiedAt: Date
    var copyCount: Int
    var isPinned: Bool
    let byteCount: Int
    let imageWidth: Int?
    let imageHeight: Int?

    var title: String {
        switch kind {
        case .image:
            if let imageWidth, let imageHeight {
                return "Image (\(imageWidth)×\(imageHeight))"
            }
            return "Image"
        case .file:
            if payload.filePaths.count == 1 {
                return URL(fileURLWithPath: payload.filePaths[0]).lastPathComponent
            }
            return "\(payload.filePaths.count) Files"
        case .link:
            return linkTitle ?? textTitle
        case .text:
            return textTitle
        case .color:
            return payload.colorHex ?? "Color"
        }
    }

    private var textTitle: String {
        let value = payload.plainText?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "Rich text"
        let firstLine = value.split(maxSplits: 1, whereSeparator: \.isNewline).first
            .map(String.init) ?? value
        return firstLine.truncated(to: 110)
    }

    private var linkTitle: String? {
        guard let value = urlString,
              let url = URL(string: value),
              let host = url.host else {
            return nil
        }

        let normalizedHost = host.lowercased()
        if normalizedHost == "music.youtube.com" || normalizedHost.hasSuffix(".music.youtube.com") {
            return "YouTube Music"
        }
        if normalizedHost == "youtube.com"
            || normalizedHost.hasSuffix(".youtube.com")
            || normalizedHost == "youtu.be" {
            return "YouTube"
        }

        let hostComponent = host
            .split(separator: ".")
            .drop(while: { String($0).caseInsensitiveCompare("www") == .orderedSame })
            .first
        return hostComponent.map { String($0).replacingOccurrences(of: "-", with: " ").localizedCapitalized }
    }

    var previewText: String? {
        guard let value = payload.plainText else { return nil }
        return value.truncated(to: 20_000)
    }

    var subtitle: String? {
        switch kind {
        case .file:
            return payload.filePaths.count == 1
                ? URL(fileURLWithPath: payload.filePaths[0]).deletingLastPathComponent().path
                : "Files"
        case .link:
            return urlString?.truncated(to: 110)
        case .image, .text, .color:
            return nil
        }
    }

    var plainText: String? {
        payload.plainText
    }

    var colorHex: String? {
        payload.colorHex
    }

    var urlString: String? {
        if let plainText = payload.plainText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !plainText.isEmpty {
            return plainText
        }
        guard let urlData = payload.urlData,
              let url = URL(dataRepresentation: urlData, relativeTo: nil) else {
            return nil
        }
        return url.absoluteString
    }

    var fileURLs: [URL] {
        payload.filePaths.map { URL(fileURLWithPath: $0) }
    }

    var characterCount: Int {
        payload.plainText?.count ?? 0
    }

    var wordCount: Int {
        payload.plainText?.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count ?? 0
    }

    var dimensionsLabel: String? {
        guard let imageWidth, let imageHeight else { return nil }
        return "\(imageWidth)×\(imageHeight)"
    }

    var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }

    func refreshed(at date: Date, source: ClipboardSource?) -> ClipboardEntry {
        var refreshed = self
        refreshed.lastCopiedAt = date
        refreshed.copyCount += 1
        if let source {
            refreshed.source = source
        }
        return refreshed
    }

    func settingPinned(_ isPinned: Bool) -> ClipboardEntry {
        var updated = self
        updated.isPinned = isPinned
        return updated
    }

    func withoutImageData(thumbnailData: Data? = nil) -> ClipboardEntry {
        ClipboardEntry(
            id: id,
            kind: kind,
            payload: payload.withoutImageData(thumbnailData: thumbnailData),
            fingerprint: fingerprint,
            source: source,
            firstCopiedAt: firstCopiedAt,
            lastCopiedAt: lastCopiedAt,
            copyCount: copyCount,
            isPinned: isPinned,
            byteCount: byteCount,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        )
    }

    func withImageData(_ imageData: Data) -> ClipboardEntry {
        ClipboardEntry(
            id: id,
            kind: kind,
            payload: payload.withImageData(imageData),
            fingerprint: fingerprint,
            source: source,
            firstCopiedAt: firstCopiedAt,
            lastCopiedAt: lastCopiedAt,
            copyCount: copyCount,
            isPinned: isPinned,
            byteCount: byteCount,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        )
    }

    func settingThumbnailData(_ thumbnailData: Data?) -> ClipboardEntry {
        ClipboardEntry(
            id: id,
            kind: kind,
            payload: payload.settingThumbnailData(thumbnailData),
            fingerprint: fingerprint,
            source: source,
            firstCopiedAt: firstCopiedAt,
            lastCopiedAt: lastCopiedAt,
            copyCount: copyCount,
            isPinned: isPinned,
            byteCount: byteCount,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        )
    }
}

private extension String {
    func truncated(to maxLength: Int) -> String {
        guard count > maxLength else { return self }
        return String(prefix(max(0, maxLength - 1))) + "…"
    }
}

struct ClipboardDragPayload {
    let pasteboardItems: [NSPasteboardItem]
    let cleanup: () -> Void
}

enum ClipboardPasteboardWriter {
    @discardableResult
    static func write(_ entry: ClipboardEntry, to pasteboard: NSPasteboard = .general) -> Bool {
        pasteboard.clearContents()

        if !entry.payload.filePaths.isEmpty {
            let urls = entry.fileURLs.map { $0 as NSURL }
            return pasteboard.writeObjects(urls)
        }

        let item = NSPasteboardItem()
        guard populate(item, with: entry) else { return false }
        return pasteboard.writeObjects([item])
    }

    static func makeDragPayload(for entry: ClipboardEntry) -> ClipboardDragPayload? {
        let item = NSPasteboardItem()
        var temporaryFiles: [URL] = []

        if !entry.payload.filePaths.isEmpty {
            let fileURLs = entry.fileURLs
            guard !fileURLs.isEmpty else { return nil }

            let pasteboardItems = fileURLs.map { fileURL in
                let fileItem = NSPasteboardItem()
                fileItem.setData(
                    fileURL.dataRepresentation,
                    forType: ClipboardSnapshot.fileURLType
                )
                return fileItem
            }

            return ClipboardDragPayload(
                pasteboardItems: pasteboardItems,
                cleanup: {}
            )
        } else {
            guard populate(item, with: entry) else { return nil }

            if let imageFile = temporaryImageFile(for: entry) {
                temporaryFiles.append(imageFile)
                item.setData(
                    imageFile.dataRepresentation,
                    forType: ClipboardSnapshot.fileURLType
                )
            }
        }

        let cleanup: () -> Void = {
            guard !temporaryFiles.isEmpty else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                for file in temporaryFiles {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }

        return ClipboardDragPayload(
            pasteboardItems: [item],
            cleanup: cleanup
        )
    }

    private static func populate(_ item: NSPasteboardItem, with entry: ClipboardEntry) -> Bool {
        var didWrite = false

        if let plainText = entry.payload.plainText {
            item.setString(plainText, forType: .string)
            didWrite = true
        }
        if let urlData = entry.payload.urlData {
            item.setData(urlData, forType: ClipboardSnapshot.urlType)
            didWrite = true
        }
        if let rtfData = entry.payload.rtfData {
            item.setData(rtfData, forType: .rtf)
            didWrite = true
        }
        if let htmlData = entry.payload.htmlData {
            item.setData(htmlData, forType: .html)
            didWrite = true
        }
        if let imageData = entry.payload.imageData ?? entry.payload.thumbnailData {
            let imageType = entry.payload.imageType ?? ClipboardSnapshot.pngType.rawValue
            item.setData(imageData, forType: NSPasteboard.PasteboardType(imageType))
            if let image = NSImage(data: imageData), let tiff = image.tiffRepresentation {
                item.setData(tiff, forType: .tiff)
            }
            didWrite = true
        }
        if let colorHex = entry.payload.colorHex,
           let color = ClipboardColorCodec.color(fromHex: colorHex) {
            let colorPasteboard = NSPasteboard.withUniqueName()
            _ = colorPasteboard.writeObjects([color])
            if let colorData = colorPasteboard.data(forType: ClipboardSnapshot.colorType) {
                item.setData(colorData, forType: ClipboardSnapshot.colorType)
                didWrite = true
            }
            item.setString(colorHex, forType: .string)
            didWrite = true
        }

        return didWrite
    }

    @discardableResult
    static func writeColor(
        _ color: NSColor,
        to pasteboard: NSPasteboard = .general
    ) -> Bool {
        guard let colorHex = ClipboardColorCodec.hex(from: color) else { return false }

        pasteboard.clearContents()
        guard pasteboard.writeObjects([color]) else { return false }
        return pasteboard.setString(colorHex, forType: .string)
    }

    private static func temporaryImageFile(for entry: ClipboardEntry) -> URL? {
        guard let imageData = entry.payload.imageData ?? entry.payload.thumbnailData else { return nil }

        let fileExtension: String
        switch entry.payload.imageType?.lowercased() {
        case ClipboardSnapshot.tiffType.rawValue:
            fileExtension = "tiff"
        default:
            fileExtension = "png"
        }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Lightsearch-clipboard-\(UUID().uuidString).\(fileExtension)")
        do {
            try imageData.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path
            )
            return fileURL
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
    }

}

final class ClipboardHistoryStore: @unchecked Sendable {
    private let fileURL: URL
    private let imagesDirectoryURL: URL
    private let suppliedKeyData: Data?
    private let queue = DispatchQueue(label: "io.notscope.Lightsearch.clipboard-history", qos: .utility)

    nonisolated init(
        fileURL: URL? = nil,
        imagesDirectoryURL: URL? = nil,
        keyData: Data? = nil
    ) {
        let defaultFile = Self.defaultFileURL()
        self.fileURL = fileURL ?? defaultFile
        self.imagesDirectoryURL = imagesDirectoryURL ?? Self.defaultImagesDirectoryURL()
        self.suppliedKeyData = keyData
    }

    nonisolated func loadData() -> Data? {
        queue.sync {
            loadDataLocked()
        }
    }

    nonisolated func saveData(_ plaintext: Data) {
        queue.async { [fileURL, suppliedKeyData] in
            Self.saveDataLocked(
                plaintext,
                fileURL: fileURL,
                suppliedKeyData: suppliedKeyData
            )
        }
    }

    nonisolated func saveImageData(_ data: Data, for id: UUID) {
        queue.async { [imagesDirectoryURL, suppliedKeyData] in
            Self.saveImageDataLocked(
                data,
                for: id,
                directoryURL: imagesDirectoryURL,
                suppliedKeyData: suppliedKeyData
            )
        }
    }

    nonisolated func loadImageData(for id: UUID) -> Data? {
        queue.sync {
            loadImageDataLocked(for: id)
        }
    }

    nonisolated func deleteImageData(for id: UUID) {
        queue.async { [imagesDirectoryURL] in
            let imageFileURL = imagesDirectoryURL.appendingPathComponent("\(id.uuidString).enc")
            try? FileManager.default.removeItem(at: imageFileURL)
        }
    }

    nonisolated func pruneImageData(keeping validIDs: Set<UUID>) {
        queue.async { [imagesDirectoryURL] in
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: imagesDirectoryURL,
                includingPropertiesForKeys: nil
            ) else { return }
            for url in contents where url.pathExtension == "enc" {
                let uuidString = url.deletingPathExtension().lastPathComponent
                if let uuid = UUID(uuidString: uuidString), !validIDs.contains(uuid) {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
    }

    nonisolated func clear() {
        queue.sync {
            try? FileManager.default.removeItem(at: fileURL)
            try? FileManager.default.removeItem(at: imagesDirectoryURL)
        }
    }

    nonisolated func flush() {
        queue.sync {}
    }

    private nonisolated func loadDataLocked() -> Data? {
        guard let encryptedData = try? Data(contentsOf: fileURL),
              let keyData = keyData(),
              let sealedBox = try? AES.GCM.SealedBox(combined: encryptedData),
              let data = try? AES.GCM.open(sealedBox, using: SymmetricKey(data: keyData)) else {
            return nil
        }
        return data
    }

    private nonisolated func loadImageDataLocked(for id: UUID) -> Data? {
        let imageFileURL = imagesDirectoryURL.appendingPathComponent("\(id.uuidString).enc")
        guard let encryptedData = try? Data(contentsOf: imageFileURL),
              let keyData = keyData(),
              let sealedBox = try? AES.GCM.SealedBox(combined: encryptedData),
              let data = try? AES.GCM.open(sealedBox, using: SymmetricKey(data: keyData)) else {
            return nil
        }
        return data
    }

    private nonisolated static func saveDataLocked(
        _ plaintext: Data,
        fileURL: URL,
        suppliedKeyData: Data?
    ) {
        let keyData: Data?
        if let suppliedKeyData {
            keyData = suppliedKeyData
        } else {
            keyData = try? keyDataFromKeychain()
        }
        guard let keyData else {
            return
        }

        do {
            let sealedBox = try AES.GCM.seal(plaintext, using: SymmetricKey(data: keyData))
            guard let encryptedData = sealedBox.combined else { return }

            let directoryURL = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            try encryptedData.write(to: fileURL, options: .atomic)
            chmod(directoryURL.path, 0o700)
            chmod(fileURL.path, 0o600)

            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var persistedURL = fileURL
            try? persistedURL.setResourceValues(values)
        } catch {
            // History is a convenience feature. A persistence failure must
            // never interrupt clipboard capture or expose clipboard contents.
        }
    }

    private nonisolated static func saveImageDataLocked(
        _ data: Data,
        for id: UUID,
        directoryURL: URL,
        suppliedKeyData: Data?
    ) {
        let keyData: Data?
        if let suppliedKeyData {
            keyData = suppliedKeyData
        } else {
            keyData = try? keyDataFromKeychain()
        }
        guard let keyData else { return }

        do {
            let sealedBox = try AES.GCM.seal(data, using: SymmetricKey(data: keyData))
            guard let encryptedData = sealedBox.combined else { return }

            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            let imageFileURL = directoryURL.appendingPathComponent("\(id.uuidString).enc")
            try encryptedData.write(to: imageFileURL, options: .atomic)
            chmod(directoryURL.path, 0o700)
            chmod(imageFileURL.path, 0o600)

            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var persistedURL = imageFileURL
            try? persistedURL.setResourceValues(values)
        } catch {
        }
    }

    private nonisolated func keyData() -> Data? {
        if let suppliedKeyData {
            return suppliedKeyData
        }
        return try? Self.keyDataFromKeychain()
    }

    private nonisolated static func defaultFileURL() -> URL {
        let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return applicationSupportURL
            .appendingPathComponent("io.notscope.Lightsearch", isDirectory: true)
            .appendingPathComponent("clipboard-history.enc")
    }

    private nonisolated static func defaultImagesDirectoryURL() -> URL {
        let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return applicationSupportURL
            .appendingPathComponent("io.notscope.Lightsearch", isDirectory: true)
            .appendingPathComponent("clipboard-images", isDirectory: true)
    }

    private nonisolated static func keyDataFromKeychain() throws -> Data {
        let keychainService = "io.notscope.Lightsearch"
        let keychainAccount = "clipboard-history-key-v1"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, data.count == 32 {
            return data
        }
        guard status == errSecItemNotFound else {
            throw ClipboardHistoryStoreError.keychain(status)
        }

        let keyData = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: keyData
        ]
        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else {
            throw ClipboardHistoryStoreError.keychain(addStatus)
        }
        if addStatus == errSecDuplicateItem {
            return try keyDataFromKeychain()
        }
        return keyData
    }
}

struct ClipboardHistoryArchive: Codable {
    let version: Int
    let entries: [ClipboardEntry]

    init(entries: [ClipboardEntry]) {
        version = 1
        self.entries = entries
    }
}

private enum ClipboardHistoryStoreError: Error {
    case keychain(OSStatus)
}
