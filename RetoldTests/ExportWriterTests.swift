import Foundation
import XCTest
@testable import Retold

final class ExportWriterTests: XCTestCase {
    private var root: URL!
    private var folder: URL { root.appendingPathComponent("export", isDirectory: true) }
    private var audioDirectory: URL { root.appendingPathComponent("audio", isDirectory: true) }

    override func setUp() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("retold-export-writer", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    func testWritesTextAndAudio() throws {
        let audioBytes = Data([0, 1, 2, 3, 250])
        try audioBytes.write(to: audioDirectory.appendingPathComponent("take.m4a"))
        let manifest = ExportManifest(files: [
            ExportFile(path: "index.md", content: .text("# Retold export\n")),
            ExportFile(path: "transcripts/take.md", content: .text("# Capture take\n")),
            ExportFile(path: "audio/take.m4a", content: .audio(sourceFileName: "take.m4a")),
        ])
        let skipped = try ExportWriter.write(manifest, audioDirectory: audioDirectory, to: folder)
        XCTAssertTrue(skipped.isEmpty)
        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent("index.md"), encoding: .utf8),
                       "# Retold export\n")
        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent("transcripts/take.md"),
                                 encoding: .utf8), "# Capture take\n")
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("audio/take.m4a")), audioBytes)
    }

    func testMissingAudioIsSkippedAndReported() throws {
        let manifest = ExportManifest(files: [
            ExportFile(path: "index.md", content: .text("index")),
            ExportFile(path: "audio/gone.m4a", content: .audio(sourceFileName: "gone.m4a")),
        ])
        let skipped = try ExportWriter.write(manifest, audioDirectory: audioDirectory, to: folder)
        XCTAssertEqual(skipped, ["audio/gone.m4a"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("index.md").path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: folder.appendingPathComponent("audio/gone.m4a").path))
    }

    func testPathLikeSourceNameIsTreatedAsMissing() throws {
        for badName in ["../x.m4a", "a/b.m4a", "a\\b.m4a"] {
            let manifest = ExportManifest(files: [
                ExportFile(path: "audio/x.m4a", content: .audio(sourceFileName: badName)),
            ])
            let skipped = try ExportWriter.write(manifest, audioDirectory: audioDirectory, to: folder)
            XCTAssertEqual(skipped, ["audio/x.m4a"], badName)
        }
    }

    func testOverwritesExistingFiles() throws {
        try Data([1]).write(to: audioDirectory.appendingPathComponent("take.m4a"))
        let first = ExportManifest(files: [
            ExportFile(path: "index.md", content: .text("v1")),
            ExportFile(path: "audio/take.m4a", content: .audio(sourceFileName: "take.m4a")),
        ])
        _ = try ExportWriter.write(first, audioDirectory: audioDirectory, to: folder)
        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent("index.md"), encoding: .utf8), "v1")

        // A second export at the same folder replaces both kinds of file.
        try Data([2, 3]).write(to: audioDirectory.appendingPathComponent("take.m4a"))
        let second = ExportManifest(files: [
            ExportFile(path: "index.md", content: .text("v2")),
            ExportFile(path: "audio/take.m4a", content: .audio(sourceFileName: "take.m4a")),
        ])
        _ = try ExportWriter.write(second, audioDirectory: audioDirectory, to: folder)
        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent("index.md"), encoding: .utf8), "v2")
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("audio/take.m4a")), Data([2, 3]))
    }
}
