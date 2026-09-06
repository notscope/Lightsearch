//
//  ClipboardHistoryTests.swift
//  LightsearchTests
//
// Correctness, privacy, and persistence tests for clipboard history.

import AppKit
import Foundation
import XCTest
@testable import Lightsearch

@MainActor
final class ClipboardHistoryTests: XCTestCase {
    private let source = ClipboardSource(
        name: "Test Editor",
        bundleIdentifier: "com.example.editor",
        bundlePath: "/Applications/Test Editor.app"
    )

    func testSnapshotsClassifyTextLinksImagesAndFiles() {
        let text = makeTextSnapshot("AppKit keeps the launcher responsive")
        XCTAssertEqual(text.makeEntry()?.kind, .text)

        let link = makeTextSnapshot("https://example.com/article")
        XCTAssertEqual(link.makeEntry()?.kind, .link)

        let image = ClipboardSnapshot(
            types: [ClipboardSnapshot.pngType.rawValue],
            imageData: onePixelPNG,
            imageType: ClipboardSnapshot.pngType.rawValue,
            source: source
        )
        let imageEntry = image.makeEntry()
        XCTAssertEqual(imageEntry?.kind, .image)
        XCTAssertEqual(imageEntry?.imageWidth, 1)
        XCTAssertEqual(imageEntry?.imageHeight, 1)

        let files = ClipboardSnapshot(
            types: [ClipboardSnapshot.fileNamesType.rawValue],
            filePaths: ["/Users/example/Documents/Brief.pdf", "/Users/example/Desktop/Notes.txt"],
            source: source
        )
        let fileEntry = files.makeEntry()
        XCTAssertEqual(fileEntry?.kind, .file)
        XCTAssertEqual(fileEntry?.title, "2 Files")
        XCTAssertEqual(fileEntry?.fileURLs.count, 2)
    }

    func testClipboardFilterSystemImageNames() {
        XCTAssertEqual(ClipboardFilter.all.systemImageName, "list.bullet")
        XCTAssertEqual(ClipboardFilter.text.systemImageName, "doc.text")
        XCTAssertEqual(ClipboardFilter.link.systemImageName, "link")
        XCTAssertEqual(ClipboardFilter.image.systemImageName, "photo")
        XCTAssertEqual(ClipboardFilter.file.systemImageName, "doc")
        XCTAssertEqual(ClipboardFilter.color.systemImageName, "eyedropper")
    }

    func testClipboardFilterDropdownKeyboardStateAndNavigation() {
        let state = LauncherState()
        state.enterClipboardHistory()

        XCTAssertFalse(state.isClipboardFilterPresented)
        XCTAssertEqual(state.clipboardFilter, .all)

        // Open dropdown
        state.openClipboardFilterDropdown()
        XCTAssertTrue(state.isClipboardFilterPresented)
        XCTAssertEqual(state.focusedClipboardFilter, .all)

        // Navigate forward
        state.moveFocusedClipboardFilter(by: 1)
        XCTAssertEqual(state.focusedClipboardFilter, .text)

        state.moveFocusedClipboardFilter(by: 1)
        XCTAssertEqual(state.focusedClipboardFilter, .link)

        // Navigate backwards and wrap around
        state.moveFocusedClipboardFilter(by: -2)
        XCTAssertEqual(state.focusedClipboardFilter, .all)
        state.moveFocusedClipboardFilter(by: -1)
        XCTAssertEqual(state.focusedClipboardFilter, .color)

        // Apply focused filter
        state.applyFocusedClipboardFilter()
        XCTAssertFalse(state.isClipboardFilterPresented)
        XCTAssertEqual(state.clipboardFilter, .color)

        // Toggle dropdown
        state.toggleClipboardFilterPresented()
        XCTAssertTrue(state.isClipboardFilterPresented)
        XCTAssertEqual(state.focusedClipboardFilter, .color)

        state.toggleClipboardFilterPresented()
        XCTAssertFalse(state.isClipboardFilterPresented)

        // Exit or reset closes dropdown
        state.openClipboardFilterDropdown()
        XCTAssertTrue(state.isClipboardFilterPresented)
        state.exitClipboardHistory()
        XCTAssertFalse(state.isClipboardFilterPresented)
    }

