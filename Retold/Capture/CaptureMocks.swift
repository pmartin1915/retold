#if DEBUG
import Foundation

// Test doubles for the R6a seams. The Release compile proves that no production code reaches them.
// Under Swift 6 a mock with mutable recorded calls is a final class whose state sits behind a
// lock, marked @unchecked Sendable here only — production types never use @unchecked Sendable.

// MARK: - CaptureEngine

final class MockCaptureEngine: CaptureEngine, @unchecked Sendable {
    enum RecordedCall: Equatable {
        case start(captureID: UUID, route: TranscriptionRoute)
        case pause(captureID: UUID)
        case resume(captureID: UUID)
        case stop(captureID: UUID)
    }

    /// The SAME stream on every access (the coordinator is the single consumer).
    let events: AsyncStream<CaptureEngineEvent>
    private let continuation: AsyncStream<CaptureEngineEvent>.Continuation
    private let lock = NSLock()

    /// What microphonePermission()/requestMicrophonePermission() report.
    var permission: MicrophonePermission = .granted
    private var recorded: [RecordedCall] = []

    init() {
        let (stream, continuation) = AsyncStream<CaptureEngineEvent>.makeStream()
        self.events = stream
        self.continuation = continuation
    }

    var recordedCalls: [RecordedCall] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    func record(_ call: RecordedCall) {
        lock.lock(); defer { lock.unlock() }
        recorded.append(call)
    }

    func microphonePermission() async -> MicrophonePermission { permission }
    func requestMicrophonePermission() async -> MicrophonePermission { permission }

    func start(captureID: UUID, audioURL: URL, route: TranscriptionRoute) async {
        record(.start(captureID: captureID, route: route))
    }

    func pause(captureID: UUID) async { record(.pause(captureID: captureID)) }
    func resume(captureID: UUID) async { record(.resume(captureID: captureID)) }
    func stop(captureID: UUID) async { record(.stop(captureID: captureID)) }

    /// Test driver: pushes a recorder event onto the engine stream.
    func push(_ event: RecorderEvent) {
        continuation.yield(.recorder(event))
    }

    /// Test driver: pushes a volatile (UI-only) event onto the engine stream.
    func pushVolatile(captureID: UUID, text: String) {
        continuation.yield(.volatile(captureID: captureID, text: text))
    }

    /// Ends the event stream (run() returns).
    func finish() {
        continuation.finish()
    }
}

// MARK: - FileTranscriber

final class MockFileTranscriber: FileTranscriber, @unchecked Sendable {
    private let lock = NSLock()
    private var recordedRoutes: [TranscriptionRoute] = []
    private var callCount = 0
    private var gateWaiters: [CheckedContinuation<Void, Never>] = []

    /// When true, each transcribe() stream waits for releaseGate() before yielding.
    var gateEnabled = false
    /// Results consumed in call order; the last one repeats.
    var results: [Result<[TranscriptSegment], Error>] = [.success([])]

    var routes: [TranscriptionRoute] {
        lock.lock(); defer { lock.unlock() }
        return recordedRoutes
    }

    var calls: Int {
        lock.lock(); defer { lock.unlock() }
        return callCount
    }

    /// Nonzero while a gated stream is still waiting (tests spin on this before releasing).
    var gateWaiterCount: Int {
        lock.lock(); defer { lock.unlock() }
        return gateWaiters.count
    }

    func releaseGate() {
        lock.lock()
        let waiters = gateWaiters
        gateWaiters.removeAll()
        lock.unlock()
        for waiter in waiters { waiter.resume() }
    }

    func transcribe(audioURL: URL, route: TranscriptionRoute) -> AsyncThrowingStream<TranscriptSegment, Error> {
        lock.lock()
        recordedRoutes.append(route)
        callCount += 1
        let gated = gateEnabled
        let index = min(callCount - 1, max(results.count - 1, 0))
        let result = results.isEmpty ? Result<[TranscriptSegment], Error>.success([]) : results[index]
        lock.unlock()
        return AsyncThrowingStream<TranscriptSegment, Error> { continuation in
            Task {
                if gated {
                    await withCheckedContinuation { (waiter: CheckedContinuation<Void, Never>) in
                        self.lock.lock()
                        self.gateWaiters.append(waiter)
                        self.lock.unlock()
                    }
                }
                switch result {
                case .success(let segments):
                    for segment in segments { continuation.yield(segment) }
                    continuation.finish()
                case .failure(let error):
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - AudioDurationProbe

final class MockDurationProbe: AudioDurationProbe, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [URL: TimeInterval] = [:]
    private var recordedURLs: [URL] = []

    var defaultValue: TimeInterval? = nil

    func setDuration(_ duration: TimeInterval?, for url: URL) {
        lock.lock(); defer { lock.unlock() }
        values[url] = duration
    }

    var calledURLs: [URL] {
        lock.lock(); defer { lock.unlock() }
        return recordedURLs
    }

    func duration(of audioURL: URL) -> TimeInterval? {
        lock.lock(); defer { lock.unlock() }
        recordedURLs.append(audioURL)
        if let value = values[audioURL] { return value }
        return defaultValue
    }
}

// MARK: - FileProtector

final class MockFileProtector: FileProtector, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [(url: URL, type: FileProtectionType)] = []
    private var failures: [Error] = []

    /// Errors thrown one per call, in order, until exhausted.
    func failNext(_ errors: [Error]) {
        lock.lock(); defer { lock.unlock() }
        failures.append(contentsOf: errors)
    }

    var calls: [(url: URL, type: FileProtectionType)] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    func protect(_ url: URL, as type: FileProtectionType) throws {
        lock.lock()
        recorded.append((url, type))
        let failure = failures.isEmpty ? nil : failures.removeFirst()
        lock.unlock()
        if let failure { throw failure }
    }
}

// MARK: - JournalAppending

final class MockJournalWriter: JournalAppending, @unchecked Sendable {
    let captureID: UUID
    private let lock = NSLock()
    private var stored: [JournalRecord] = []
    private var appendCount = 0

    /// 1-based append numbers that throw appendedError.
    var failOnAppends: Set<Int> = []
    var appendedError: JournalError = .closed
    var closeCount = 0

    init(captureID: UUID) {
        self.captureID = captureID
    }

    var records: [JournalRecord] {
        lock.lock(); defer { lock.unlock() }
        return stored
    }

    func append(_ record: JournalRecord) throws {
        lock.lock()
        appendCount += 1
        let count = appendCount
        lock.unlock()
        if failOnAppends.contains(count) { throw appendedError }
        lock.lock()
        stored.append(record)
        lock.unlock()
    }

    func close() {
        lock.lock(); defer { lock.unlock() }
        closeCount += 1
    }
}
#endif
