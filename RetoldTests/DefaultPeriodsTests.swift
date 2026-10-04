import Foundation
import SwiftData
import XCTest
@testable import Retold

@MainActor
final class DefaultPeriodsTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var suiteName: String!
    private var defaults: UserDefaults!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() throws {
        container = try RetoldSchema.makeInMemoryContainer()
        context = container.mainContext
        suiteName = UUID().uuidString
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func fetchPeriods() throws -> [Period] {
        try context.fetch(FetchDescriptor<Period>())
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func testSeedsSixInOrderOnFirstRun() throws {
        let seeded = try DefaultPeriods.seedIfNeeded(context, defaults: defaults, now: now)
        XCTAssertTrue(seeded)
        let periods = try fetchPeriods()
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
        XCTAssertTrue(try DefaultPeriods.seedIfNeeded(context, defaults: defaults, now: now))
        XCTAssertFalse(try DefaultPeriods.seedIfNeeded(context, defaults: defaults, now: now))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Period>()), 6)
    }

    func testDoesNotReseedAfterUserDeletesAll() throws {
        XCTAssertTrue(try DefaultPeriods.seedIfNeeded(context, defaults: defaults, now: now))
        for period in try context.fetch(FetchDescriptor<Period>()) {
            context.delete(period)
        }
        try context.save()

        XCTAssertFalse(try DefaultPeriods.seedIfNeeded(context, defaults: defaults, now: now))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Period>()), 0)
    }

    func testExistingPeriodsSuppressSeedAndSetFlag() throws {
        context.insert(Period(title: "The commune years", sortOrder: 0, createdAt: now))
        try context.save()

        XCTAssertFalse(try DefaultPeriods.seedIfNeeded(context, defaults: defaults, now: now))
        XCTAssertTrue(defaults.bool(forKey: DefaultPeriods.seededKey))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Period>()), 1)
    }

    func testSeedIsSavedBeforeFlag() throws {
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
