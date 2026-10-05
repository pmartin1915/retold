import Foundation

enum ExportArchiveError: Error {
    case noArchive
}

/// Builds the export zip that Settings hands to the share sheet (R7b section 7.7). The zip holds
/// the whole library unencrypted in tmp, so `sweep` clears it at launch and before every export.
enum ExportArchiver {
    /// Clears and recreates `workDirectory`, writes `manifest` into workDirectory/<name> with
    /// ExportWriter, zips that folder with NSFileCoordinator(.forUploading), copies the zip to
    /// workDirectory/<name>.zip, removes the folder, and returns the zip's URL.
    nonisolated static func makeArchive(
        _ manifest: ExportManifest,
        audioDirectory: URL,
        workDirectory: URL,
        name: String
    ) throws -> URL {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: workDirectory)
        try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)

        let folder = workDirectory.appendingPathComponent(name, isDirectory: true)
        let zipURL = workDirectory.appendingPathComponent("\(name).zip")
        // The skipped-audio list is ignored: the manifest already lists each file, and a missing
        // recording must not fail the export.
        _ = try ExportWriter.write(manifest, audioDirectory: audioDirectory, to: folder)

        var coordinatorError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(
            readingItemAt: folder,
            options: .forUploading,
            error: &coordinatorError
        ) { temporaryZip in
            // The URL is valid only inside this accessor, so the copy happens here.
            do {
                try? FileManager.default.removeItem(at: zipURL)
                try FileManager.default.copyItem(at: temporaryZip, to: zipURL)
            } catch {
                copyError = error
            }
        }
        try? fileManager.removeItem(at: folder)

        if let coordinatorError { throw coordinatorError }
        if let copyError { throw copyError }
        guard fileManager.fileExists(atPath: zipURL.path) else {
            throw ExportArchiveError.noArchive
        }
        return zipURL
    }

    /// Removes the work directory, ignoring errors.
    nonisolated static func sweep(workDirectory: URL) {
        try? FileManager.default.removeItem(at: workDirectory)
    }

    /// "Retold export yyyy-MM-dd" in the current time zone, Gregorian calendar and en_US_POSIX locale.
    nonisolated static func exportName(at date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return "Retold export \(formatter.string(from: date))"
    }

    /// FileManager.default.temporaryDirectory/RetoldExport.
    nonisolated static var defaultWorkDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("RetoldExport", isDirectory: true)
    }
}
