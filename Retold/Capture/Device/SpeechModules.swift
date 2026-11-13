import AVFoundation
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
    static func module(for route: TranscriptionRoute, live: Bool,
                       tuning: ListenTuning = .shipping) -> (any SpeechModule)? {
        switch route {
        case .speech(let id):
            // The option type is left to inference (Set or OptionSet, whichever the SDK declares).
            return SpeechTranscriber(
                locale: Locale(identifier: id),
                transcriptionOptions: [],
                reportingOptions: live ? (tuning.fastResults ? [.volatileResults, .fastResults] : [.volatileResults]) : [],
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

    /// One analyzer for `module`, set up as `tuning` says: model retention and priority, contextual
    /// strings (people's names and places), and the model prepared for `format` before audio
    /// arrives. Every step is best effort: a failure leaves the analyzer as the default one.
    static func makeAnalyzer(module: any SpeechModule, tuning: ListenTuning,
                             contextualStrings: [String], format: AVAudioFormat?) async -> SpeechAnalyzer {
        let analyzer: SpeechAnalyzer
        if tuning.prepareModel {
            analyzer = SpeechAnalyzer(modules: [module],
                                      options: SpeechAnalyzer.Options(priority: .userInitiated,
                                                                      modelRetention: .processLifetime))
        } else {
            analyzer = SpeechAnalyzer(modules: [module])
        }
        if tuning.useContext, !contextualStrings.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings[.general] = contextualStrings
            try? await analyzer.setContext(context)
        }
        if tuning.prepareModel {
            try? await analyzer.prepareToAnalyze(in: format)
        }
        return analyzer
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

/// Recognizer settings the listening self-test compares (listening hardening, 2026-11-12).
/// `.shipping` is what the app uses; it changes only when the self-test's numbers say so.
struct ListenTuning: Codable, Equatable, Sendable {
    var name: String
    /// SpeechTranscriber `.fastResults` on the live module: sooner volatile results, maybe less accurate.
    var fastResults: Bool
    /// SpeechAnalyzer options (user-initiated priority, model kept for the process) and
    /// `prepareToAnalyze` before the first buffer, so the first words are not waiting on a model load.
    var prepareModel: Bool
    /// At Stop, hand the converter's held-back frames to the analyzer (end of stream).
    var flushConverter: Bool
    /// AnalysisContext contextual strings: names and places the user has already filed.
    var useContext: Bool

    static let current = ListenTuning(name: "current", fastResults: false, prepareModel: false,
                                      flushConverter: false, useContext: false)
    static let steady = ListenTuning(name: "steady", fastResults: false, prepareModel: true,
                                     flushConverter: true, useContext: true)
    static let fast = ListenTuning(name: "fast", fastResults: true, prepareModel: true,
                                   flushConverter: true, useContext: true)
    /// What the capture engine and the file pass use.
    static let shipping = current
}
