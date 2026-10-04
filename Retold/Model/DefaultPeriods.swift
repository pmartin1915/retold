import Foundation
import SwiftData

/// The six seeded periods of the no-model mode (PLAN section 8), seeded once per install.
enum DefaultPeriods {
    /// PLAN section 8, verbatim, in age order. Middle entry uses " / " with spaces.
    static let titles = ["Early childhood", "Primary school", "Middle school / junior high",
                         "High school", "The years after school", "Twenties"]

    static let seededKey = "retold.didSeedDefaultPeriods"

    /// Seeds the six periods once per install. If `defaults.bool(forKey: seededKey)` is true,
    /// does nothing and returns false. Otherwise: if the store already holds any Period
    /// (fetchCount > 0; a throw propagates and the flag stays unset), sets the key and returns
    /// false; else inserts one Period per title, sortOrder 0...5 in `titles` order, createdAt =
    /// `now` for all six, approxStartAge and approxEndAge left nil, then calls context.save()
    /// (a throw propagates and the flag stays unset), then sets the key and returns true. The
    /// flag is written LAST, so a failure never leaves an install flagged but unseeded; and a
    /// user who deletes every period does not get the six back on the next launch. Ages stay
    /// nil: an age range is a fact the user did not state, and seeding one would be the app
    /// authoring it.
    @MainActor @discardableResult
    static func seedIfNeeded(_ context: ModelContext, defaults: UserDefaults, now: Date = Date()) throws -> Bool {
        if defaults.bool(forKey: seededKey) { return false }
        if try context.fetchCount(FetchDescriptor<Period>()) > 0 {
            defaults.set(true, forKey: seededKey)
            return false
        }
        for (index, title) in titles.enumerated() {
            context.insert(Period(title: title, sortOrder: index, createdAt: now))
        }
        try context.save()
        defaults.set(true, forKey: seededKey)
        return true
    }
}
