import Foundation

enum ExportWriter {
    /// Creates `folder` (with intermediates) and writes every file of `manifest` under it:
    /// .text as UTF-8, .audio copied from audioDirectory/sourceFileName. A missing audio source is
    /// skipped, not fatal (the export must not fail because one file is gone), and its manifest
    /// path is returned. A sourceFileName that contains "/" or "\\" or equals ".." is treated as
    /// missing (skipped and returned), never resolved. Any other filesystem error throws. An
    /// existing file at a target path is removed before writing or copying (copyItem does not
    /// overwrite).
    @discardableResult
    static func write(_ manifest: ExportManifest, audioDirectory: URL, to folder: URL) throws -> [String] {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        var skipped: [String] = []
        for file in manifest.files {
            let target = folder.appendingPathComponent(file.path)
            switch file.content {
            case .text(let string):
                try fileManager.createDirectory(
                    at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fileManager.removeItem(at: target)
                try string.write(to: target, atomically: true, encoding: .utf8)
            case .audio(let sourceFileName):
                guard !sourceFileName.contains("/"),
                      !sourceFileName.contains("\\"),
                      sourceFileName != ".."
                else {
                    skipped.append(file.path)
                    continue
                }
                let source = audioDirectory.appendingPathComponent(sourceFileName)
                guard fileManager.fileExists(atPath: source.path) else {
                    skipped.append(file.path)
                    continue
                }
                try fileManager.createDirectory(
                    at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fileManager.removeItem(at: target)
                try fileManager.copyItem(at: source, to: target)
            }
        }
        return skipped
    }
}
