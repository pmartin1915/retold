import Foundation
import SwiftData

// Imports closed journals into the store, while protected data is available, and adopts orphan
// audio files. Order 4 -> 5 -> 6 (save, protect, remove journal) makes a crash safe at any point:
// a re-run finds the row and finishes only the remaining steps. No duplicate Capture is created.

@MainActor
struct JournalImporter {
    let files: CaptureFiles
    let durationProbe: any AudioDurationProbe
    let protector: any FileProtector

    struct Report: Equatable {
        var imported: [UUID] = []          // Capture created from a journal
        var adoptedOrphans: [UUID] = []    // Capture created from an audio file with no importable journal
        var alreadyPresent: [UUID] = []
        var quarantined: [URL] = []        // journals renamed to .bad
        var failed: [URL] = []             // save/write failed; file left for the next import
        var protectFailed: [UUID] = []     // journal kept so protection is retried
    }

    /// Caller guarantees protected data is available. Uses a FRESH ModelContext(container), never
    /// mainContext, so rollback/save cannot touch unrelated edits. `excluding` = the live capture.
    func importAll(into container: ModelContainer, excluding: UUID?) -> Report {
        var report = Report()
        let context = ModelContext(container)
        context.autosaveEnabled = false

        // Pass 1: journals, in journalURLs order.
        let urls = (try? JournalReader.journalURLs(in: files)) ?? []
        for url in urls {
            guard let cid = CaptureFiles.captureID(fromFileName: url.lastPathComponent),
                  cid != excluding else { continue }

            let replay: JournalReplay
            do {
                replay = try JournalReader.read(url)
            } catch is JournalError {
                // .missingBegin / .mixedCaptures: quarantine; the audio is picked up in pass 2.
                quarantine(url, report: &report)
                continue
            } catch {
                // An I/O error is not a bad journal: leave it for the next import.
                report.failed.append(url)
                continue
            }

            let existing: Capture?
            do {
                existing = try fetchCapture(cid, context: context)
            } catch {
                report.failed.append(url)
                continue
            }
            if existing != nil {
                report.alreadyPresent.append(cid)
                finishJournal(url: url, captureID: cid, corrupt: replay.corruptLine != nil,
                              report: &report)
                continue
            }

            // Build the row. `begin` always exists: the reader guarantees it.
            let begin = replay.records.first { $0.kind == .begin }
            let audioURL = files.audioURL(for: cid)
            let endRecord = replay.records.last { $0.kind == .end }
            let journaled = endRecord?.duration.flatMap { $0 > 0 ? $0 : nil }
            let duration = journaled ?? durationProbe.duration(of: audioURL) ?? 0
            let capture = Capture(
                audioFileName: begin?.audioFileName ?? CaptureFiles.audioFileName(for: cid),
                duration: duration,
                createdAt: begin?.createdAt ?? Date()
            )
            capture.id = cid
            capture.answersQuestionID = begin?.answersQuestionID
            let segments = replay.records
                .filter { $0.kind == .segment }
                .map {
                    TranscriptSegment(text: $0.text ?? "", start: $0.start ?? 0,
                                      end: $0.end ?? 0, isFinal: true)
                }

            // Status per §4.3, using `try`: a throw means the journal is left for the next import.
            do {
                try writeStatus(to: capture, replay: replay, segments: segments)
            } catch {
                report.failed.append(url)
                continue
            }

            context.insert(capture)
            do {
                try context.save()
            } catch {
                context.rollback()
                report.failed.append(url)      // file left for the next import
                continue
            }

            report.imported.append(cid)
            finishJournal(url: url, captureID: cid, corrupt: replay.corruptLine != nil,
                          report: &report)
        }

        importOrphanAudio(into: context, excluding: excluding, report: &report)
        return report
    }

