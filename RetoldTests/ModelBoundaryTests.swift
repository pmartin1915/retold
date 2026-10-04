import Foundation
import XCTest
@testable import Retold

/// R7 spec section 8.4, the Rule-1 wall's first item: the model file cannot write facts. This is
/// the "module that cannot see the persistence constructors" (Sol R1 audit), done as a source scan.
final class ModelBoundaryTests: XCTestCase {
    private let modelFile = "Retold/Filing/FoundationFilingModel.swift"
    private let forbidden = ["ModelContext", "insert(", "Person(", "Place(", "Episode(",
                             "Question(", "Period(", "Detail(", "import SwiftData"]

    func testOnlyFoundationFilingModelImportsFoundationModels() throws {
        let root = repoRoot()
        let importers = try swiftFiles(under: root.appendingPathComponent("Retold"))
            .filter { try String(contentsOf: $0, encoding: .utf8).contains("import FoundationModels") }
            .map { relative($0, to: root) }
        XCTAssertEqual(importers, [modelFile])
    }

    func testModelFileNamesNoPersistence() throws {
        let text = try String(contentsOf: repoRoot().appendingPathComponent(modelFile), encoding: .utf8)
        for name in forbidden {
            XCTAssertFalse(text.contains(name), "\(modelFile) names \(name)")
        }
    }

    func testDeviceTokenCounterOverCounts() {
        let counter = DeviceTokenCounter()
        XCTAssertEqual(counter.count(""), 0)
        XCTAssertEqual(counter.count("a"), 1)
        XCTAssertEqual(counter.count("abcdef"), 2)
        XCTAssertEqual(counter.count("abcdefg"), 3)
    }

    private func swiftFiles(under dir: URL) throws -> [URL] {
        guard let walker = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else {
            XCTFail("cannot enumerate \(dir.path)")
            return []
        }
        let files = walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        XCTAssertFalse(files.isEmpty, "no Swift files under \(dir.path)")
        return files.sorted { $0.path < $1.path }
    }

    private func relative(_ url: URL, to root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath) else { return path }
        return String(path.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    /// The repo root is the first directory above this file that holds project.yml.
    private func repoRoot(file: StaticString = #filePath, line: UInt = #line) -> URL {
        var url = URL(fileURLWithPath: "\(file)").deletingLastPathComponent()
        let fileManager = FileManager.default
        while true {
            if fileManager.fileExists(atPath: url.appendingPathComponent("project.yml").path) {
                return url
            }
            let parent = url.deletingLastPathComponent()
            if parent == url { break }
            url = parent
        }
        XCTFail("repo root (a directory containing project.yml) not found above \(file)", file: file, line: line)
        return url
    }
}
