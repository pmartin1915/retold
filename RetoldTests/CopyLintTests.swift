import Foundation
import XCTest
@testable import Retold

/// PLAN section 5.2 item 2: the wellness copy lint. Forbidden terms take the app out of the FDA
/// general-wellness safe harbour; the app prompts, it does not assess.
@MainActor
final class CopyLintTests: XCTestCase {
    func testEveryForbiddenTermIsCaught() {
        let samples = [
            "Take the memory test", "Your score this week", "improve your memory", "improved the memory",
            "A cognitive exercise", "Signs of decline", "We assess you", "An assessment", "Screening for change",
            "Early MCI", "Dementia care", "Alzheimer's", "A diagnosis", "It can treat", "A treatment",
            "Not a cure", "Prevent forgetting", "Brain training", "Sharpen your mind", "PTSD", "Depression",
            "ADHD", "Anxiety relief", "Trauma work", "Therapy session",
        ]
        for sample in samples {
            XCTAssertFalse(CopyLint.violations(in: sample).isEmpty, sample)
        }
    }

    func testMatchingIsCaseInsensitiveAndCurlyApostropheSafe() {
        XCTAssertFalse(CopyLint.violations(in: "MEMORY TEST").isEmpty)
        XCTAssertFalse(CopyLint.violations(in: "Alzheimer\u{2019}s").isEmpty)
    }

    func testInflectedAndPlantedTermsAreCaught() {
        XCTAssertEqual(CopyLint.violations(in: "It was cured"), ["cured"])
        let planted = "Get your memory SCORE today"
        XCTAssertEqual(CopyLint.violations(in: planted), ["score"])
    }

    func testPlainWellnessCopyPasses() {
        let clean = [
            "Retold records your voice while you talk through a memory. Recordings stay on this phone.",
            "One question waiting", "Remember more, reflect more", "Scoreboard", "A curious mind",
            "Screen recording is off", "Improve the audio quality",
        ]
        for sample in clean {
            XCTAssertEqual(CopyLint.violations(in: sample), [], sample)
        }
    }

    func testEveryAuthoredTemplateIsCleanCopy() {
        for template in FilingTemplates.all {
            XCTAssertEqual(CopyLint.violations(in: template.pattern), [], template.id)
        }
    }

    // MARK: - Scanning the repo's user-facing sources

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private func isFile(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }

    private func files(under directory: String, recursive: Bool = true, where include: (URL) -> Bool) -> [URL] {
        let root = directory.isEmpty ? repoRoot : repoRoot.appendingPathComponent(directory)
        if recursive {
            guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
            return walker.compactMap { $0 as? URL }.filter { isFile($0) && include($0) }
        }
        let listed = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return listed.filter { isFile($0) && include($0) }
    }

    /// Everything the policy names: string catalogs, in-repo App Store metadata, privacy policy source.
    private func scannedFiles() -> [URL] {
        var urls = files(under: "Retold") { $0.pathExtension == "xcstrings" }
        urls += files(under: "AppStore") { _ in true }
        urls += files(under: "fastlane/metadata") { _ in true }
        let policyExtensions: Set<String> = ["md", "markdown", "html", "txt"]
        for directory in ["", "docs", "AppStore", "Retold"] {
            urls += files(under: directory, recursive: false) {
                $0.lastPathComponent.lowercased().hasPrefix("privacy") && policyExtensions.contains($0.pathExtension.lowercased())
            }
        }
        return urls
    }

    func testRepoRootIsFound() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("project.yml").path))
    }

    func testUserFacingStringsInProjectYmlAreClean() throws {
        let text = try String(contentsOf: repoRoot.appendingPathComponent("project.yml"), encoding: .utf8)
        let lines = text.split(separator: "\n").map(String.init)
            .filter { $0.contains("UsageDescription") || $0.contains("CFBundleDisplayName") }
        XCTAssertFalse(lines.isEmpty, "the scanner must find the Info.plist strings it exists to guard")
        for line in lines {
            XCTAssertEqual(CopyLint.violations(in: line), [], line)
        }
    }

    func testScannedCopyFilesAreClean() throws {
        for url in scannedFiles() {
            let text = try String(contentsOf: url, encoding: .utf8)
            XCTAssertEqual(CopyLint.violations(in: text), [], url.lastPathComponent)
        }
    }
}
