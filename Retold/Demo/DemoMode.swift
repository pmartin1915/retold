#if DEBUG
import Foundation
import SwiftData

// App Store screenshot demo (`-RetoldDemo`, used only by RetoldUITests/ScreenshotTests). Debug
// builds only: the Release build compiles none of this, and a Debug launch without the argument
// takes the production path unchanged. The library is in memory and fictional; capture is mocked,
// so no permission alert, speech-asset download or real recording can happen.
enum DemoMode {
    /// True only when the app was launched with `-RetoldDemo`.
    static let isActive: Bool = ProcessInfo.processInfo.arguments.contains("-RetoldDemo")

    /// The demo composition root: an in-memory store seeded with a small fictional library, a
    /// per-launch temp capture directory, and mock capture/transcription seams. The permission is
    /// .granted up front, so FirstRunView (the only reader of `engine`/`prefetch`) never appears.
    @MainActor
    static func makeServices() throws -> LiveCapture.LiveCaptureServices {
        let files = CaptureFiles(root: FileManager.default.temporaryDirectory
            .appendingPathComponent("RetoldDemo-\(UUID().uuidString)", isDirectory: true))
        try files.prepare()
        let container = try RetoldSchema.makeInMemoryContainer()
        try seed(container.mainContext, files: files)

        let coordinator = CaptureCoordinator(
            engine: DemoCaptureEngine(),
            fileTranscriber: MockFileTranscriber(),
            routeProvider: { .speech(localeID: "en-US") },
            files: files,
            importer: JournalImporter(files: files, durationProbe: MockDurationProbe(),
                                      protector: MockFileProtector()),
            container: container,
            initialPermission: .granted,
            protectedDataAvailable: true,
            makeWriter: { _, captureID in MockJournalWriter(captureID: captureID) })
        return LiveCapture.LiveCaptureServices(
            coordinator: coordinator,
            engine: LiveCaptureEngine(),   // never started; FirstRunView is unreachable here
            prefetch: AssetPrefetch(),     // never run, for the same reason
            container: container
        )
    }

    /// The confirm screen's suggestions in demo mode: the production pipeline over a scripted
    /// model. Every claimed phrase still goes through SpanVerifier, so a chip appears only where
    /// the phrase is a verbatim quote of the unfiled transcript below.
    static func filingPipeline() -> FilingPipeline {
        FilingPipeline(
            model: MockFilingModel { _, _ in
                WindowExtract(
                    periodName: "Primary school",
                    people: ["Grandpa Joe"],
                    places: ["the lake house"],
                    timeCues: ["the summer I turned nine"],
                    referents: [RawReferent(span: "the old green tackle box", kind: .object)],
                    titleSpan: "taught me to fish off the dock"
                )
            },
            counter: WordTokenCounter()
        )
    }

    // MARK: - Seed

    private struct StorySeed {
        let title: String
        let period: String
        let year: Int?
        let age: Int?
        let place: String?
        let people: [String]
        let detail: String?
        let daysAgo: Int
        let lines: [String]
    }

    private static let stories: [StorySeed] = [
        StorySeed(
            title: "My first car", period: "High school", year: 1987, age: nil,
            place: "Maple Street", people: ["Grandpa Joe"], detail: "the radio only played one station",
            daysAgo: 2,
            lines: ["It was a blue station wagon with a dent in the back door,",
                    "and Grandpa Joe sold it to me for one dollar.",
                    "I parked it on Maple Street and washed it every Saturday.",
                    "The radio only played one station, so we sang along to whatever came on."]),
        StorySeed(
            title: "Summers at the lake house", period: "Primary school", year: nil, age: 8,
            place: "the lake house", people: ["Grandpa Joe", "Aunt Ruth"],
            detail: "the porch door banged every time", daysAgo: 5,
            lines: ["Every July we drove up to the lake house with the windows down.",
                    "Aunt Ruth made pancakes shaped like the letters of our names,",
                    "and the porch door banged every time somebody ran out to the water.",
                    "We stayed in the lake until our fingers wrinkled."]),
        StorySeed(
            title: "The treehouse we built", period: "Early childhood", year: nil, age: 6,
            place: "Maple Street", people: ["Sam"], detail: nil, daysAgo: 9,
            lines: ["My brother Sam and I built a treehouse out of old fence boards.",
                    "It leaned to one side, but we called it a castle anyway,",
                    "and we ate our sandwiches up there all summer."]),
    ]

    private static let unfiledLines = [
        "Grandpa Joe taught me to fish off the dock at the lake house.",
        "It was the summer I turned nine, and we got up before the sun.",
        "He let me carry the old green tackle box, which felt like a big job.",
        "I didn't catch anything, but I still remember how quiet the water was.",
    ]

