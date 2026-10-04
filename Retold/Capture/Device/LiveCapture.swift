import Foundation
import SwiftData
import UIKit

/// The composition root: builds the device adapters and the coordinator exactly once.
/// The store lives under Application Support with .complete protection (spec 7, store
/// protection): unwritable while locked, which is why the sidecar journal exists.
enum LiveCapture {
    struct LiveCaptureServices: Sendable {
        let coordinator: CaptureCoordinator
        let engine: LiveCaptureEngine
        let prefetch: AssetPrefetch
        let container: ModelContainer
    }

    @MainActor
    static func makeCoordinator() throws -> LiveCaptureServices {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        let files = CaptureFiles(root: appSupport.appendingPathComponent("Captures", isDirectory: true))

        let storeURL = appSupport
            .appendingPathComponent("Store", isDirectory: true)
            .appendingPathComponent("Retold.store")
        let container = try RetoldSchema.makeContainer(url: storeURL)

        let protector = FileManagerProtector()
        protectStore(url: storeURL, protector: protector)

        let importer = JournalImporter(files: files, durationProbe: AVDurationProbe(), protector: protector)
        let engine = LiveCaptureEngine()
        let probe = SpeechRouteProbe()
        let coordinator = CaptureCoordinator(
            engine: engine,
            fileTranscriber: SpeechFileTranscriber(),
            routeProvider: { await probe.currentRoute() },
            files: files,
            importer: importer,
            container: container,
            initialPermission: LiveCaptureEngine.currentPermission(),
            protectedDataAvailable: UIApplication.shared.isProtectedDataAvailable,
            makeWriter: { files, captureID in
                try JournalWriter(files: files, captureID: captureID, protector: protector)
            })
        return LiveCaptureServices(
            coordinator: coordinator,
            engine: engine,
            prefetch: AssetPrefetch(),
            container: container
        )
    }

    /// .complete on the store directory, the store file and its -wal/-shm siblings, each only
    /// if it exists, ignoring errors per file (checklist item 6).
    private static func protectStore(url: URL, protector: FileManagerProtector) {
        let directory = url.deletingLastPathComponent()
        let names = [url.lastPathComponent,
                     url.lastPathComponent + "-wal",
                     url.lastPathComponent + "-shm"]
        for target in [directory] + names.map({ directory.appendingPathComponent($0) }) {
            guard FileManager.default.fileExists(atPath: target.path) else { continue }
            try? protector.protect(target, as: .complete)
        }
    }
}
