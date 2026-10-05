import Foundation

// The export manifest (PLAN section 2 "Keep" and section 4 item 4): value snapshots of the
// library, built into a folder listing — index.md, transcripts/<capture-id>.md and
// audio/<capture-id>.<ext> per capture. Rule 1 in export: only confirmed values print as
// facts; transcripts are verbatim and corrections are listed after, never substituted.

struct ExportQuestion: Equatable, Sendable {
    let id: UUID
    let text: String
    let createdAt: Date
}

struct ExportDetail: Equatable, Sendable {
    let id: UUID
    let text: String
    let kind: DetailKind
}

struct ExportCapture: Equatable, Sendable {
    let id: UUID
    let audioFileName: String
    let duration: TimeInterval
    let createdAt: Date
    let status: TranscriptionStatus
    let segments: [TranscriptSegment]
    let corrections: [UserCorrection]
    let episodeID: UUID?
}

struct ExportEpisode: Equatable, Sendable {
    let id: UUID
    /// The title only when its status is .confirmed; nil otherwise (proposed or rejected).
    let confirmedTitle: String?
    let excerpt: String
    let periodID: UUID?
    let approxYear: Int?        // confirmed only
    let approxAge: Int?         // confirmed only
    let place: String?
    let people: [String]
    let details: [ExportDetail]
    let openQuestions: [ExportQuestion]   // status .open or .skipped
    let createdAt: Date
}

struct ExportPeriod: Equatable, Sendable {
    let id: UUID
    let title: String
    let startAge: Int?          // confirmed only
    let endAge: Int?            // confirmed only
    let sortOrder: Int
    let createdAt: Date
    let openQuestions: [ExportQuestion]   // Question.period == this, episode nil, .open or .skipped
}

struct ExportLibrary: Equatable, Sendable {
    let periods: [ExportPeriod]
    let episodes: [ExportEpisode]
    let captures: [ExportCapture]
    /// .open/.skipped questions with no episode and no period (theme questions today).
    let otherOpenQuestions: [ExportQuestion]
}

extension ExportLibrary {
    /// The SwiftData adapter. The caller fetches every Period, Episode, Capture and Question.
    /// A Confirmable is read as a fact only when status == .confirmed. Capture.rejectedProposals
    /// are never read.
    /// Questions come ONLY from the `questions` argument (never from episode.questions), filtered
    /// to status .open or .skipped and templateID != "broad.open" (the opener stays open by design
    /// and would print on every episode). Routing: episode != nil -> that episode's openQuestions
    /// (person-linked questions included), or dropped if the episode is not in `episodes`;
    /// episode == nil, period != nil -> that period's openQuestions, or dropped if absent;
    /// both nil -> otherOpenQuestions (person ignored).
    /// ExportQuestion.text is the persisted Question.text, except a period.slot question with a
    /// period: its text is re-assembled with TemplateAssembler.assemble(_:periodTitle:) on
    /// period.titleFill, falling back to the persisted text on a throw, so a renamed period
    /// exports its current title.
    @MainActor
    init(periods: [Period], episodes: [Episode], captures: [Capture], questions: [Question]) {
        let periodIDs = Set(periods.map(\.id))
        let episodeIDs = Set(episodes.map(\.id))

        let openQuestions = questions.filter {
            ($0.status == .open || $0.status == .skipped) && $0.templateID != "broad.open"
        }
        var episodeQuestions: [UUID: [ExportQuestion]] = [:]
        var periodQuestions: [UUID: [ExportQuestion]] = [:]
        var otherQuestions: [ExportQuestion] = []
        for question in openQuestions {
            let export = ExportQuestion(id: question.id, text: QuestionText.display(question), createdAt: question.createdAt)
            if let episode = question.episode {
                if episodeIDs.contains(episode.id) {
                    episodeQuestions[episode.id, default: []].append(export)
                }
            } else if let period = question.period {
                if periodIDs.contains(period.id) {
                    periodQuestions[period.id, default: []].append(export)
                }
            } else {
                otherQuestions.append(export)
            }
        }

        self.init(
            periods: periods.map { period in
                ExportPeriod(
                    id: period.id,
                    title: period.title,
                    startAge: period.approxStartAge.flatMap { $0.status == .confirmed ? $0.value : nil },
                    endAge: period.approxEndAge.flatMap { $0.status == .confirmed ? $0.value : nil },
                    sortOrder: period.sortOrder,
                    createdAt: period.createdAt,
                    openQuestions: periodQuestions[period.id] ?? []
                )
            },
            episodes: episodes.map { episode in
                ExportEpisode(
                    id: episode.id,
                    confirmedTitle: episode.title.status == .confirmed ? episode.title.value : nil,
                    excerpt: episode.excerpt,
                    periodID: episode.period?.id,
                    approxYear: episode.approxYear.flatMap { $0.status == .confirmed ? $0.value : nil },
                    approxAge: episode.approxAge.flatMap { $0.status == .confirmed ? $0.value : nil },
                    place: episode.place?.name,
                    people: episode.people.map(\.name),
                    details: episode.details.map { ExportDetail(id: $0.id, text: $0.text, kind: $0.kind) },
                    openQuestions: episodeQuestions[episode.id] ?? [],
                    createdAt: episode.createdAt
                )
            },
            captures: captures.map { capture in
                ExportCapture(
                    id: capture.id,
                    audioFileName: capture.audioFileName,
                    duration: capture.duration,
                    createdAt: capture.createdAt,
                    status: capture.transcriptionStatus,
                    segments: capture.transcript,
                    corrections: capture.corrections,
                    episodeID: capture.episode?.id
                )
            },
            otherOpenQuestions: otherQuestions
        )
    }
}

