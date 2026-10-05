import Foundation
import XCTest
@testable import Retold

final class TimelineTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func id(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
    }

    private func period(_ n: Int, sortOrder: Int, title: String = "P") -> PeriodRef {
        PeriodRef(id: id(n), title: "\(title)\(n)", sortOrder: sortOrder)
    }

    private func episode(_ n: Int, period: UUID?, at offset: TimeInterval) -> TimelineEpisode {
        TimelineEpisode(id: id(n), periodID: period, createdAt: base.addingTimeInterval(offset))
    }

    func testPeriodsInSortOrder() {
        let periods = [
            period(1, sortOrder: 2),
            period(2, sortOrder: 0),
            period(3, sortOrder: 1),
        ]
        let sections = Timeline.sections(periods: periods, episodes: [])
        XCTAssertEqual(sections.map { $0.period?.id }, [id(2), id(3), id(1)])
    }

    func testEpisodesNewestFirst() {
        let p = period(1, sortOrder: 0)
        let episodes = [
            episode(10, period: p.id, at: 0),
            episode(11, period: p.id, at: 200),
            episode(12, period: p.id, at: 100),
        ]
        let sections = Timeline.sections(periods: [p], episodes: episodes)
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].episodeIDs, [id(11), id(12), id(10)])
    }

    func testEmptyPeriodKept() {
        let a = period(1, sortOrder: 0)
        let b = period(2, sortOrder: 1)
        let sections = Timeline.sections(periods: [a, b], episodes: [episode(10, period: a.id, at: 0)])
        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[1].period, b)
        XCTAssertEqual(sections[1].episodeIDs, [])
    }

    func testUnperiodedLast() {
        let a = period(1, sortOrder: 0)
        let sections = Timeline.sections(
            periods: [a],
            episodes: [episode(10, period: nil, at: 0), episode(11, period: a.id, at: 5)]
        )
        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[0].period, a)
        XCTAssertNil(sections[1].period)
        XCTAssertEqual(sections[1].episodeIDs, [id(10)])
    }

    func testNoUnperiodedSectionWhenNone() {
        let a = period(1, sortOrder: 0)
        let sections = Timeline.sections(periods: [a], episodes: [episode(10, period: a.id, at: 0)])
        XCTAssertEqual(sections.count, 1)
        XCTAssertFalse(sections.contains { $0.period == nil })
    }

    func testUnknownPeriodIDIsUnperioded() {
        let a = period(1, sortOrder: 0)
        let sections = Timeline.sections(
            periods: [a],
            episodes: [episode(10, period: id(99), at: 0)]
        )
        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[0].episodeIDs, [])
        XCTAssertNil(sections[1].period)
        XCTAssertEqual(sections[1].episodeIDs, [id(10)])
    }
}
