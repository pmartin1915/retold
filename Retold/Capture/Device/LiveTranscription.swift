import AVFoundation
import Foundation
import os
import Speech

// The live-transcription half of a capture, moved out of LiveCaptureEngine (listening hardening,
// 2026-11-12) with no change of behavior. Nothing here touches AVAudioSession or UIKit, so the
// transcription harness (harness/) drives exactly this code with recorded buffers, on the iOS
// simulator or on a macOS host.

/// The audio file a capture writes: AAC at the input's rate and channel count (spec 7).
enum CaptureAudioFile {
    static func settings(for inputFormat: AVAudioFormat) -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: inputFormat.sampleRate,
            AVNumberOfChannelsKey: inputFormat.channelCount,
        ]
    }
}

/// One SpeechAnalyzer fed from tap buffers, plus the task that maps its results.
/// @unchecked Sendable: `resultsTask` is set once by startResults and read by finish/cancel; the
/// engine calls those one at a time on its serial effect task. The failure flag is lock-protected.
final class LiveTranscription: @unchecked Sendable {
    let analyzer: SpeechAnalyzer
    /// The analyzer's input; TapSink yields converted buffers into it.
    let input: AsyncStream<AnalyzerInput>.Continuation
    /// nil when the input format already equals the analyzer format (buffers pass through).
    let converter: AVAudioConverter?
    let tuning: ListenTuning
    private let results: AsyncThrowingStream<SpeechModules.SpeechResultValue, Error>
    private var resultsTask: Task<Void, Never>?
    private let resultsFailed = OSAllocatedUnfairLock(initialState: false)

    private init(analyzer: SpeechAnalyzer,
                 input: AsyncStream<AnalyzerInput>.Continuation,
                 converter: AVAudioConverter?,
                 tuning: ListenTuning,
                 results: AsyncThrowingStream<SpeechModules.SpeechResultValue, Error>) {
        self.analyzer = analyzer
        self.input = input
        self.converter = converter
        self.tuning = tuning
        self.results = results
    }

    /// Builds the converter, starts the analyzer and subscribes to its results. Throws if any step
    /// fails; an analyzer that was created is cancelled first. `module` must have been built with
    /// the same `tuning` (SpeechModules.module(for:live:tuning:)).
    static func start(module: any SpeechModule, inputFormat: AVAudioFormat,
                      tuning: ListenTuning = .shipping,
                      contextualStrings: [String] = []) async throws -> LiveTranscription {
        // Typed optional so this compiles whether the SDK returns AVAudioFormat or AVAudioFormat?.
        let bestFormat: AVAudioFormat? = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module])
        guard let analyzerFormat = bestFormat else { throw LiveTranscriptionError.converterUnavailable }
        var converter: AVAudioConverter?
        if inputFormat != analyzerFormat {
            guard let made = AVAudioConverter(from: inputFormat, to: analyzerFormat) else {
                throw LiveTranscriptionError.converterUnavailable
            }
            converter = made
        }   // identical formats (rate, channels, sample type): pass buffers through
        let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
        let analyzer = await SpeechModules.makeAnalyzer(module: module, tuning: tuning,
                                                        contextualStrings: contextualStrings,
                                                        format: analyzerFormat)
        do {
            try await analyzer.start(inputSequence: inputSequence)
        } catch {
            await analyzer.cancelAndFinishNow()
            throw error
        }
        // The mapped stream (Sendable) is what the results task captures, not the module.
        let results = SpeechModules.results(of: module)
        return LiveTranscription(analyzer: analyzer, input: inputBuilder,
                                 converter: converter, tuning: tuning, results: results)
    }

    /// Starts the task that hands each result, in order, to `handler`. Call once.
    func startResults(_ handler: @escaping @Sendable (SpeechModules.SpeechResultValue) -> Void) {
        let results = self.results
        let failed = resultsFailed
        resultsTask = Task {
            do {
                for try await result in results {
                    handler(result)
                }
            } catch {
                failed.withLock { $0 = true }
            }
        }
    }

    /// Ends the input, finalizes through the end of the input, and waits until every remaining
    /// result has been handed to the handler. True only if the run finished without error.
    /// Call after the last buffer reached `sink`; with `tuning.flushConverter` the converter's
    /// held-back frames go to the analyzer first.
    func finish(flushing sink: TapSink?) async -> Bool {
        if tuning.flushConverter {
            sink?.flush()
        }
        input.finish()
        do {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
        } catch {
            resultsFailed.withLock { $0 = true }
            await analyzer.cancelAndFinishNow()     // so the results stream terminates
        }
        if let resultsTask {
            await resultsTask.value     // drain the remaining finals
        }
        return !resultsFailed.withLock { $0 }
    }

    /// Abandons the run (a failed start): no more results are delivered.
    func cancel() async {
        input.finish()
        await analyzer.cancelAndFinishNow()
        resultsTask?.cancel()
    }
}

enum LiveTranscriptionError: Error {
    case converterUnavailable
}

/// The tap's only contact: writes each buffer to the audio file, then converts and forwards
/// it to the SpeechAnalyzer input. A write error is flagged, never thrown (a tap must not
/// throw). @unchecked Sendable: the tap delivers buffers on the audio thread; the only state
/// read from elsewhere is lock-protected.
final class TapSink: @unchecked Sendable {
    private let file: AVAudioFile
    private let converter: AVAudioConverter?
    private let builder: AsyncStream<AnalyzerInput>.Continuation?
    private let writeErrorFlag = OSAllocatedUnfairLock(initialState: false)
    /// Buffers written to the file but never handed to the analyzer because conversion produced
    /// nothing (diagnostics: a dropped chunk the live text never hears).
    private let convertDropCount = OSAllocatedUnfairLock(initialState: 0)

    var writeError: Bool { writeErrorFlag.withLock { $0 } }
    var convertDrops: Int { convertDropCount.withLock { $0 } }

    init(file: AVAudioFile, converter: AVAudioConverter?,
         builder: AsyncStream<AnalyzerInput>.Continuation?) {
        self.file = file
        self.converter = converter
        self.builder = builder
    }

    func consume(_ buffer: AVAudioPCMBuffer) {
        do {
            try file.write(from: buffer)
        } catch {
            writeErrorFlag.withLock { $0 = true }
            return
        }
        guard let builder else { return }
        if converter != nil {
            guard let converted = convert(buffer) else {
                convertDropCount.withLock { $0 += 1 }
                return
            }
            builder.yield(AnalyzerInput(buffer: converted))
        } else {
            builder.yield(AnalyzerInput(buffer: buffer))
        }
    }

    /// Converts what the converter still holds (end of stream) and hands it to the analyzer.
    /// Call once, after the last consume (the tap is removed and the engine stopped).
    func flush() {
        guard let converter, let builder else { return }
        guard let output = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: 8192) else {
            return
        }
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            inputStatus.pointee = .endOfStream
            return nil
        }
        if status != .error, output.frameLength > 0 {
            builder.yield(AnalyzerInput(buffer: output))
        }
    }

    private func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let converter else { return nil }
        let outputFormat = converter.outputFormat
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            return nil
        }
        var providedInput = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if providedInput {
                inputStatus.pointee = .noDataNow
                return nil
            }
            providedInput = true
            inputStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, output.frameLength > 0 else { return nil }
        return output
    }
}
