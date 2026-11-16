import Foundation

// The one app declaration the macOS build needs from Retold/Capture/CaptureEngine.swift, which
// cannot compile for macOS as a whole. Keep the signature identical to the app's.
protocol FileTranscriber: Sendable {
    func transcribe(audioURL: URL, route: TranscriptionRoute) -> AsyncThrowingStream<TranscriptSegment, Error>
}
