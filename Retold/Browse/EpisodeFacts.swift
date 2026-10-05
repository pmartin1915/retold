import Foundation

/// What a page may show as fact about one episode (R7b section 3.2). A Confirmable is read only
/// when its status is `.confirmed` (Rule 1, PLAN section 5.1 item 2), the same rule as
/// ExportLibrary. Every page reads an episode's title, when, place and people from here.
struct EpisodeFacts: Equatable, Sendable {
    let title: String?              // title.value only when title.status == .confirmed
    let period: PeriodRef?
    let year: Int?                  // approxYear only when .confirmed
    let age: Int?                   // approxAge only when .confirmed
    let place: EntityRef?
    let people: [EntityRef]         // sorted by (name, id.uuidString)
    let details: [String]           // Detail.text, sorted by (kind.rawValue, text, id.uuidString)
}

extension EpisodeFacts {
    @MainActor
    init(episode: Episode) {
        let sortedPeople = episode.people
            .map { EntityRef(id: $0.id, name: $0.name) }
            .sorted { (a: EntityRef, b: EntityRef) -> Bool in
                (a.name, a.id.uuidString) < (b.name, b.id.uuidString)
            }
        let sortedDetails = episode.details.sorted { (a: Detail, b: Detail) -> Bool in
            (a.kind.rawValue, a.text, a.id.uuidString) < (b.kind.rawValue, b.text, b.id.uuidString)
        }
        self.init(
            title: episode.title.status == .confirmed ? episode.title.value : nil,
            period: episode.period.map { PeriodRef(id: $0.id, title: $0.title, sortOrder: $0.sortOrder) },
            year: episode.approxYear.flatMap { $0.status == .confirmed ? $0.value : nil },
            age: episode.approxAge.flatMap { $0.status == .confirmed ? $0.value : nil },
            place: episode.place.map { EntityRef(id: $0.id, name: $0.name) },
            people: sortedPeople,
            details: sortedDetails.map(\.text)
        )
    }

    /// The when display (R7b section 1): the year (`1998`), `Age 12`, or both joined by " · ".
    /// Display-only; never persisted. nil when neither is confirmed.
    var whenDisplay: String? {
        var parts: [String] = []
        if let year { parts.append("\(year)") }
        if let age { parts.append("\(AppCopy.whenAge) \(age)") }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }
}

/// How a capture's transcript is shown on a page (R7b section 3.3).
enum CaptureTranscriptState: Equatable, Sendable {
    case transcribing, segments([TranscriptSegment]), none
}

extension CaptureTranscriptState {
    /// `.pending`, `.live` and `.fromFile` are transcribing; `.complete` with segments is
    /// segments; `.complete` with none, or `.failed` (even with a partial transcript), is none.
    static func of(status: TranscriptionStatus, segments: [TranscriptSegment]) -> CaptureTranscriptState {
        switch status {
        case .pending, .live, .fromFile:
            return .transcribing
        case .complete:
            return segments.isEmpty ? CaptureTranscriptState.none : .segments(segments)
        case .failed:
            return CaptureTranscriptState.none
        }
    }
}
