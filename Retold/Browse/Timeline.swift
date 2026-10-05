import Foundation

/// A value snapshot of an episode for the Timeline.
struct TimelineEpisode: Equatable, Sendable {
    let id: UUID
    let periodID: UUID?
    let createdAt: Date
}

struct TimelineSection: Equatable, Sendable {
    let period: PeriodRef?          // nil = "Not in a period"
    let episodeIDs: [UUID]
}

/// Home's Timeline (R7b section 3.1): one section per period, then episodes that sit in none.
enum Timeline {
    /// One section per period in `(sortOrder, id.uuidString)` order; empty periods are kept (an
    /// empty period's page is where its opener lives). Each section's episodes run newest first,
    /// by `(createdAt descending, id.uuidString)`. An episode with no period, or a period id that
    /// matches none, goes to one final section with `period == nil`, present only if non-empty.
    static func sections(periods: [PeriodRef], episodes: [TimelineEpisode]) -> [TimelineSection] {
        func newestFirst(_ a: TimelineEpisode, _ b: TimelineEpisode) -> Bool {
            if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
            return a.id.uuidString < b.id.uuidString
        }

        let orderedPeriods = periods.sorted { (a: PeriodRef, b: PeriodRef) -> Bool in
            (a.sortOrder, a.id.uuidString) < (b.sortOrder, b.id.uuidString)
        }
        let periodIDs = Set(periods.map(\.id))

        var sections: [TimelineSection] = []
        for period in orderedPeriods {
            let inPeriod = episodes.filter { $0.periodID == period.id }.sorted(by: newestFirst)
            sections.append(TimelineSection(period: period, episodeIDs: inPeriod.map(\.id)))
        }
        let unperioded = episodes.filter { episode in
            guard let periodID = episode.periodID else { return true }
            return !periodIDs.contains(periodID)
        }.sorted(by: newestFirst)
        if !unperioded.isEmpty {
            sections.append(TimelineSection(period: nil, episodeIDs: unperioded.map(\.id)))
        }
        return sections
    }
}
