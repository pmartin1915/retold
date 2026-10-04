import Foundation

/// Identifies a period for nudge bookkeeping; `.unfiled` is the not-yet-filed bucket.
enum PeriodKey: Hashable, Sendable {
    case period(UUID)
    case unfiled
}

enum NudgeItemKind: Hashable, Sendable {
    case question(UUID)
    case revisit(captureID: UUID)
}

/// One nudge candidate the caller (R7) supplies: an open or skipped question, or a
/// capture offered as a Revisit (PLAN section 2: revisiting is as much the product as
/// asking).
struct NudgeItem: Equatable, Sendable {
    let kind: NudgeItemKind
    let period: PeriodKey
    let createdAt: Date
    let lastOfferedAt: Date?
}

/// One period's nudge inputs, as values.
struct NudgePeriod: Equatable, Sendable {
    let key: PeriodKey
    let captureCount: Int
    let detailCount: Int
    /// The latest capture createdAt or question lastAskedAt in the period.
    let lastVisitedAt: Date?
    /// The confirmed approxStartAge value, or nil.
    let startAge: Int?
    let sortOrder: Int
}

enum NudgeCadence: String, CaseIterable, Codable, Sendable {
    case daily, threeTimesWeekly, weekly, off
}

enum NudgePicker {
    /// Weighted thinness, then staleness, then age (PLAN section 7), additive on
    /// purpose: a strictly lexicographic key never resurfaces a well-filled period while
    /// a thinner one has items, which starves Revisits. So a never-visited thick period
    /// can outrank a recently visited thin one.
    ///
    /// T = 5 − min(5, captureCount + detailCount); S = 30 when never visited, else the
    /// whole days since lastVisitedAt capped at 30; A = 2 when there is one period, else
    /// `(2 * (n − 1 − i)) / (n − 1)` for the period's index i in age order
    /// (`.unfiled` last, nil startAge after non-nil, startAge ascending, sortOrder
    /// ascending). score = 4T + S + A.
    static func score(_ period: NudgePeriod, among periods: [NudgePeriod], now: Date) -> Int {
        let t = 5 - min(5, period.captureCount + period.detailCount)
        let s: Int
        if let lastVisitedAt = period.lastVisitedAt {
            s = min(30, max(0, Int(now.timeIntervalSince(lastVisitedAt) / 86_400)))
        } else {
            s = 30
        }
        let n = periods.count
        let ordered = periods.sorted(by: comesBeforeInAgeOrder)
        let i = ordered.firstIndex(where: { $0.key == period.key }) ?? 0
        let a = n == 1 ? 2 : (2 * (n - 1 - i)) / (n - 1)
        return 4 * t + s + a
    }

    /// The nudge to offer, or nil. Candidate periods have at least one item and are not
    /// `lastPeriod` — never the same period twice running, even if it would win. Items
    /// whose period is not in `periods` are ignored.
    static func pick(items: [NudgeItem], periods: [NudgePeriod], lastPeriod: PeriodKey?, now: Date) -> NudgeItem? {
        var winning: NudgePeriod?
        for period in periods {
            guard period.key != lastPeriod else { continue }
            guard items.contains(where: { $0.period == period.key }) else { continue }
            guard let current = winning else {
                winning = period
                continue
            }
            let scoreNew = score(period, among: periods, now: now)
            let scoreCurrent = score(current, among: periods, now: now)
            if scoreNew > scoreCurrent
                || (scoreNew == scoreCurrent && period.sortOrder < current.sortOrder)
                || (scoreNew == scoreCurrent && period.sortOrder == current.sortOrder
                    && keyTieBreak(period.key) < keyTieBreak(current.key)) {
                winning = period
            }
        }
        guard let winning else { return nil }
        return items
            .filter { $0.period == winning.key }
            .sorted(by: itemComesBefore)
            .first
    }

    /// At most one nudge a day in every cadence (PLAN section 7): `.off` never; nil
    /// lastNudgeAt always due; otherwise the whole days between the two start-of-days.
    static func isDue(cadence: NudgeCadence, lastNudgeAt: Date?, now: Date, calendar: Calendar) -> Bool {
        guard cadence != .off else { return false }
        guard let lastNudgeAt else { return true }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: lastNudgeAt),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        switch cadence {
        case .daily: return days >= 1
        case .threeTimesWeekly: return days >= 2
        case .weekly: return days >= 7
        case .off: return false
        }
    }

    // MARK: - Ordering helpers

    /// Age order: `.unfiled` last, nil startAge after non-nil, startAge ascending,
    /// sortOrder ascending.
    private static func comesBeforeInAgeOrder(_ a: NudgePeriod, _ b: NudgePeriod) -> Bool {
        switch (a.key, b.key) {
        case (.unfiled, .period): return false
        case (.period, .unfiled): return true
        default: break
        }
        switch (a.startAge, b.startAge) {
        case (.none, .some): return false
        case (.some, .none): return true
        case let (.some(x), .some(y)) where x != y: return x < y
        default: break
        }
        return a.sortOrder < b.sortOrder
    }

    /// Equal-score, equal-sortOrder tie-break: `.period` before `.unfiled`, then the
    /// uuid ascending.
    private static func keyTieBreak(_ key: PeriodKey) -> (Int, String) {
        switch key {
        case .period(let id): return (0, id.uuidString)
        case .unfiled: return (1, "")
        }
    }

    /// Within the winning period: never offered first, then older lastOfferedAt, then
    /// `.question` before `.revisit`, then older createdAt, then the kind's UUID
    /// ascending.
    private static func itemComesBefore(_ a: NudgeItem, _ b: NudgeItem) -> Bool {
        switch (a.lastOfferedAt, b.lastOfferedAt) {
        case (.none, .some): return true
        case (.some, .none): return false
        case let (.some(x), .some(y)) where x != y: return x < y
        default: break
        }
        switch (a.kind, b.kind) {
        case (.question, .revisit): return true
        case (.revisit, .question): return false
        default: break
        }
        if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
        return itemKindID(a.kind) < itemKindID(b.kind)
    }

    private static func itemKindID(_ kind: NudgeItemKind) -> String {
        switch kind {
        case .question(let id), .revisit(let id): return id.uuidString
        }
    }
}
