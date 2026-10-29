import Foundation
import Testing
@testable import Today

struct DayKeyTests {
    private func calendar(firstWeekday: Int = 1, zone: String = "America/Toronto") -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: zone)!
        cal.firstWeekday = firstWeekday
        return cal
    }

    @Test func roundTripsKeys() {
        let cal = calendar()
        let date = DayKey.date(for: "2026-10-29", calendar: cal)
        #expect(DayKey.key(for: date, calendar: cal) == "2026-10-29")
        #expect(DayKey.key(for: date.addingTimeInterval(23 * 3600), calendar: cal) == "2026-10-29")
    }

    @Test func addsDaysAcrossMonthsAndDST() {
        let cal = calendar()
        #expect(DayKey.adding(1, to: "2026-10-31", calendar: cal) == "2026-11-01")
        #expect(DayKey.adding(1, to: "2026-11-01", calendar: cal) == "2026-11-02") // DST ends
        #expect(DayKey.adding(-1, to: "2026-01-01", calendar: cal) == "2025-12-31")
    }

    @Test func findsNextMonday() {
        let cal = calendar()
        #expect(DayKey.nextMonday(after: "2026-10-29", calendar: cal) == "2026-11-02")
        #expect(DayKey.nextMonday(after: "2026-11-02", calendar: cal) == "2026-11-09")
    }

    @Test func weekFollowsFirstWeekday() {
        #expect(DayKey.week(containing: "2026-10-29", calendar: calendar(firstWeekday: 1)).first == "2026-10-25")
        #expect(DayKey.week(containing: "2026-10-29", calendar: calendar(firstWeekday: 2)).first == "2026-10-26")
        #expect(DayKey.week(containing: "2026-10-29", calendar: calendar()).count == 7)
    }

    @Test func keysAreGregorianInOtherCalendars() {
        var japanese = Calendar(identifier: .japanese)
        japanese.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let date = DayKey.date(for: "2026-10-29", calendar: japanese)
        #expect(DayKey.key(for: date, calendar: japanese) == "2026-10-29")
    }
}

struct TaskOrderTests {
    @Test func openFirstThenDoneEachByCreation() {
        let base = Date(timeIntervalSince1970: 0)
        let a = TaskItem(title: "a", day: "2026-10-29", createdAt: base)
        let b = TaskItem(title: "b", day: "2026-10-29", createdAt: base.addingTimeInterval(1))
        let c = TaskItem(title: "c", day: "2026-10-29", createdAt: base.addingTimeInterval(2))
        let d = TaskItem(title: "d", day: "2026-10-29", createdAt: base.addingTimeInterval(3))
        a.isDone = true
        c.isDone = true
        #expect(TaskItem.ordered([d, c, b, a]).map(\.title) == ["b", "d", "a", "c"])
    }
}
