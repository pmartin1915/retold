import Foundation
import XCTest
@testable import Retold

final class ExportArchiverTests: XCTestCase {
    private var root: URL!
    private var audioDirectory: URL { root.appendingPathComponent("audio", isDirectory: true) }
    private var workDirectory: URL { root.appendingPathComponent("work", isDirectory: true) }
    private let exportName = "Retold export 2026-10-04"

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("retold-export-archiver", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    private func manifest(audioName: String = "take.m4a") -> ExportManifest {
        ExportManifest(files: [
            ExportFile(path: "index.md", content: .text("# Retold export\n")),
            ExportFile(path: "audio/take.m4a", content: .audio(sourceFileName: audioName)),
        ])
    }

    private func makeAudio() throws {
        try Data([0, 1, 2, 3, 250]).write(to: audioDirectory.appendingPathComponent("take.m4a"))
    }

    private func zips(in directory: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".zip") }
    }

    func testArchiveIsZip() throws {
        try makeAudio()
        let url = try ExportArchiver.makeArchive(
            manifest(), audioDirectory: audioDirectory, workDirectory: workDirectory, name: exportName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 0)
        XCTAssertEqual(Array(data.prefix(4)), [0x50, 0x4B, 0x03, 0x04])
    }

    func testArchiveNamed() throws {
        try makeAudio()
        let url = try ExportArchiver.makeArchive(
            manifest(), audioDirectory: audioDirectory, workDirectory: workDirectory, name: exportName)
        XCTAssertEqual(url.lastPathComponent, "\(exportName).zip")
        XCTAssertEqual(url.deletingLastPathComponent().standardizedFileURL.path,
                       workDirectory.standardizedFileURL.path)
    }

    func testWorkFolderRemoved() throws {
        try makeAudio()
        _ = try ExportArchiver.makeArchive(
            manifest(), audioDirectory: audioDirectory, workDirectory: workDirectory, name: exportName)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: workDirectory.appendingPathComponent(exportName).path))
    }

    func testSecondRunReplacesFirst() throws {
        try makeAudio()
        _ = try ExportArchiver.makeArchive(
            manifest(), audioDirectory: audioDirectory, workDirectory: workDirectory, name: "Retold export one")
        _ = try ExportArchiver.makeArchive(
            manifest(), audioDirectory: audioDirectory, workDirectory: workDirectory, name: "Retold export two")
        XCTAssertEqual(try zips(in: workDirectory), ["Retold export two.zip"])
    }

    func testMissingAudioDoesNotFail() throws {
        // No audio file is written: the manifest still lists it.
        let url = try ExportArchiver.makeArchive(
            manifest(audioName: "gone.m4a"),
            audioDirectory: audioDirectory, workDirectory: workDirectory, name: exportName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testSweepRemovesWorkDirectory() throws {
        try makeAudio()
        _ = try ExportArchiver.makeArchive(
            manifest(), audioDirectory: audioDirectory, workDirectory: workDirectory, name: exportName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: workDirectory.path))
        ExportArchiver.sweep(workDirectory: workDirectory)
        XCTAssertFalse(FileManager.default.fileExists(atPath: workDirectory.path))
    }
}