struct ExportFile: Equatable, Sendable {
    enum Content: Equatable, Sendable {
        case text(String)
        /// Copy the capture's audio file; the name is relative to the app's audio directory.
        case audio(sourceFileName: String)
    }
    let path: String            // relative, "/"-separated
    let content: Content
}

struct ExportManifest: Equatable, Sendable {
    let files: [ExportFile]

    /// index.md first, then for each capture in capture order: transcripts/<ID>.md, then
    /// audio/<ID>.<ext>. <ID> is uuidString. <ext> is audioFileName's path extension, or "m4a"
    /// when it has none. Dates use `timeZone`, the Gregorian calendar and the en_US_POSIX locale.
    /// All ordering is ascending on value tuples, so the output is independent of input order.
    static func build(_ library: ExportLibrary, exportedAt: Date, timeZone: TimeZone) -> ExportManifest {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        // Every user string prints with each run of newlines replaced by one space; nothing
        // else is escaped or altered. Every output line has trailing whitespace removed.
        func oneLine(_ text: String) -> String {
            text.split(whereSeparator: { $0.isNewline }).joined(separator: " ")
        }
        func rtrimmed(_ line: String) -> String {
            var line = line
            while let last = line.last, last.isWhitespace { line.removeLast() }
            return line
        }
        func date(_ value: Date) -> String { dateFormatter.string(from: value) }
        func ext(_ capture: ExportCapture) -> String {
            let ext = (capture.audioFileName as NSString).pathExtension
            return ext.isEmpty ? "m4a" : ext
        }

        let periods = library.periods.sorted {
            ($0.sortOrder, $0.createdAt, $0.id.uuidString) < ($1.sortOrder, $1.createdAt, $1.id.uuidString)
        }
        let episodes = library.episodes.sorted {
            ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString)
        }
        let captures = library.captures.sorted {
            ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString)
        }

        func captureLine(_ capture: ExportCapture) -> String {
            "\(date(capture.createdAt)) · \(formatClock(capture.duration)) · "
                + "[transcript](transcripts/\(capture.id.uuidString).md) · "
                + "[audio](audio/\(capture.id.uuidString).\(ext(capture)))"
        }

        func episodeBlock(_ episode: ExportEpisode) -> [String] {
            var lines: [String] = []
            lines.append("### \(episode.confirmedTitle.map(oneLine) ?? "Untitled")")
            if !episode.excerpt.isEmpty { lines.append("> \(oneLine(episode.excerpt))") }
            var when: [String] = []
            if let year = episode.approxYear { when.append("\(year)") }
            if let age = episode.approxAge { when.append("age \(age)") }
            if !when.isEmpty { lines.append("- When: \(when.joined(separator: "; "))") }
            if let place = episode.place { lines.append("- Place: \(oneLine(place))") }
            let people = episode.people.sorted().map(oneLine)
            if !people.isEmpty { lines.append("- People: \(people.joined(separator: ", "))") }
            let details = episode.details.sorted {
                ($0.kind.rawValue, $0.text, $0.id.uuidString) < ($1.kind.rawValue, $1.text, $1.id.uuidString)
            }
            if !details.isEmpty {
                lines.append("- Details:")
                for detail in details {
                    lines.append("  - \"\(oneLine(detail.text))\" (\(detail.kind.rawValue))")
                }
            }
            let episodeCaptures = captures.filter { $0.episodeID == episode.id }
            if !episodeCaptures.isEmpty {
                lines.append("- Captures:")
                for capture in episodeCaptures { lines.append("  - \(captureLine(capture))") }
            }
            let questions = episode.openQuestions.sorted {
                ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString)
            }
            if !questions.isEmpty {
                lines.append("- Open questions:")
                for question in questions { lines.append("  - \(oneLine(question.text))") }
            }
            return lines
        }

        func transcriptFile(_ capture: ExportCapture) -> ExportFile {
            var lines: [String] = []
            lines.append("# Capture \(capture.id.uuidString)")
            lines.append("")
            lines.append("Recorded \(date(capture.createdAt)) · \(formatClock(capture.duration)) · transcript \(capture.status.rawValue)")
            lines.append("Audio: ../audio/\(capture.id.uuidString).\(ext(capture))")
            lines.append("")
            if capture.segments.isEmpty {
                lines.append("(no transcript)")
            } else {
                for segment in capture.segments {
                    lines.append("[\(formatClock(segment.start))–\(formatClock(segment.end))] \(oneLine(segment.text))")
                }
            }
            if !capture.corrections.isEmpty {
                lines.append("")
                lines.append("## Corrections")
                lines.append("")
                for correction in capture.corrections {
                    let range: String
                    if capture.segments.indices.contains(correction.segmentIndex) {
                        let segment = capture.segments[correction.segmentIndex]
                        range = "[\(formatClock(segment.start))–\(formatClock(segment.end))]"
                    } else {
                        range = "[?]"
                    }
                    lines.append("- \(range) \"\(oneLine(correction.originalText))\" → "
                        + "\"\(oneLine(correction.correctedText))\" (\(date(correction.createdAt)))")
                }
            }
            let text = lines.map(rtrimmed).joined(separator: "\n") + "\n"
            return ExportFile(path: "transcripts/\(capture.id.uuidString).md", content: .text(text))
        }

        // MARK: index.md

        var lines: [String] = [
            "# Retold export",
            "",
            "Exported \(date(exportedAt))",
            "Recordings may name other people.",   // fixed copy (PLAN section 9, Guideline 1.4/5.1)
        ]
        let periodIDs = Set(library.periods.map(\.id))
        let episodeIDs = Set(library.episodes.map(\.id))

        for period in periods {
            lines.append("")
            lines.append("## \(oneLine(period.title))")
            if let start = period.startAge, let end = period.endAge {
                lines.append("Ages \(start)–\(end)")
            } else if let start = period.startAge {
                lines.append("From age \(start)")
            } else if let end = period.endAge {
                lines.append("Until age \(end)")
            }
            for episode in episodes where episode.periodID == period.id {
                lines.append("")
                lines.append(contentsOf: episodeBlock(episode))
            }
            let open = period.openQuestions.sorted {
                ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString)
            }
            if !open.isEmpty {
                lines.append("")
                lines.append("Open questions for this period:")
                for question in open { lines.append("- \(oneLine(question.text))") }
            }
        }

        let unperioded = episodes.filter { episode in
            guard let periodID = episode.periodID else { return true }
            return !periodIDs.contains(periodID)
        }
        if !unperioded.isEmpty {
            lines.append("")
            lines.append("## Not in a period")
            for episode in unperioded {
                lines.append("")
                lines.append(contentsOf: episodeBlock(episode))
            }
        }

        let unfiled = captures.filter { capture in
            guard let episodeID = capture.episodeID else { return true }
            return !episodeIDs.contains(episodeID)
        }
        if !unfiled.isEmpty {
            lines.append("")
            lines.append("## Unfiled captures")
            for capture in unfiled { lines.append("- \(captureLine(capture))") }
        }

        let other = library.otherOpenQuestions.sorted {
            ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString)
        }
        if !other.isEmpty {
            lines.append("")
            lines.append("## Other open questions")
            for question in other { lines.append("- \(oneLine(question.text))") }
        }

        let index = lines.map(rtrimmed).joined(separator: "\n") + "\n"

        var files: [ExportFile] = [ExportFile(path: "index.md", content: .text(index))]
        for capture in captures {
            files.append(transcriptFile(capture))
            files.append(ExportFile(
                path: "audio/\(capture.id.uuidString).\(ext(capture))",
                content: .audio(sourceFileName: capture.audioFileName)
            ))
        }
        return ExportManifest(files: files)
    }

    /// `m:ss` under one hour, `h:mm:ss` from one hour, whole seconds truncated
    /// (61.9 -> 1:01, 3725 -> 1:02:05). Negative, NaN or infinite values print as `0:00`.
    static func formatClock(_ value: TimeInterval) -> String {
        guard value.isFinite, value >= 0 else { return "0:00" }
        let total = Int(value)          // truncation toward zero; value >= 0 here
        let seconds = total % 60
        let minutes = (total / 60) % 60
        if total >= 3600 {
            return "\(total / 3600):\(pad(minutes)):\(pad(seconds))"
        }
        return "\(total / 60):\(pad(seconds))"
    }

    private static func pad(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
