import Foundation
import SwiftUI
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

    @Test func namesPartsOfTheDayAtTheirBoundaries() {
        let cal = calendar()
        func part(_ h: Int, _ m: Int) -> DayPart {
            DayPart(DayKey.date(for: "2026-11-06", calendar: cal).addingTimeInterval(TimeInterval(h * 3600 + m * 60)), calendar: cal)
        }
        #expect(part(4, 59) == .night)
        #expect(part(5, 0) == .morning)
        #expect(part(11, 59) == .morning)
        #expect(part(12, 0) == .afternoon)
        #expect(part(16, 59) == .afternoon)
        #expect(part(17, 0) == .evening)
        #expect(part(20, 59) == .evening)
        #expect(part(21, 0) == .night)
        #expect(part(0, 30) == .night)
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

struct ThemeTests {
    /// Text must read at 4.5:1 or better wherever the theme puts it: ink on the page and on cards,
    /// accent words and buttons, the time on the now line, and the selected day's number on its fill.
    @Test(arguments: Theme.allCases, [ColorScheme.light, .dark])
    func textReads(theme: Theme, scheme: ColorScheme) {
        let p = theme.palette(scheme)
        let pairs: [(String, UInt32, UInt32)] = [
            ("ink on paper", p.ink, p.paper), ("ink on card", p.ink, p.card),
            ("secondary ink on paper", p.secondaryInk, p.paper), ("secondary ink on card", p.secondaryInk, p.card),
            ("accent on paper", p.accent, p.paper), ("accent on card", p.accent, p.card),
            ("now on paper", p.now, p.paper), ("day number on accent", p.onAccent, p.accent),
        ]
        for (name, text, background) in pairs {
            let ratio = UIColor(hex: text).contrastRatio(with: UIColor(hex: background))
            #expect(ratio >= 4.5, "\(theme.name) \(scheme) \(name): \(ratio)")
        }
    }

    /// The setting is stored under the old highlight key; every colour it offered still opens a theme.
    @Test func readsStoredHighlightColours() {
        #expect(Theme(rawValue: "standard") == .standard)
        #expect(Theme(rawValue: "blue") == .standard)
        #expect(Theme(rawValue: "teal") == .tide)
        #expect(Theme(rawValue: "green") == .moss)
        #expect(Theme(rawValue: "orange") == .clay)
        #expect(Theme(rawValue: "red") == .clay)
        #expect(Theme(rawValue: "pink") == .plum)
        #expect(Theme(rawValue: "purple") == .plum)
        #expect(Theme(rawValue: "nonsense") == nil)
        for theme in Theme.allCases { #expect(Theme(rawValue: theme.rawValue) == theme) }
    }
}