    func testColorCodecNormalizesSupportedHexFormatsAndRejectsInvalidValues() {
        let supportedValues: [String: String] = [
            "#4e2f88": "#4E2F88",
            "#abc": "#AABBCC",
            "#abcd": "#AABBCCDD",
            "0x12345678": "#12345678",
            "  #0f0  ": "#00FF00"
        ]

        for (value, expected) in supportedValues {
            XCTAssertEqual(ClipboardColorCodec.normalizedHex(value), expected, value)
        }

        for value in ["4e2f88", "#12", "#12345", "#GGGGGG", "#123456789"] {
            XCTAssertNil(ClipboardColorCodec.normalizedHex(value), value)
        }
    }

    func testColorSnapshotPreservesHexAndUsesColorKind() {
        let snapshot = ClipboardSnapshot(
            types: [
                ClipboardSnapshot.colorType.rawValue,
                ClipboardSnapshot.utf8TextType.rawValue
            ],
            plainText: "#4e2f88",
            colorHex: "#4e2f88",
            source: source
        )

        guard let entry = snapshot.makeEntry() else {
            XCTFail("Expected a color entry")
            return
        }

        XCTAssertEqual(entry.kind, .color)
        XCTAssertEqual(entry.title, "#4E2F88")
        XCTAssertEqual(entry.colorHex, "#4E2F88")
        XCTAssertEqual(entry.plainText, "#4e2f88")
        XCTAssertNil(entry.subtitle)
    }

    func testNativeColorPasteboardRoundTripIncludesColorTypeAndHexText() {
        let color = NSColor(srgbRed: 78 / 255, green: 47 / 255, blue: 136 / 255, alpha: 1)
        let pasteboard = NSPasteboard.withUniqueName()

        XCTAssertTrue(ClipboardPasteboardWriter.writeColor(color, to: pasteboard))
        XCTAssertNotNil(pasteboard.data(forType: ClipboardSnapshot.colorType))
        XCTAssertEqual(pasteboard.string(forType: .string), "#4E2F88")

        guard let snapshot = ClipboardSnapshot.read(
            from: pasteboard,
            source: source,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000)
        ),
        let entry = snapshot.makeEntry() else {
            XCTFail("Expected the native color pasteboard to be readable")
            return
        }

