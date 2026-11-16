import AVFoundation
import SwiftData
import XCTest
@testable import Retold

/// The Whisper pass after Stop, end to end with the real model on the simulator's CPU
/// (docs/WHISPER-PASS-SPEC.md section 8). The simulator has no Apple speech route, so the capture
/// is set up as the importer leaves it after a completed live run: .live with Apple's words, marked.
/// The coordinator's file pass then runs Whisper turbo over the saved m4a and completes the capture.
final class WhisperPassHarnessTests: XCTestCase {
    @MainActor
    func testWhisperPassCompletesMarkedCaptureWithWhisperWords() async throws {
        let bundle = Bundle(for: WhisperPassHarnessTests.self)
        let directory = try XCTUnwrap(bundle.url(forResource: "generated", withExtension: nil),
                                      "no generated fixtures in the test bundle")
        let fixture = try XCTUnwrap(HarnessFixture.load(from: directory).first { $0.name == "names-places-a" })

        // The model, as Settings leaves it: downloaded and marked (the pass loads it itself).
        let spec = WhisperModelSpec.turbo
        if WhisperModelStore.downloadedFolder(for: spec) == nil {
            let folder = try await WhisperModelStore.download(spec) { tenth in
                print("LISTEN_HARNESS: whisper pass test: download \(tenth * 10)%")
            }
            WhisperModelStore.recordDownload(of: spec, at: folder)
        }
        XCTAssertTrue(WhisperAfterStopPass().isReady())

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper-pass-harness-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let files = CaptureFiles(root: root)
        try files.prepare()
        let captureID = UUID()
        try Self.writeCaptureAudio(from: fixture.audioURL, to: files.audioURL(for: captureID))

        let container = try RetoldSchema.makeInMemoryContainer()
        let apple = [TranscriptSegment(text: "apple heard these words", start: 0, end: 2, isFinal: true)]
        let capture = Capture(audioFileName: CaptureFiles.audioFileName(for: captureID), duration: 30)
        capture.id = captureID
        try capture.updateTranscript(apple, status: .live)
        let context = ModelContext(container)
        context.insert(capture)
        try context.save()

        let suite = "whisper-pass-harness-\(UUID().uuidString)"
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suite) }
        let ledger = WhisperPassLedger(defaults: try XCTUnwrap(UserDefaults(suiteName: suite)))
        ledger.mark(captureID)

        let protector = MockFileProtector()
        let importer = JournalImporter(files: files, durationProbe: MockDurationProbe(), protector: protector,
                                       afterStopPass: WhisperAfterStopPass(), ledger: ledger)
        let coordinator = CaptureCoordinator(
            engine: MockCaptureEngine(),
            fileTranscriber: MockFileTranscriber(),
            routeProvider: { .speech(localeID: "en_US") },
            files: files,
            importer: importer,
            container: container,
            initialPermission: .granted,
            protectedDataAvailable: true,
            makeWriter: { files, id in try JournalWriter(files: files, captureID: id, protector: protector) },
            whisperTimeLimit: { _ in 1_200 })     // the simulator's CPU, not the phone's Neural Engine

        let start = Date()
        await coordinator.retranscribePending()
        print("LISTEN_HARNESS: whisper pass test: pass took \(Int(Date().timeIntervalSince(start)))s")

        let cid = captureID
        let reloaded = try XCTUnwrap(ModelContext(container).fetch(
            FetchDescriptor<Capture>(predicate: #Predicate { $0.id == cid })).first)
        XCTAssertEqual(reloaded.transcriptionStatus, .complete)
        XCTAssertFalse(ledger.isMarked(captureID))
        let text = reloaded.transcript.map(\.text).joined(separator: " ")
        print("LISTEN_HARNESS: whisper pass test: kept \"\(text)\"")
        XCTAssertNotEqual(reloaded.transcript, apple, "Whisper's words were not kept")
        let lower = text.lowercased()
        let heardNames = fixture.contextualStrings.filter { lower.contains($0.lowercased()) }
        print("LISTEN_HARNESS: whisper pass test: names heard \(heardNames.count)/\(fixture.contextualStrings.count)")
        XCTAssertGreaterThan(heardNames.count, 0, "none of the fixture's names in Whisper's transcript")
    }

    /// The fixture re-encoded as the app saves a capture (CaptureAudioFile: AAC at the input rate).
    private static func writeCaptureAudio(from source: URL, to destination: URL) throws {
        let input = try AVAudioFile(forReading: source)
        let format = input.processingFormat
        let output = try AVAudioFile(forWriting: destination, settings: CaptureAudioFile.settings(for: format),
                                     commonFormat: .pcmFormatFloat32, interleaved: false)
        while input.framePosition < input.length {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096) else { break }
            try input.read(into: buffer, frameCount: 4096)
            if buffer.frameLength == 0 { break }
            try output.write(from: buffer)
        }
        output.close()
    }
}
