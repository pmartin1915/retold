import Foundation
import SwiftData

enum PeriodEditError: Error, Equatable { case emptyTitle, duplicateTitle }

/// Adding and renaming periods (R7b section 6). Reorder and delete are not in 1.0.
@MainActor
enum PeriodEditor {
    /// Inserts `Period(title:, sortOrder: max existing + 1 (0 if none), createdAt: now)` and saves.
    /// The title is trimmed; an empty one throws `.emptyTitle`, and one equal to another period's
    /// (case-insensitive, both trimmed) throws `.duplicateTitle`. Both checks run before any write.
    static func add(title: String, in context: ModelContext, now: Date = Date()) throws -> Period {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PeriodEditError.emptyTitle }
        let periods = try context.fetch(FetchDescriptor<Period>())
        if periods.contains(where: { sameTitle($0.title, trimmed) }) {
            throw PeriodEditError.duplicateTitle
        }
        let period = Period(
            title: trimmed,
            sortOrder: (periods.map(\.sortOrder).max() ?? -1) + 1,
            createdAt: now
        )
        context.insert(period)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return period
    }

    /// Sets `period.title` to the trimmed title and saves. The duplicate check excludes the period
    /// being renamed, and a title equal to the period's own (including a change of case only) is
    /// always allowed, so two pre-existing periods with one title can each be saved unchanged.
    static func rename(_ period: Period, to title: String, in context: ModelContext) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PeriodEditError.emptyTitle }
        if !sameTitle(period.title, trimmed) {
            let periods = try context.fetch(FetchDescriptor<Period>())
            let periodID = period.id
            if periods.contains(where: { $0.id != periodID && sameTitle($0.title, trimmed) }) {
                throw PeriodEditError.duplicateTitle
            }
        }
        period.title = trimmed
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Case-insensitive equality after trimming both sides.
    private static func sameTitle(_ a: String, _ b: String) -> Bool {
        let left = a.trimmingCharacters(in: .whitespacesAndNewlines)
        let right = b.trimmingCharacters(in: .whitespacesAndNewlines)
        return left.caseInsensitiveCompare(right) == .orderedSame
    }
}
