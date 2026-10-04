import CoreMedia
import Foundation
import Speech

/// One place that maps a TranscriptionRoute to its SpeechAnalyzer module, so the route probe,
/// the file transcriber and the live engine agree. Also the one place that maps a Speech result
/// to a plain value, so Rule 1 (verbatim final text) lives in a single helper.
enum SpeechModules {
    /// The module for `route`, or nil for .audioOnly. `live` adds .volatileResults to the
    /// reporting options; both module kinds always ask for .audioTimeRange so segment times
    /// are audio-file time.
    static func module(for route: TranscriptionRoute, live: Bool) -> (any SpeechModule)? {
        switch route {
        case .speech(let id):
            return SpeechTranscriber(
                locale: Locale(identifier: id),
                transcriptionOptions: [],
                reportingOptions: live ? [.volatileResults] : [],
                attributeOptions: [.audioTimeRange])
        case .dictation(let id):
            return DictationTranscriber(
                locale: Locale(identifier: id),
                contentHints: [],
                transcriptionOptions: [],
                reportingOptions: live ? [.volatileResults] : [],
                attributeOptions: [.audioTimeRange])
        case .audioOnly:
            return nil
        }
    }

    /// A route-agnostic result value; callers never switch on the module type twice.
    struct SpeechResultValue: Sendable {
        let text: String       // String(result.text.characters), verbatim (Rule 1)
        let start: TimeInterval
        let end: TimeInterval
        let isFinal: Bool
    }

    /// The module's result stream mapped to SpeechResultValue. Ends by throwing on error.
    static func results(of module: any SpeechModule) -> AsyncThrowingStream<SpeechResultValue, Error> {
        if let transcriber = module as? SpeechTranscriber {
            return mapped(transcriber.results) { result in
                SpeechResultValue(text: String(result.text.characters),
                                  start: result.range.start.seconds,
                                  end: CMTimeRangeGetEnd(result.range).seconds,
                                  isFinal: result.isFinal)
            }
        }
        if let transcriber = module as? DictationTranscriber {
            return mapped(transcriber.results) { result in
                SpeechResultValue(text: String(result.text.characters),
                                  start: result.range.start.seconds,
                                  end: CMTimeRangeGetEnd(result.range).seconds,
                                  isFinal: result.isFinal)
            }
        }
        return AsyncThrowingStream { $0.finish() }
    }

    /// Generic over the SDK's result sequence type; `sending` moves it into the task, so it need
    /// not be Sendable.
    private static func mapped<S: AsyncSequence>(
        _ stream: sending S,
        _ transform: @escaping @Sendable (S.Element) -> SpeechResultValue
    ) -> AsyncThrowingStream<SpeechResultValue, Error> {
        let (output, continuation) = AsyncThrowingStream<SpeechResultValue, Error>.makeStream()
        let task = Task {
            do {
                for try await result in stream {
                    continuation.yield(transform(result))
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
