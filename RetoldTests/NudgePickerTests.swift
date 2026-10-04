import Foundation
import XCTest
@testable import Retold

@MainActor
final class NudgePickerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_900_000_000)

    /// Six periods, start ages 0, 5, 11, 14, 18, 20, sortOrder 0-5; the age-14 one is
    /// thick (4 captures + 6 details), the rest are empty.
    private func sixPeriods() -> [NudgePeriod] {
        [0, 5, 11, 14, 18, 20].enumerated().map { index, age in
            NudgePeriod(
                key: .period(UUID()),
                captureCount: age == 14 ? 4 : 0,
                detailCount: age == 14 ? 6 : 0,
                lastVisitedAt: nil,
                startAge: age,
                sortOrder: index
            )
        }
    }

    private func item(_ period: PeriodKey, lastOfferedAt: Date? = nil, createdAt: Date? = nil,
                      kind: NudgeItemKind? = nil) -> NudgeItem {
        NudgeItem(
            kind: kind ?? .question(UUID()),
            period: period,
            createdAt: createdAt ?? now,
            lastOfferedAt: lastOfferedAt
        )
    }

    private func withLastVisited(_ period: NudgePeriod, at date: Date?) -> NudgePeriod {
        NudgePeriod(
            key: period.key,
            captureCount: period.captureCount,
            detailCount: period.detailCount,
            lastVisitedAt: date,
            startAge: period.startAge,
            sortOrder: period.sortOrder
        )
    }

    // MARK: score

    func testScoreEmptyNeverVisitedOldestOfSix() {
        let periods = sixPeriods()
        // T = 5, S = 30, A = 2: 4*5 + 30 + 2 = 52.
        XCTAssertEqual(NudgePicker.score(periods[0], among: periods, now: now), 52)
    }

    func testScoreThickPeriodVisitedThreeDaysAgo() {
        var periods = sixPeriods()
        // Fourth-oldest of 6 (i = 3): A = (2 * (6 - 1 - 3)) / (6 - 1) = 0.
        var thick = periods[3]
        thick = NudgePeriod(
            key: thick.key,
            captureCount: 10,
            detailCount: 0,
            lastVisitedAt: now.addingTimeInterval(-3 * 86_400),
            startAge: thick.startAge,
            sortOrder: thick.sortOrder
        )
        periods[3] = thick
        // T = 0, S = 3, A = 0.
        XCTAssertEqual(NudgePicker.score(thick, among: periods, now: now), 3)
    }

    func testScoreSinglePeriodGetsFullAgeWeight() {
        let only = NudgePeriod(
            key: .unfiled, captureCount: 0, detailCount: 0,
            lastVisitedAt: nil, startAge: nil, sortOrder: 0
        )
        // n == 1, so A = 2 regardless of index: 20 + 30 + 2 = 52.
        XCTAssertEqual(NudgePicker.score(only, among: [only], now: now), 52)
    }

    // MARK: pick

    func testNeverTheSamePeriodTwiceRunning() {
        let periods = sixPeriods()
        let items = periods.map { item($0.key) }
        let first = NudgePicker.pick(items: items, periods: periods, lastPeriod: nil, now: now)
        XCTAssertEqual(first?.period, periods[0].key)

        // With the first winner as lastPeriod the pick moves on, even though it would
        // still win on score.
        let second = NudgePicker.pick(
            items: items, periods: periods, lastPeriod: first?.period, now: now
        )
        XCTAssertEqual(second?.period, periods[1].key)
    }

    func testOnlyEligiblePeriodBeingLastPeriodMeansNil() {
        let periods = sixPeriods()
        let onlyItems = [item(periods[0].key)]
        XCTAssertNil(NudgePicker.pick(
            items: onlyItems, periods: periods, lastPeriod: periods[0].key, now: now
        ))
    }

    func testPeriodWithNoItemsNeverWins() {
        let periods = sixPeriods()
        // The thinnest, never-visited period would win on score (52), but only the
        // thick period has an item.
        let items = [item(periods[3].key)]
        let picked = NudgePicker.pick(items: items, periods: periods, lastPeriod: nil, now: now)
        XCTAssertEqual(picked?.period, periods[3].key)
    }

    func testTieBreaksToLowerSortOrder() {
        // Genuine 32-32 tie, composed differently: X = 0+30+2, Y = 8+23+1.
        let x = NudgePeriod(key: .period(UUID()), captureCount: 5, detailCount: 0,
                            lastVisitedAt: nil, startAge: 0, sortOrder: 1)
        let y = NudgePeriod(key: .period(UUID()), captureCount: 3, detailCount: 0,
                            lastVisitedAt: now.addingTimeInterval(-23 * 86_400),
                            startAge: 5, sortOrder: 0)
        // Z is thick and visited today, so it scores 0 and cannot win: 0+0+0.
        let z = NudgePeriod(key: .period(UUID()), captureCount: 5, detailCount: 0,
                            lastVisitedAt: now, startAge: 9, sortOrder: 2)
        let periods = [x, y, z]
        XCTAssertEqual(NudgePicker.score(x, among: periods, now: now), 32)
        XCTAssertEqual(NudgePicker.score(y, among: periods, now: now), 32)
        let items = [item(x.key), item(y.key), item(z.key)]
        let picked = NudgePicker.pick(items: items, periods: periods, lastPeriod: nil, now: now)
        XCTAssertEqual(picked?.period, y.key)
    }

    func testTieBreaksToPeriodBeforeUnfiled() {
        // Genuine 50-50 tie at equal sortOrder: 20+28+2 vs 20+30+0.
        let filed = NudgePeriod(key: .period(UUID()), captureCount: 0, detailCount: 0,
                                lastVisitedAt: now.addingTimeInterval(-28 * 86_400),
                                startAge: nil, sortOrder: 0)
        let unfiled = NudgePeriod(key: .unfiled, captureCount: 0, detailCount: 0,
                                  lastVisitedAt: nil, startAge: nil, sortOrder: 0)
        let periods = [unfiled, filed]
        XCTAssertEqual(NudgePicker.score(filed, among: periods, now: now), 50)
        XCTAssertEqual(NudgePicker.score(unfiled, among: periods, now: now), 50)
        let items = [item(filed.key), item(unfiled.key)]
        let picked = NudgePicker.pick(
            items: items, periods: periods, lastPeriod: nil, now: now
        )
        XCTAssertEqual(picked?.period, filed.key)
    }

    func testWithinPeriodNeverOfferedComesFirst() {
        let period = NudgePeriod(key: .period(UUID()), captureCount: 0, detailCount: 0,
                                 lastVisitedAt: nil, startAge: 0, sortOrder: 0)
        let offered = item(period.key, lastOfferedAt: now.addingTimeInterval(-86_400))
        let neverOffered = item(period.key, lastOfferedAt: nil)
        let picked = NudgePicker.pick(
            items: [offered, neverOffered], periods: [period], lastPeriod: nil, now: now
        )
        XCTAssertEqual(picked, neverOffered)
    }

    func testWithinPeriodQuestionBeforeRevisitAtEqualLastOfferedAt() {
        let period = NudgePeriod(key: .period(UUID()), captureCount: 0, detailCount: 0,
                                 lastVisitedAt: nil, startAge: 0, sortOrder: 0)
        let offeredAt = now.addingTimeInterval(-86_400)
        let revisit = item(period.key, lastOfferedAt: offeredAt,
                           kind: .revisit(captureID: UUID()))
        let question = item(period.key, lastOfferedAt: offeredAt)
        let picked = NudgePicker.pick(
            items: [revisit, question], periods: [period], lastPeriod: nil, now: now
        )
        XCTAssertEqual(picked, question)
    }

    // MARK: the 30-day literal rotation

    func testThirtyDayRotation() {
        var periods = sixPeriods()
        let items = periods.map { item($0.key) }
        let expectedByStartAge = [
            0, 5, 11, 18, 20, 14, 0, 5, 11, 18,
            0, 20, 5, 11, 0, 18, 5, 20, 0, 11,
            5, 18, 0, 20, 11, 5, 0, 18, 11, 20,
        ]
        var lastPeriod: PeriodKey? = nil
        var pickedAges: [Int] = []
        for day in 0..<30 {
            let dayNow = now.addingTimeInterval(Double(day) * 86_400)
            guard let picked = NudgePicker.pick(
                items: items, periods: periods, lastPeriod: lastPeriod, now: dayNow
            ) else {
                XCTFail("no pick on day \(day + 1)")
                break
            }
            lastPeriod = picked.period
            guard let winner = periods.first(where: { $0.key == picked.period }) else {
                XCTFail("picked period not among periods")
                break
            }
            pickedAges.append(winner.startAge ?? -1)
            guard let index = periods.firstIndex(where: { $0.key == picked.period }) else { continue }
            periods[index] = withLastVisited(winner, at: dayNow)
        }
        XCTAssertEqual(pickedAges, expectedByStartAge)
    }

    // MARK: isDue

    private let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func at(_ days: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        now.addingTimeInterval(Double(days) * 86_400 + Double(hour * 3600 + minute * 60))
    }

    func testIsDueDaily() {
        XCTAssertFalse(NudgePicker.isDue(cadence: .daily, lastNudgeAt: at(0), now: at(0), calendar: utc))
        XCTAssertTrue(NudgePicker.isDue(cadence: .daily, lastNudgeAt: at(0), now: at(1), calendar: utc))
        XCTAssertTrue(NudgePicker.isDue(cadence: .daily, lastNudgeAt: at(0), now: at(2), calendar: utc))
        XCTAssertTrue(NudgePicker.isDue(cadence: .daily, lastNudgeAt: at(0), now: at(7), calendar: utc))
    }

    func testIsDueThreeTimesWeekly() {
        XCTAssertFalse(NudgePicker.isDue(cadence: .threeTimesWeekly, lastNudgeAt: at(0), now: at(0), calendar: utc))
        XCTAssertFalse(NudgePicker.isDue(cadence: .threeTimesWeekly, lastNudgeAt: at(0), now: at(1), calendar: utc))
        XCTAssertTrue(NudgePicker.isDue(cadence: .threeTimesWeekly, lastNudgeAt: at(0), now: at(2), calendar: utc))
        XCTAssertTrue(NudgePicker.isDue(cadence: .threeTimesWeekly, lastNudgeAt: at(0), now: at(7), calendar: utc))
    }

    func testIsDueWeekly() {
        XCTAssertFalse(NudgePicker.isDue(cadence: .weekly, lastNudgeAt: at(0), now: at(0), calendar: utc))
        XCTAssertFalse(NudgePicker.isDue(cadence: .weekly, lastNudgeAt: at(0), now: at(1), calendar: utc))
        XCTAssertFalse(NudgePicker.isDue(cadence: .weekly, lastNudgeAt: at(0), now: at(2), calendar: utc))
        XCTAssertTrue(NudgePicker.isDue(cadence: .weekly, lastNudgeAt: at(0), now: at(7), calendar: utc))
    }

    func testIsDueOffNever() {
        for days in [0, 1, 2, 7] {
            XCTAssertFalse(NudgePicker.isDue(
                cadence: .off, lastNudgeAt: at(0), now: at(days), calendar: utc
            ))
        }
        XCTAssertFalse(NudgePicker.isDue(cadence: .off, lastNudgeAt: nil, now: at(0), calendar: utc))
    }

    func testIsDueNilLastNudgeIsDueExceptOff() {
        XCTAssertTrue(NudgePicker.isDue(cadence: .daily, lastNudgeAt: nil, now: at(0), calendar: utc))
        XCTAssertTrue(NudgePicker.isDue(cadence: .threeTimesWeekly, lastNudgeAt: nil, now: at(0), calendar: utc))
        XCTAssertTrue(NudgePicker.isDue(cadence: .weekly, lastNudgeAt: nil, now: at(0), calendar: utc))
    }

    func testIsDueCountsWholeDaysNotHours() {
        // 23:59 -> 00:01 is one day, not two.
        let day0 = utc.startOfDay(for: now)
        let lastNudgeAt = day0.addingTimeInterval(23 * 3600 + 59 * 60)
        let nextDay = day0.addingTimeInterval(86_400 + 60)
        XCTAssertTrue(NudgePicker.isDue(
            cadence: .daily, lastNudgeAt: lastNudgeAt, now: nextDay, calendar: utc
        ))
        XCTAssertFalse(NudgePicker.isDue(
            cadence: .threeTimesWeekly, lastNudgeAt: lastNudgeAt, now: nextDay, calendar: utc
        ))
    }
}