    @MainActor
    private static func seed(_ context: ModelContext, files: CaptureFiles) throws {
        var periods: [String: Period] = [:]
        for (index, title) in DefaultPeriods.titles.enumerated() {
            let period = Period(title: title, sortOrder: index)
            context.insert(period)
            periods[title] = period
        }
        var people: [String: Person] = [:]
        for name in ["Grandpa Joe", "Aunt Ruth", "Sam"] {
            let person = Person(name: name)
            context.insert(person)
            people[name] = person
        }
        var places: [String: Place] = [:]
        for name in ["the lake house", "Maple Street"] {
            let place = Place(name: name)
            context.insert(place)
            places[name] = place
        }

        for story in stories {
            let created = demoDate(daysAgo: story.daysAgo)
            let capture = try makeCapture(lines: story.lines, createdAt: created, files: files)
            context.insert(capture)
            let episode = Episode(typedTitle: story.title, createdAt: created)
            context.insert(episode)
            episode.captures.append(capture)
            if let transcript = capture.completedTranscript {
                episode.setExcerpt(from: transcript)
                if let detail = story.detail,
                   let span = SpanVerifier.verify(detail, in: transcript.window(0..<transcript.segments.count)) {
                    let quote = Detail(quote: span, kind: .sensory)
                    context.insert(quote)
                    episode.details.append(quote)
                }
            }
            episode.period = periods[story.period]
            if let year = story.year { episode.answerWhen(year: year) }
            if let age = story.age { episode.answerWhen(age: age) }
            if let name = story.place { episode.place = places[name] }
            episode.people = story.people.compactMap { people[$0] }
        }

        // One unfiled recording: the confirm screen's subject.
        let unfiled = try makeCapture(lines: unfiledLines, createdAt: demoDate(daysAgo: 0), files: files)
        context.insert(unfiled)

        try context.save()
    }

    /// A completed capture whose segments are `lines`, with a few placeholder bytes at its audio
    /// path so the player row shows (playback itself is never exercised in demo mode).
    @MainActor
    private static func makeCapture(lines: [String], createdAt: Date, files: CaptureFiles) throws -> Capture {
        var segments: [TranscriptSegment] = []
        var clock: TimeInterval = 0
        for line in lines {
            let length = TimeInterval(line.split(separator: " ").count) * 0.45 + 1.5
            segments.append(TranscriptSegment(text: line, start: clock, end: clock + length, isFinal: true))
            clock += length + 0.8
        }
        let capture = Capture(audioFileName: "", duration: clock.rounded(), createdAt: createdAt)
        capture.audioFileName = CaptureFiles.audioFileName(for: capture.id)
        try Data([0x00, 0x01, 0x02, 0x03]).write(to: files.audioURL(for: capture.id))
        try capture.completeTranscript(segments)
        return capture
    }

    /// Local early evening `daysAgo` days before today, so the lists read like a real week.
    private static func demoDate(daysAgo: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.date(bySettingHour: 18, minute: 30, second: 0, of: Date()) ?? Date()
        return calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
    }
}

/// The demo recorder engine. MockCaptureEngine only records calls, so a capture would sit in
/// .starting forever; this one reports a started engine and one line of fictional live text,
/// and honours the stop contract (engineStopped last, once per capture).
final class DemoCaptureEngine: CaptureEngine, @unchecked Sendable {
    let events: AsyncStream<CaptureEngineEvent>
    private let continuation: AsyncStream<CaptureEngineEvent>.Continuation
    private let lock = NSLock()
    private var stopped: Set<UUID> = []

    init() {
        let (stream, continuation) = AsyncStream<CaptureEngineEvent>.makeStream()
        self.events = stream
        self.continuation = continuation
    }

    func microphonePermission() async -> MicrophonePermission { .granted }
    func requestMicrophonePermission() async -> MicrophonePermission { .granted }

    func start(captureID: UUID, audioURL: URL, route: TranscriptionRoute) async {
        continuation.yield(.recorder(.engineStarted(captureID: captureID)))
        continuation.yield(.volatile(
            captureID: captureID,
            text: "The first thing I remember about that kitchen is the smell of bread on Sunday mornings"))
    }

    func pause(captureID: UUID) async {}
    func resume(captureID: UUID) async {}

    func stop(captureID: UUID) async {
        let first = lock.withLock { stopped.insert(captureID).inserted }
        guard first else { return }
        continuation.yield(.recorder(.engineStopped(captureID: captureID, duration: 0)))
    }
}
#endif