    /// §4.3: what the importer writes to Capture.transcriptionStatus.
    private func writeStatus(to capture: Capture, replay: JournalReplay,
                             segments: [TranscriptSegment]) throws {
        let begin = replay.records.first { $0.kind == .begin }
        let route = begin?.route.flatMap { TranscriptionRoute(journalTag: $0) }
        let hasEnd = replay.records.contains { $0.kind == .end }
        // "completed": at least one transcriberEnded, none with completed != true, and every run
        // that started has a completed transcriberEnded (a hole in any run forces the file pass).
        let ended = replay.records.filter { $0.kind == .transcriberEnded }
        let startedRuns = Set(replay.records.filter { $0.kind == .runStarted }.compactMap(\.run))
        let completedRuns = Set(ended.filter { $0.completed == true }.compactMap(\.run))
        let completed = !ended.isEmpty
            && ended.allSatisfy { $0.completed == true }
            && startedRuns.isSubset(of: completedRuns)

        switch route {
        case .some(.speech) where completed && hasEnd,
             .some(.dictation) where completed && hasEnd:
            try capture.completeTranscript(segments)                 // -> .complete
        case .some(.audioOnly):
            try capture.updateTranscript([], status: .live)          // queued for the file pass
        default:
            // Died, ended false, no .end, or an unparseable/missing route: keep the partial and
            // queue for the file pass.
            try capture.updateTranscript(segments, status: .live)
        }
    }

    // MARK: - Steps 5 and 6 (protect the audio, then remove or quarantine the journal)

    private func finishJournal(url: URL, captureID: UUID, corrupt: Bool, report: inout Report) {
        let audioURL = files.audioURL(for: captureID)
        if FileManager.default.fileExists(atPath: audioURL.path) {
            do {
                try protector.protect(audioURL, as: ProtectionPlan.afterImport)
            } catch {
                // The journal survives, so the next import retries through the alreadyPresent row.
                report.protectFailed.append(captureID)
                return
            }
        }
        if corrupt {
            quarantine(url, report: &report)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func quarantine(_ url: URL, report: inout Report) {
        let badURL = url.appendingPathExtension("bad")
        do {
            try FileManager.default.moveItem(at: url, to: badURL)
            report.quarantined.append(badURL)
        } catch {
            report.failed.append(url)
        }
    }

    // MARK: - Pass 2: orphan audio

    private func importOrphanAudio(into context: ModelContext, excluding: UUID?,
                                   report: inout Report) {
        let audioURLs = ((try? FileManager.default.contentsOfDirectory(
            at: files.audioDirectory, includingPropertiesForKeys: nil
        )) ?? [])
            .filter { CaptureFiles.captureID(fromFileName: $0.lastPathComponent) != nil }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        for audioURL in audioURLs {
            guard let cid = CaptureFiles.captureID(fromFileName: audioURL.lastPathComponent),
                  cid != excluding,
                  !FileManager.default.fileExists(atPath: files.journalURL(for: cid).path)
            else { continue }
            // A fetch error is not "absent": skip rather than risk a duplicate row.
            let existing: Capture?
            do { existing = try fetchCapture(cid, context: context) } catch { continue }
            guard existing == nil else { continue }

            let attributes = try? FileManager.default.attributesOfItem(atPath: audioURL.path)
            let capture = Capture(
                audioFileName: audioURL.lastPathComponent,
                duration: durationProbe.duration(of: audioURL) ?? 0,
                createdAt: attributes?[.creationDate] as? Date ?? Date()
            )
            capture.id = cid
            // A crash between creating the file and .begin, a journal-open failure, or a
            // quarantined journal: the recording is never lost to a bad journal.
            guard (try? capture.updateTranscript([], status: .live)) != nil else { continue }
            context.insert(capture)
            do {
                try context.save()
            } catch {
                context.rollback()
                continue
            }
            do {
                try protector.protect(audioURL, as: ProtectionPlan.afterImport)
                report.adoptedOrphans.append(cid)
            } catch {
                report.protectFailed.append(cid)
            }
        }
    }

    private func fetchCapture(_ id: UUID, context: ModelContext) throws -> Capture? {
        let cid = id
        let descriptor = FetchDescriptor<Capture>(predicate: #Predicate { $0.id == cid })
        return try context.fetch(descriptor).first
    }
}
