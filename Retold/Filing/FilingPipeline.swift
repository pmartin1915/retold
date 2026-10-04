import Foundation

enum FilingOutcome: Equatable, Sendable {
    /// Verified, merged proposals and the assembled questions. Nothing here is persisted or
    /// confirmed; the confirm flow (a later step) is the only writer of facts.
    case proposal(MergedExtract, [AssembledQuestion])
    /// The model path did not complete; the capture goes to the no-model screen (PLAN section 8).
    case noModel(FilingModelError)
}

/// Chunk -> one fresh model call per window -> verify -> merge -> assemble.
struct FilingPipeline: Sendable {
    let model: any FilingModel
    let counter: any TokenCounter
    var maxWindowTokens = 1_600
    var overlapTokens = 200

    /// Any failure in any window sends the whole capture to `.noModel`: a half-filed capture
    /// would look complete. An empty transcript has nothing to file and also lands there.
    func file(_ transcript: CompletedTranscript, periodTitles: [String]) async -> FilingOutcome {
        let windows = WindowChunker.windows(
            of: transcript,
            maxTokens: maxWindowTokens,
            overlapTokens: overlapTokens,
            counter: counter)
        guard !windows.isEmpty else { return .noModel(.other) }

        var results: [(window: TranscriptWindow, extract: WindowExtract)] = []
        for window in windows {
            do {
                let extract = try await model.extract(from: window, periodTitles: periodTitles)
                results.append((window, extract))
            } catch let error as FilingModelError {
                return .noModel(error)
            } catch is CancellationError {
                return .noModel(.cancelled)
            } catch {
                return .noModel(.other)
            }
        }
        let merged = ExtractMerger.merge(results, periodTitles: periodTitles)
        return .proposal(merged, TemplateAssembler.followUps(from: merged))
    }
}
