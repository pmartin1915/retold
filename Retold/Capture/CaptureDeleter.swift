import Foundation
import SwiftData

// Deletes one unfiled capture (docs/R7C-SPEC.md). Files go first and the record goes last: the
// importer re-adopts any journal or audio file that has no row, so a record deleted before its
// files could bring the recording back. A failure part-way leaves a row the user can delete again.

enum CaptureDeleteError: Error, Equatable {
    case filed               // capture.episode != nil at delete time
    case active              // the capture is the coordinator's active capture
    case fileRemovalFailed   // a file exists and could not be removed; nothing else was touched after it
    case saveFailed          // files are gone; the record delete was rolled back
}

@MainActor
enum CaptureDeleter {
    /// Deletes one unfiled capture: journal files, then audio, then the record.
    /// An absent capture is success (already deleted). `remove` is injectable for tests.
    /// Uses a FRESH ModelContext(container), never mainContext, so a rollback cannot touch
    /// unrelated unsaved edits. There is no suspension point, so nothing interleaves.
    static func delete(
        captureID: UUID,
        activeCaptureID: UUID?,
        files: CaptureFiles,
        in container: ModelContainer,
        remove: (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }
    ) throws {
        if captureID == activeCaptureID { throw CaptureDeleteError.active }

        let context = ModelContext(container)
        context.autosaveEnabled = false

        // A fetch error does not mean the capture is absent, so it removes nothing.
        let wantedID = captureID
        var descriptor = FetchDescriptor<Capture>(predicate: #Predicate { $0.id == wantedID })
        descriptor.fetchLimit = 1
        let found: [Capture]
        do {
            found = try context.fetch(descriptor)
        } catch {
            throw CaptureDeleteError.saveFailed
        }
        guard let capture = found.first else { return }
        // AnswerAttacher can attach the capture between the swipe and the confirm.
        if capture.episode != nil { throw CaptureDeleteError.filed }

        // Journal, quarantined journal (it still holds transcript text), then audio.
        let journalURL = files.journalURL(for: captureID)
        let urls = [
            journalURL,
            journalURL.appendingPathExtension("bad"),
            files.audioURL(for: captureID),
        ]
        for url in urls where FileManager.default.fileExists(atPath: url.path) {
            do {
                try remove(url)
            } catch {
                throw CaptureDeleteError.fileRemovalFailed
            }
        }

        context.delete(capture)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw CaptureDeleteError.saveFailed
        }
    }
}
