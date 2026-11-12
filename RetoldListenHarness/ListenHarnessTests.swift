import XCTest
@testable import Retold

/// The transcription harness on the iOS simulator (scheme RetoldListenHarness, workflow
/// listen-harness.yml; never part of the Retold scheme). Fixtures are bundled as resources by the
/// workflow (harness/generated). The raw report is attached to the result bundle as
/// listen-harness.json; harness/score.py scores it. This test never fails on a transcription
/// result: it measures. It fails only if there are no fixtures.
final class ListenHarnessTests: XCTestCase {
    func testListenHarness() async throws {
        let bundle = Bundle(for: ListenHarnessTests.self)
        guard let directory = bundle.url(forResource: "generated", withExtension: nil) else {
            XCTFail("no generated fixtures in the test bundle")
            return
        }
        let fixtures = HarnessFixture.load(from: directory)
        XCTAssertFalse(fixtures.isEmpty, "no fixtures in \(directory.path)")
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("listen-harness", isDirectory: true)
        let report = await ListenHarness.runAll(fixtures: fixtures, host: "iOS simulator", workDirectory: work)
        let data = ListenHarness.encode(report)
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "listen-harness.json"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