        XCTAssertEqual(entry.kind, .color)
        XCTAssertEqual(entry.colorHex, "#4E2F88")
    }

    func testColorDragPayloadIncludesNativeColorAndHexText() {
        let snapshot = ClipboardSnapshot(
            types: [ClipboardSnapshot.colorType.rawValue],
            plainText: "#4E2F88",
            colorHex: "#4E2F88",
            source: source
        )
        guard let entry = snapshot.makeEntry(),
              let payload = ClipboardPasteboardWriter.makeDragPayload(for: entry),
              let pasteboardItem = payload.pasteboardItems.first else {
            XCTFail("Expected a draggable color entry")
            return
        }
        defer { payload.cleanup() }

        XCTAssertNotNil(pasteboardItem.data(forType: ClipboardSnapshot.colorType))
        XCTAssertEqual(pasteboardItem.string(forType: .string), "#4E2F88")
    }

    func testPrivateAndUnsupportedPasteboardContentIsNeverMadeIntoAnEntry() {
        let concealed = ClipboardSnapshot(
            types: [ClipboardSnapshot.concealedType],
            plainText: "password=do-not-store",
            source: source
        )
        XCTAssertTrue(concealed.isPrivate)
        XCTAssertNil(concealed.makeEntry())

        let transient = ClipboardSnapshot(
            types: [ClipboardSnapshot.transientType],
            plainText: "one-time token",
            source: source
        )
        XCTAssertNil(transient.makeEntry())

        let generated = ClipboardSnapshot(
            types: [ClipboardSnapshot.autoGeneratedType],
            plainText: "temporary content",
            source: source
        )
        XCTAssertNil(generated.makeEntry())

        let unsupported = ClipboardSnapshot(types: ["com.example.private-format"])
        XCTAssertFalse(unsupported.hasSupportedContent)
        XCTAssertNil(unsupported.makeEntry())
    }

    func testOversizedTextIsRejectedBeforeItCanConsumeHistoryStorage() {
        let oversizedText = String(
            repeating: "x",
            count: ClipboardEntry.maximumTextBytes + 1
        )
        let snapshot = makeTextSnapshot(oversizedText)

        XCTAssertNil(snapshot.makeEntry())
    }

    func testRichFormatsAreBoundedAndLargeTextPreviewsAreCapped() {
        let oversizedRTF = ClipboardSnapshot(
            types: [ClipboardSnapshot.rtfType.rawValue],
            rtfData: Data(repeating: 0x7F, count: ClipboardEntry.maximumRichTextBytes + 1),
            source: source
        )
        XCTAssertNil(oversizedRTF.makeEntry())

        let oversizedHTML = ClipboardSnapshot(
            types: [ClipboardSnapshot.htmlType.rawValue],
            htmlData: Data(repeating: 0x3C, count: ClipboardEntry.maximumRichTextBytes + 1),
            source: source
        )
        XCTAssertNil(oversizedHTML.makeEntry())

        let longText = String(repeating: "preview ", count: 3_000)
        guard let entry = makeTextSnapshot(longText).makeEntry() else {
            XCTFail("Expected a bounded text entry")
            return
        }
        XCTAssertEqual(entry.plainText, longText)
        XCTAssertEqual(entry.previewText?.count, 20_000)
        XCTAssertTrue(entry.previewText?.hasSuffix("…") == true)
    }

    func testURLUTIDataIsRetainedAndPastedAlongsideText() {
        let rawURL = "https://music.youtube.com/watch?v=example"
        guard let url = URL(string: rawURL) else {
            XCTFail("Expected a valid URL")
            return
        }
        let urlData = url.dataRepresentation
        let snapshot = ClipboardSnapshot(
            types: [ClipboardSnapshot.urlType.rawValue, ClipboardSnapshot.utf8TextType.rawValue],
            plainText: rawURL,
            urlData: urlData,
            source: source
        )

        guard let entry = snapshot.makeEntry() else {
            XCTFail("Expected a link entry")
            return
        }
        XCTAssertEqual(entry.kind, .link)
        XCTAssertEqual(entry.title, "YouTube Music")
        XCTAssertEqual(entry.subtitle, rawURL)

        let pasteboard = NSPasteboard.withUniqueName()
        XCTAssertTrue(ClipboardPasteboardWriter.write(entry, to: pasteboard))
        XCTAssertEqual(pasteboard.string(forType: .string), rawURL)
        XCTAssertEqual(pasteboard.data(forType: ClipboardSnapshot.urlType), urlData)
    }

    func testDragPayloadPreservesNativeTextAndURLRepresentations() {
        let rawURL = "https://example.com/upload"
        guard let url = URL(string: rawURL),
              let entry = ClipboardSnapshot(
                  types: [ClipboardSnapshot.urlType.rawValue, ClipboardSnapshot.utf8TextType.rawValue],
                  plainText: rawURL,
                  urlData: url.dataRepresentation,
                  source: source
              ).makeEntry(),
              let payload = ClipboardPasteboardWriter.makeDragPayload(for: entry) else {
            XCTFail("Expected a draggable link entry")
            return
        }
        guard let pasteboardItem = payload.pasteboardItems.first else {
            XCTFail("Expected one draggable link item")
            return
        }

        XCTAssertEqual(pasteboardItem.string(forType: .string), rawURL)
        XCTAssertEqual(
            pasteboardItem.data(forType: ClipboardSnapshot.urlType),
            url.dataRepresentation
        )
        payload.cleanup()
    }

    func testImageDragPayloadIncludesImageDataAndAttachableFileURL() throws {
        guard let entry = ClipboardSnapshot(
            types: [ClipboardSnapshot.pngType.rawValue],
            imageData: onePixelPNG,
            imageType: ClipboardSnapshot.pngType.rawValue,
            source: source
        ).makeEntry(),
        let payload = ClipboardPasteboardWriter.makeDragPayload(for: entry) else {
            XCTFail("Expected a draggable image entry")
            return
        }
        guard let pasteboardItem = payload.pasteboardItems.first else {
            XCTFail("Expected one draggable image item")
            return
        }

        XCTAssertEqual(
            pasteboardItem.data(forType: ClipboardSnapshot.pngType),
            onePixelPNG
        )
        guard let fileURLData = pasteboardItem.data(
            forType: ClipboardSnapshot.fileURLType
        ),
        let temporaryURL = URL(dataRepresentation: fileURLData, relativeTo: nil) else {
            XCTFail("Expected an attachable temporary image file")
            return
        }
        defer {
            try? FileManager.default.removeItem(at: temporaryURL)
            payload.cleanup()
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: temporaryURL.path))
        XCTAssertEqual(
            pasteboardItem.data(forType: ClipboardSnapshot.fileURLType),
            temporaryURL.dataRepresentation
        )
        let attributes = try FileManager.default.attributesOfItem(atPath: temporaryURL.path)
        XCTAssertEqual(
            (attributes[FileAttributeKey.posixPermissions] as? NSNumber).map { $0.intValue & 0o777 },
            0o600
        )
    }

    func testFileDragPayloadExposesEachFileAsANativeFileURL() {
        let paths = [
            "/Users/example/Documents/Brief.pdf",
            "/Users/example/Desktop/Notes.txt"
        ]
        guard let entry = ClipboardSnapshot(
            types: [ClipboardSnapshot.fileNamesType.rawValue],
            filePaths: paths,
            source: source
        ).makeEntry(),
        let payload = ClipboardPasteboardWriter.makeDragPayload(for: entry) else {
            XCTFail("Expected a draggable file entry")
            return
        }
        defer { payload.cleanup() }

        let draggedPaths: [String] = payload.pasteboardItems.compactMap { item -> String? in
            guard let data = item.data(forType: ClipboardSnapshot.fileURLType) else {
                return nil
            }
            return URL(dataRepresentation: data, relativeTo: nil)?.path
        }

        XCTAssertEqual(draggedPaths, paths)
    }

    func testEntriesExposeStablePreviewMetadataAndCopyCounts() {
        let capturedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = makeTextSnapshot(
            "first line\nsecond line",
            capturedAt: capturedAt
        )
        guard let entry = snapshot.makeEntry() else {
            XCTFail("Expected a text entry")
            return
        }

        XCTAssertEqual(entry.title, "first line")
        XCTAssertEqual(entry.characterCount, 22)
        XCTAssertEqual(entry.wordCount, 4)
        XCTAssertEqual(entry.copyCount, 1)
        XCTAssertFalse(entry.isPinned)
        XCTAssertEqual(entry.source?.displayName, "Test Editor")
        XCTAssertEqual(entry.sizeLabel, "22 bytes")

        let refreshed = entry.refreshed(
            at: capturedAt.addingTimeInterval(60),
            source: source
        )
        XCTAssertEqual(refreshed.id, entry.id)
        XCTAssertEqual(refreshed.copyCount, 2)
        XCTAssertEqual(refreshed.firstCopiedAt, capturedAt)
        XCTAssertEqual(refreshed.lastCopiedAt, capturedAt.addingTimeInterval(60))
    }

    func testFeatureDeduplicatesEntriesAndSupportsFilterSearchPinAndDelete() {
        let feature = makeFeature()
        feature.enter()

        let firstDate = Date(timeIntervalSince1970: 1_700_000_000)
        feature.ingest(makeTextSnapshot("alpha", capturedAt: firstDate))
        feature.ingest(
            makeTextSnapshot(
                "https://example.com",
                capturedAt: firstDate.addingTimeInterval(10)
            )
        )
        feature.ingest(
            ClipboardSnapshot(
                types: [ClipboardSnapshot.fileNamesType.rawValue],
                filePaths: ["/tmp/report.pdf"],
                source: source,
                capturedAt: firstDate.addingTimeInterval(20)
            )
        )

        XCTAssertEqual(feature.entries.count, 3)
        XCTAssertEqual(feature.visibleEntries.count, 3)

        feature.ingest(makeTextSnapshot("alpha", capturedAt: firstDate.addingTimeInterval(30)))
        XCTAssertEqual(feature.entries.count, 3)
        XCTAssertEqual(feature.visibleEntries.first?.plainText, "alpha")
        XCTAssertEqual(feature.visibleEntries.first?.copyCount, 2)

        feature.setFilter(.link)
        XCTAssertEqual(feature.visibleEntries.map(\.kind), [.link])

        feature.setFilter(.all)
        feature.queryChanged("report", page: .clipboard)
        XCTAssertEqual(feature.visibleEntries.map(\.kind), [.file])

        feature.queryChanged("", page: .clipboard)
        guard let firstEntry = feature.visibleEntries.first else {
            XCTFail("Expected a visible entry")
            return
        }
        feature.togglePin(for: firstEntry.id)
        XCTAssertTrue(feature.entries.first(where: { $0.id == firstEntry.id })?.isPinned == true)

        feature.deleteEntry(withID: firstEntry.id)
        XCTAssertFalse(feature.entries.contains(where: { $0.id == firstEntry.id }))
    }

    func testFeaturePausesCaptureAndCapsHistory() {
        let feature = makeFeature()
        feature.enter()

        feature.setCaptureEnabled(false)
        feature.ingest(makeTextSnapshot("ignored while paused"))
        XCTAssertTrue(feature.entries.isEmpty)

        feature.setCaptureEnabled(true)
        feature.ingest(makeTextSnapshot("captured"))
        XCTAssertEqual(feature.entries.count, 1)

        for index in 0...ClipboardEntry.maximumHistoryEntries {
            feature.ingest(makeTextSnapshot("entry-\(index)"))
        }
        XCTAssertEqual(feature.entries.count, ClipboardEntry.maximumHistoryEntries)
    }

    func testFeatureFiltersAndSearchesColorEntries() {
        let feature = makeFeature()
        feature.enter()
        feature.ingest(
            ClipboardSnapshot(
                types: [ClipboardSnapshot.colorType.rawValue],
                plainText: "#4E2F88",
                colorHex: "#4E2F88",
                source: source
            )
        )
        feature.ingest(makeTextSnapshot("ordinary text"))

        feature.setFilter(.color)
        XCTAssertEqual(feature.visibleEntries.map(\.kind), [.color])

        feature.setFilter(.all)
        feature.queryChanged("4e2f", page: .clipboard)
        XCTAssertEqual(feature.visibleEntries.map(\.kind), [.color])
    }

    func testClipboardSearchActionIsDiscoverableFromTheLauncher() {
        let feature = makeFeature()
        let matchingQueries = [
            "cl",
            "clip",
            "clipboard",
            "clipboard history",
            "pa",
            "paste",
            "hi",
            "history"
        ]

        for query in matchingQueries {
            let output = feature.searchResults(
                for: LauncherSearchContext(query: query, applicationQuery: query)
            )

            XCTAssertEqual(output.placement, .beforeApplications, query)
            XCTAssertEqual(output.results.count, 1, query)
            if case .clipboardHistory = output.results[0] {
                // Expected action type.
            } else {
                XCTFail("Expected clipboard history action for \(query)")
            }
        }

        let nonMatchingQueries = ["c", "p", "calculator", "copy", "files"]
        for query in nonMatchingQueries {
            XCTAssertTrue(
                feature.searchResults(
                    for: LauncherSearchContext(query: query, applicationQuery: query)
                ).results.isEmpty,
                query
            )
        }
    }

    func testColorPickerSearchActionIsDiscoverableWithoutAClipboardKeyword() {
        let feature = ColorPickerFeature()
        let matchingQueries = ["co", "color", "picker", "pick color", "eyedropper", "sample"]

        for query in matchingQueries {
            let output = feature.searchResults(
                for: LauncherSearchContext(query: query, applicationQuery: query)
            )

            XCTAssertEqual(output.placement, .beforeApplications, query)
            XCTAssertEqual(output.results.count, 1, query)
            if case .colorPicker = output.results[0] {
                // Expected action type.
            } else {
                XCTFail("Expected color picker action for \(query)")
            }
        }

        for query in ["c", "p", "copy", "calculator", "clipboard"] {
            XCTAssertTrue(
                feature.searchResults(
                    for: LauncherSearchContext(query: query, applicationQuery: query)
                ).results.isEmpty,
                query
            )
        }
    }

    func testHistoryIsEncryptedAndReloadableWithFilePermissionsRestricted() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LightsearchClipboardTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("clipboard-history.enc")
        let keyData = Data(repeating: 0x42, count: 32)
        let store = ClipboardHistoryStore(fileURL: fileURL, keyData: keyData)
        defer { try? FileManager.default.removeItem(at: directory) }

        let secret = "local-only-secret-\(UUID().uuidString)"
        guard let entry = makeTextSnapshot(secret).makeEntry() else {
            XCTFail("Expected a text entry")
            return
        }
        let archiveData = try JSONEncoder().encode(
            ClipboardHistoryArchive(entries: [entry])
        )

        store.saveData(archiveData)
        store.flush()

        let encryptedData = try Data(contentsOf: fileURL)
        XCTAssertFalse(encryptedData.isEmpty)
        XCTAssertNil(encryptedData.range(of: Data(secret.utf8)))
        XCTAssertNotEqual(encryptedData, archiveData)

        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue
        XCTAssertEqual(permissions.map { $0 & 0o777 }, 0o600)

        guard let restoredData = store.loadData() else {
            XCTFail("Expected encrypted history to decrypt")
            return
        }
        let restoredArchive = try JSONDecoder().decode(
            ClipboardHistoryArchive.self,
            from: restoredData
        )
        XCTAssertEqual(restoredArchive.version, 1)
        XCTAssertEqual(restoredArchive.entries, [entry])
    }

    func testCorruptedHistoryDoesNotProduceEntries() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LightsearchClipboardTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("clipboard-history.enc")
        let store = ClipboardHistoryStore(
            fileURL: fileURL,
            keyData: Data(repeating: 0x11, count: 32)
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try Data("not encrypted".utf8).write(to: fileURL)

        XCTAssertNil(store.loadData())
    }

    func testThumbnailGeneratorProducesCompactThumbnail() {
        let thumbnail = ClipboardThumbnailGenerator.makeThumbnail(from: onePixelPNG)
        XCTAssertNotNil(thumbnail)
        XCTAssertGreaterThan(thumbnail?.count ?? 0, 0)
    }

    func testThumbnailGeneratorDownsamplesImageCorrectly() {
        let image = ClipboardThumbnailGenerator.downsampleToThumbnail(from: onePixelPNG, maxPixelSize: 96)
        XCTAssertNotNil(image)
    }

    func testEncryptedImageStoreSaveLoadDeleteAndPruning() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LightsearchImageStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = ClipboardHistoryStore(
            fileURL: directory.appendingPathComponent("history.enc"),
            imagesDirectoryURL: directory.appendingPathComponent("images", isDirectory: true),
            keyData: Data(repeating: 0x42, count: 32)
        )

        let imageID1 = UUID()
        let imageID2 = UUID()
        let testData1 = Data([0x01, 0x02, 0x03, 0x04])
        let testData2 = Data([0x05, 0x06, 0x07, 0x08])

        store.saveImageData(testData1, for: imageID1)
        store.saveImageData(testData2, for: imageID2)
        store.flush()

        XCTAssertEqual(store.loadImageData(for: imageID1), testData1)
        XCTAssertEqual(store.loadImageData(for: imageID2), testData2)

        store.pruneImageData(keeping: [imageID1])
        store.flush()

        XCTAssertEqual(store.loadImageData(for: imageID1), testData1)
        XCTAssertNil(store.loadImageData(for: imageID2))

        store.deleteImageData(for: imageID1)
        store.flush()
        XCTAssertNil(store.loadImageData(for: imageID1))
    }

    func testClipboardFeatureRetainsFullImageDataAndGeneratesThumbnail() {
        let feature = makeFeature()
        let snapshot = ClipboardSnapshot(
            types: [ClipboardSnapshot.pngType.rawValue],
            imageData: onePixelPNG,
            imageType: ClipboardSnapshot.pngType.rawValue,
            source: source
        )

        feature.ingest(snapshot)
        XCTAssertEqual(feature.entries.count, 1)

        guard let entry = feature.entries.first else {
            XCTFail("Expected entry to exist")
            return
        }

        XCTAssertEqual(entry.kind, .image)
        XCTAssertEqual(entry.payload.imageData, onePixelPNG, "Full image payload must be retained in memory")
        XCTAssertNotNil(entry.payload.thumbnailData, "Thumbnail data must be generated in memory")

        let pasteboard = NSPasteboard.withUniqueName()
        let didWrite = ClipboardPasteboardWriter.write(entry, to: pasteboard)
        XCTAssertTrue(didWrite)
        XCTAssertEqual(pasteboard.data(forType: ClipboardSnapshot.pngType), onePixelPNG)
    }

    func testClipboardFeatureMigratesAndRehydratesImageArchiveOnLoad() async throws {
        let suiteName = "LightsearchClipboardMigrationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LightsearchMigration-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let keyData = Data(repeating: 0x33, count: 32)
        let store = ClipboardHistoryStore(
            fileURL: directory.appendingPathComponent("history.enc"),
            imagesDirectoryURL: directory.appendingPathComponent("images", isDirectory: true),
            keyData: keyData
        )

        let rawSnapshot = ClipboardSnapshot(
            types: [ClipboardSnapshot.pngType.rawValue],
            imageData: onePixelPNG,
            imageType: ClipboardSnapshot.pngType.rawValue,
            source: source
        )
        guard let entryWithImage = rawSnapshot.makeEntry() else {
            XCTFail("Expected legacy entry")
            return
        }

        // Save raw image payload to disk and stripped entry to archive
        store.saveImageData(onePixelPNG, for: entryWithImage.id)
        store.flush()

        let strippedEntry = entryWithImage.withoutImageData(thumbnailData: nil)
        let legacyArchive = ClipboardHistoryArchive(entries: [strippedEntry])
        let encodedData = try JSONEncoder().encode(legacyArchive)
        store.saveData(encodedData)
        store.flush()

        let feature = ClipboardFeature(historyStore: store, defaults: defaults)
        await feature.load()

        XCTAssertEqual(feature.entries.count, 1)
        guard let loadedEntry = feature.entries.first else {
            XCTFail("Expected loaded entry")
            return
        }

        XCTAssertEqual(loadedEntry.payload.imageData, onePixelPNG, "Missing image payload must be rehydrated from encrypted disk store on load")
        XCTAssertNotNil(loadedEntry.payload.thumbnailData, "Thumbnail data must be generated on load")
    }

    private func makeFeature() -> ClipboardFeature {
        let suiteName = "LightsearchClipboardTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LightsearchClipboardFeature-\(UUID().uuidString)", isDirectory: true)
        let store = ClipboardHistoryStore(
            fileURL: directory.appendingPathComponent("history.enc"),
            keyData: Data(repeating: 0x22, count: 32)
        )
        return ClipboardFeature(historyStore: store, defaults: defaults)
    }

    private func makeTextSnapshot(
        _ text: String,
        capturedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> ClipboardSnapshot {
        ClipboardSnapshot(
            types: [ClipboardSnapshot.utf8TextType.rawValue],
            plainText: text,
            source: source,
            capturedAt: capturedAt
        )
    }

    private var onePixelPNG: Data {
        Data(
            base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        )!
    }
}
