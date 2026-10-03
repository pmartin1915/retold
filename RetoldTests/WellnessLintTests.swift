import Foundation
import XCTest
@testable import Retold

@MainActor
final class WellnessLintTests: XCTestCase {
    func testEachTermIsDetected() {
        let cases: [(term: String, sentence: String)] = [
            ("memory test", "This is not a memory test."),
            ("memory loss", "Many people worry about memory loss."),
            ("score", "Check your score each week."),
            ("improve memory", "Puzzles that improve memory."),
            ("cognitive", "Cognitive training games."),
            ("decline", "Track decline over time."),
            ("assess", "We assess users gently."),
            ("screen", "Screen for early signs."),
            ("MCI", "A family history of MCI."),
            ("dementia", "Not about dementia."),
            ("Alzheimer", "Stories about Alzheimer's."),
            ("diagnose", "We never diagnose conditions."),
            ("treat", "It may treat symptoms."),
            ("cure", "There is no cure."),
            ("prevent", "Help prevent isolation."),
            ("brain", "Train your brain daily."),
            ("sharpen", "Sharpen your recall."),
            ("PTSD", "Telling stories about PTSD."),
            ("depression", "Living with depression."),
            ("ADHD", "A grandchild with ADHD."),
            ("anxiety", "Moments of anxiety."),
            ("trauma", "Working through trauma."),
            ("therapy", "Not a replacement for therapy."),
        ]
        XCTAssertEqual(cases.count, 23)
        for entry in cases {
            let violations = WellnessLint.violations(in: entry.sentence)
            XCTAssertTrue(violations.contains { $0.term == entry.term },
                "\(entry.term) not found in: \(entry.sentence)")
        }
    }

    func testNearMissesAreClean() {
        for text in ["Take a screenshot", "Keep it secure", "I was curious", "an underscore", "It was a treasure"] {
            XCTAssertTrue(WellnessLint.violations(in: text).isEmpty, text)
        }
    }

    func testAppCopyIsNonEmptyAndClean() {
        XCTAssertFalse(AppCopy.all.isEmpty)
        for copy in AppCopy.all {
            let violations = WellnessLint.violations(in: copy)
            XCTAssertTrue(violations.isEmpty,
                "\(copy): \(violations.map(\.term).joined(separator: ", "))")
        }
    }

    func testRepoFacingCopyIsClean() {
        let root = repoRoot()
        var scanned: [String] = []

        guard let projectYML = try? String(contentsOf: root.appendingPathComponent("project.yml"), encoding: .utf8) else {
            XCTFail("project.yml is unreadable at \(root.path)")
            return
        }
        guard let usageRegex = try? NSRegularExpression(pattern: #"NS\w+UsageDescription:\s*"([^"]*)""#) else { return }
        var usageCount = 0
        for match in usageRegex.matches(in: projectYML, range: NSRange(projectYML.startIndex..., in: projectYML)) {
            guard let valueRange = Range(match.range(at: 1), in: projectYML) else { continue }
            scanned.append(String(projectYML[valueRange]))
            usageCount += 1
        }
        XCTAssertGreaterThan(usageCount, 0, "no NS*UsageDescription values found in project.yml")

        func collect(_ pathExtension: String, under relative: String) {
            let directory = root.appendingPathComponent(relative)
            guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
            else { return }
            for case let url as URL in enumerator where url.pathExtension == pathExtension {
                guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                    XCTFail("unreadable file: \(url.lastPathComponent)")
                    continue
                }
                scanned.append(text)
            }
        }
        collect("xcstrings", under: "Retold")
        collect("txt", under: "metadata")

        XCTAssertFalse(scanned.isEmpty)
        for text in scanned {
            let violations = WellnessLint.violations(in: text)
            XCTAssertTrue(violations.isEmpty,
                "wellness terms \(violations.map(\.term)) in scanned copy: \(text.prefix(80))")
        }
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
