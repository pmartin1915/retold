import Foundation
import SwiftData
import XCTest
@testable import Retold

@MainActor
final class DefaultPeriodsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    /// Keeps each test's container alive for the whole test (the tuple's `_` would not).
    private var containers: [ModelContainer] = []

    // No setUp/tearDown overrides: a @MainActor test class can't override XCTest's
    // nonisolated synchronous ones in Swift 6 (see SchemaRoundTripTests). Each test makes its
    // own store and defaults suite; a teardown block removes the suite.
    private func makeStore() throws -> (ModelContainer, ModelContext, UserDefaults) {
        let container = try RetoldSchema.makeInMemoryContainer()
        containers.append(container)
        let suiteName = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        addTeardownBlock { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        return (container, container.mainContext, defaults)
    }

    private func fetchPeriods(_ context: ModelContext) throws -> [Period] {
        try context.fetch(FetchDescriptor<Period>())
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func testSeedsSixInOrderOnFirstRun() throws {
        let (_, context, defaults) = try makeStore()
        let seeded = try DefaultPeriods.seedIfNeeded(context, defaults: defaults, now: now)
        XCTAssertTrue(seeded)
        let periods = try fetchPeriods(context)
        XCTAssertEqual(periods.map(\.title), DefaultPeriods.titles)
        XCTAssertEqual(periods.map(\.sortOrder), [0, 1, 2, 3, 4, 5])
        for period in periods {
            XCTAssertNil(period.approxStartAge)
            XCTAssertNil(period.approxEndAge)
            XCTAssertEqual(period.createdAt, now)
        }
        XCTAssertTrue(defaults.bool(forKey: DefaultPeriods.seededKey))
    }

    func testSecondRunDoesNotReseed() throws {
        let (_, context, defaults) = try makeStore()
        XCTAssertTrue(try DefaultPeriods.seedIfNeeded(context, defaults: defaults, now: now))
        XCTAssertFalse(try DefaultPeriods.seedIfNeeded(context, defaults: defaults, now: now))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Period>()), 6)
    }

    func testDoesNotReseedAfterUserDeletesAll() throws {
        let (_, context, defaults) = try makeStore()
        XCTAssertTrue(try DefaultPeriods.seedIfNeeded(context, defaults: defaults, now: now))
        for period in try context.fetch(FetchDescriptor<Period>()) {
            context.delete(period)
        }
        try context.save()

        XCTAssertFalse(try DefaultPeriods.seedIfNeeded(context, defaults: defaults, now: now))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Period>()), 0)
    }

    func testExistingPeriodsSuppressSeedAndSetFlag() throws {
        let (_, context, defaults) = try makeStore()
        context.insert(Period(title: "The commune years", sortOrder: 0, createdAt: now))
        try context.save()

        XCTAssertFalse(try DefaultPeriods.seedIfNeeded(context, defaults: defaults, now: now))
        XCTAssertTrue(defaults.bool(forKey: DefaultPeriods.seededKey))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Period>()), 1)
    }

    func testSeedIsSavedBeforeFlag() throws {
        let (container, context, defaults) = try makeStore()
        XCTAssertTrue(try DefaultPeriods.seedIfNeeded(context, defaults: defaults, now: now))
        let freshContext = ModelContext(container)
        XCTAssertEqual(try freshContext.fetchCount(FetchDescriptor<Period>()), 6)
    }

    func testTitlesAreWellnessClean() {
        for title in DefaultPeriods.titles {
            XCTAssertTrue(WellnessLint.violations(in: title).isEmpty, title)
        }
    }
}
