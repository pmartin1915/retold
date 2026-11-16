import AVFoundation
import Foundation
import Speech

/// Re-transcribes a closed audio file with SpeechAnalyzer (spec 7). Yields one final segment
/// per final result, in file-time order, then finishes; throws on failure. .audioOnly finishes
/// immediately with no segments.
struct SpeechFileTranscriber: FileTranscriber {
    /// The listening self-test compares tunings; the app uses the default.
    var tuning: ListenTuning = .shipping
    var contextualStrings: [String] = []

    func transcribe(audioURL: URL, route: TranscriptionRoute) -> AsyncThrowingStream<TranscriptSegment, Error> {
        let (output, continuation) = AsyncThrowingStream<TranscriptSegment, Error>.makeStream()
        let tuning = self.tuning
        let contextualStrings = self.contextualStrings
        let task = Task {
            guard let module = SpeechModules.module(for: route, live: false, tuning: tuning) else {
                continuation.finish()       // .audioOnly
                return
            }
            do {
                let file = try AVAudioFile(forReading: audioURL)
                // Subscribe to results before analysis starts, then analyze the whole file.
                let results = SpeechModules.results(of: module)
                let consumer = Task {
                    for try await result in results where result.isFinal {
                        continuation.yield(TranscriptSegment(text: result.text,
                                                             start: result.start,
                                                             end: result.end,
                                                             isFinal: true))
                    }
                }
                let analyzer = await SpeechModules.makeAnalyzer(module: module, tuning: tuning,
                                                                contextualStrings: contextualStrings,
                                                                format: nil)
                do {
                    if let lastSample = try await analyzer.analyzeSequence(from: file) {
                        try await analyzer.finalizeAndFinish(through: lastSample)
                    } else {
                        await analyzer.cancelAndFinishNow()
                    }
                    try await withTaskCancellationHandler {
                        try await consumer.value
                    } onCancel: {
                        consumer.cancel()
                    }
                } catch {
                    consumer.cancel()
                    await analyzer.cancelAndFinishNow()
                    throw error
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
        return output
    }
}
