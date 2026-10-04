import AVFoundation
import Foundation
import Speech

/// Re-transcribes a closed audio file with SpeechAnalyzer (spec 7). Yields one final segment
/// per final result, in file-time order, then finishes; throws on failure. .audioOnly finishes
/// immediately with no segments.
struct SpeechFileTranscriber: FileTranscriber {
    func transcribe(audioURL: URL, route: TranscriptionRoute) -> AsyncThrowingStream<TranscriptSegment, Error> {
        let (output, continuation) = AsyncThrowingStream<TranscriptSegment, Error>.makeStream()
        let task = Task {
            guard let module = SpeechModules.module(for: route, live: false) else {
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
                let analyzer = SpeechAnalyzer(modules: [module])
                if let lastSample = try await analyzer.analyzeSequence(from: file) {
                    try await analyzer.finalizeAndFinish(through: lastSample)
                } else {
                    await analyzer.cancelAndFinishNow()
                }
                try await consumer.value
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
        return output
    }
}
