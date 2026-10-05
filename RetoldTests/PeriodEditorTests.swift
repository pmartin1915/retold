import Foundation
import SwiftData
import XCTest
@testable import Retold

@MainActor
final class PeriodEditorTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        container = try RetoldSchema.makeInMemoryContainer()
        context = container.mainContext
    }

    @discardableResult
    private func seed(_ titles: [String]) throws -> [Period] {
        var periods: [Period] = []
        for (index, title) in titles.enumerated() {
            let period = Period(title: title, sortOrder: index, createdAt: now)
            context.insert(period)
            periods.append(period)
        }
        try context.save()
        return periods
    }

    private func titles() throws -> [String] {
        let reopened = ModelContext(container)
        return try reopened.fetch(FetchDescriptor<Period>(sortBy: [SortDescriptor(\Period.sortOrder)]))
            .map(\.title)
    }

    func testAddAppendsSortOrder() throws {
        try seed(["Early childhood", "Primary school"])
        let added = try PeriodEditor.add(title: "Twenties", in: context, now: now)
        XCTAssertEqual(added.sortOrder, 2)
        XCTAssertEqual(added.createdAt, now)
        XCTAssertEqual(try titles(), ["Early childhood", "Primary school", "Twenties"])

    }

    func testAddToEmptyStoreStartsAtZero() throws {
        let added = try PeriodEditor.add(title: "First", in: context, now: now)
        XCTAssertEqual(added.sortOrder, 0)
    }

    func testAddTrims() throws {
        let added = try PeriodEditor.add(title: "  \n The farm years \t", in: context, now: now)
        XCTAssertEqual(added.title, "The farm years")
        XCTAssertEqual(try titles(), ["The farm years"])
    }

    func testAddEmptyThrows() throws {
        for blank in ["", "   ", "\n\t "] {
            XCTAssertThrowsError(try PeriodEditor.add(title: blank, in: context, now: now)) { error in
                XCTAssertEqual(error as? PeriodEditError, .emptyTitle)
            }
        }
        XCTAssertEqual(try titles(), [])
    }

    func testAddDuplicateThrowsCaseInsensitive() throws {
        try seed(["High school"])
        for duplicate in ["High school", "  high SCHOOL ", "HIGH SCHOOL"] {
            XCTAssertThrowsError(try PeriodEditor.add(title: duplicate, in: context, now: now)) { error in
                XCTAssertEqual(error as? PeriodEditError, .duplicateTitle)
            }
        }
        XCTAssertEqual(try titles(), ["High school"])
    }

    func testRenameTrims() throws {
        let periods = try seed(["Early childhood"])
        try PeriodEditor.rename(periods[0], to: "  The farm years \n", in: context)
        XCTAssertEqual(periods[0].title, "The farm years")
        XCTAssertEqual(try titles(), ["The farm years"])
    }

    func testRenameDuplicateThrows() throws {
        let periods = try seed(["Early childhood", "Primary school"])
        XCTAssertThrowsError(
            try PeriodEditor.rename(periods[1], to: " early CHILDHOOD ", in: context)
        ) { error in
            XCTAssertEqual(error as? PeriodEditError, .duplicateTitle)
        }
        XCTAssertEqual(periods[1].title, "Primary school")
    }

    func testRenameToOwnTitleAllowed() throws {
        let periods = try seed(["Early childhood", "Primary school"])
        try PeriodEditor.rename(periods[0], to: "Early childhood", in: context)
        try PeriodEditor.rename(periods[0], to: "EARLY CHILDHOOD", in: context)
        XCTAssertEqual(periods[0].title, "EARLY CHILDHOOD")
        XCTAssertEqual(try titles(), ["EARLY CHILDHOOD", "Primary school"])
    }

    func testRenameWithPreexistingDuplicateAllowed() throws {
        let periods = try seed(["Twin", "Twin"])
        try PeriodEditor.rename(periods[0], to: "Twin", in: context)
        try PeriodEditor.rename(periods[1], to: "Twin", in: context)
        XCTAssertEqual(try titles(), ["Twin", "Twin"])
    }

    func testFailedEditWritesNothing() throws {
        let periods = try seed(["Early childhood", "Primary school"])
        let before = try titles()

        XCTAssertThrowsError(try PeriodEditor.add(title: "  ", in: context, now: now))
        XCTAssertThrowsError(try PeriodEditor.add(title: "primary SCHOOL", in: context, now: now))
        XCTAssertThrowsError(try PeriodEditor.rename(periods[0], to: "", in: context))
        XCTAssertThrowsError(try PeriodEditor.rename(periods[0], to: "Primary school", in: context))

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Period>()), 2)
        XCTAssertEqual(try titles(), before)
        XCTAssertEqual(periods[0].title, "Early childhood")
        XCTAssertFalse(context.hasChanges)
    }
}
