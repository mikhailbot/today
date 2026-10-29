import Foundation

/// Date keys like "2026-10-29": a day in the user's time zone, independent of the time of day.
enum DayKey {
    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let c = gregorian(like: calendar).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Start of the day for a key. Falls back to today for malformed keys.
    static func date(for key: String, calendar: Calendar = .current) -> Date {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        let g = gregorian(like: calendar)
        guard parts.count == 3,
              let date = g.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        else { return calendar.startOfDay(for: Date()) }
        return date
    }

    static func today(now: Date = Date(), calendar: Calendar = .current) -> String {
        key(for: now, calendar: calendar)
    }

    static func adding(_ days: Int, to key: String, calendar: Calendar = .current) -> String {
        let date = calendar.date(byAdding: .day, value: days, to: date(for: key, calendar: calendar))!
        return Self.key(for: date, calendar: calendar)
    }

    /// The first Monday strictly after the given day.
    static func nextMonday(after key: String, calendar: Calendar = .current) -> String {
        let next = calendar.nextDate(after: date(for: key, calendar: calendar),
                                     matching: DateComponents(hour: 0, weekday: 2),
                                     matchingPolicy: .nextTime)!
        return Self.key(for: next, calendar: calendar)
    }

    /// The seven days of the week containing the given day, starting on the calendar's first weekday.
    static func week(containing key: String, calendar: Calendar = .current) -> [String] {
        let start = calendar.dateInterval(of: .weekOfYear, for: date(for: key, calendar: calendar))!.start
        return (0..<7).map { Self.key(for: calendar.date(byAdding: .day, value: $0, to: start)!, calendar: calendar) }
    }

    /// Keys are always Gregorian, in the user's time zone, so they read the same on every device.
    private static func gregorian(like calendar: Calendar) -> Calendar {
        var g = Calendar(identifier: .gregorian)
        g.timeZone = calendar.timeZone
        return g
    }
}
