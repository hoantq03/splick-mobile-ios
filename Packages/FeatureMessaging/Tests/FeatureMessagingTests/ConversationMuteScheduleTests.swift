import XCTest
@testable import FeatureMessaging

final class ConversationMuteScheduleTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return calendar
    }

    func testDurationsAddFromNow() {
        let now = ISO8601DateFormatter().date(from: "2026-09-20T03:00:00Z")!
        XCTAssertEqual(
            ConversationMuteSchedule.mutedUntil(preset: .fifteenMinutes, now: now, calendar: calendar),
            now.addingTimeInterval(15 * 60)
        )
        XCTAssertEqual(
            ConversationMuteSchedule.mutedUntil(preset: .oneHour, now: now, calendar: calendar),
            now.addingTimeInterval(60 * 60)
        )
        XCTAssertNil(ConversationMuteSchedule.mutedUntil(preset: .forever, now: now, calendar: calendar))
    }

    func testUntilSevenAmUsesNextMorningWhenAlreadyPastSeven() {
        let afterSeven = ISO8601DateFormatter().date(from: "2026-09-20T01:00:00Z")!
        let until = ConversationMuteSchedule.mutedUntil(preset: .untilSevenAM, now: afterSeven, calendar: calendar)!
        let local = calendar.dateComponents([.hour, .minute, .day], from: until)
        XCTAssertEqual(local.hour, 7)
        XCTAssertEqual(local.minute, 0)
        XCTAssertEqual(local.day, 21)
        XCTAssertGreaterThan(until, afterSeven)
    }

    func testUntilSevenAmSameDayWhenBeforeSeven() {
        let beforeSeven = ISO8601DateFormatter().date(from: "2026-09-19T23:00:00Z")!
        let until = ConversationMuteSchedule.mutedUntil(preset: .untilSevenAM, now: beforeSeven, calendar: calendar)!
        let local = calendar.dateComponents([.hour, .day], from: until)
        XCTAssertEqual(local.hour, 7)
        XCTAssertEqual(local.day, 20)
    }

    func testRemainingUsesMinuteHourDayBuckets() {
        let now = ISO8601DateFormatter().date(from: "2026-09-20T03:00:00Z")!
        XCTAssertEqual(
            ConversationMuteSchedule.remaining(mutedUntil: now.addingTimeInterval(15 * 60), now: now),
            ConversationMuteRemaining(amount: 15, unit: .minutes)
        )
        XCTAssertEqual(
            ConversationMuteSchedule.remaining(mutedUntil: now.addingTimeInterval(1), now: now),
            ConversationMuteRemaining(amount: 1, unit: .minutes)
        )
        XCTAssertEqual(
            ConversationMuteSchedule.remaining(mutedUntil: now.addingTimeInterval(2 * 3600 + 10), now: now),
            ConversationMuteRemaining(amount: 2, unit: .hours)
        )
        XCTAssertEqual(
            ConversationMuteSchedule.remaining(mutedUntil: now.addingTimeInterval(25 * 3600), now: now),
            ConversationMuteRemaining(amount: 1, unit: .days)
        )
        XCTAssertNil(ConversationMuteSchedule.remaining(mutedUntil: nil, now: now))
        XCTAssertNil(ConversationMuteSchedule.remaining(mutedUntil: now.addingTimeInterval(-1), now: now))
    }
}
