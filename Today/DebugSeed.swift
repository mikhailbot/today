#if DEBUG
import EventKit
import SwiftData
import UIKit

/// A sample week for design screenshots: events in four coloured calendars around now (two past,
/// one in progress, more to come), open and done tasks today, yesterday's leftovers, and a few
/// tasks and events on the days around it.
///
/// Runs when the app is launched with `-seedSampleDay YES`. It replaces every task and the
/// calendars it made last time, so only use it on a simulator.
enum DebugSeed {
    static let key = "seedSampleDay"
    private static let calendarsKey = "seededCalendarIDs"

    static var isRequested: Bool { UserDefaults.standard.bool(forKey: key) }

    @MainActor static func run(context: ModelContext, calendar: CalendarStore) async {
        seedTasks(context)
        if !calendar.hasAccess { await calendar.requestAccess() }
        if calendar.hasAccess { seedEvents(calendar.store) }
        calendar.refresh()
    }

    private static func seedTasks(_ context: ModelContext) {
        try? context.delete(model: TaskItem.self)
        let today = DayKey.today()
        let start = Date().addingTimeInterval(-3600 * 6)
        var n = 0
        func add(_ title: String, _ offset: Int, done: Bool = false) {
            let task = TaskItem(title: title, day: DayKey.adding(offset, to: today),
                                createdAt: start.addingTimeInterval(Double(n) * 60))
            task.isDone = done
            context.insert(task)
            n += 1
        }
        add("Book flights for December", 0)
        add("Reply to Lena about the deck", 0)
        add("Pick up dry cleaning", 0)
        add("Water the plants", 0)
        add("Pay the hydro bill", 0, done: true)
        add("Order Theo's birthday present", 0, done: true)
        add("Return library books", -1)
        add("Send invoice #42", -1)
        add("Renew passport photos", -1, done: true)
        add("Call the landlord", -3)
        add("Draft Q4 goals", -4, done: true)
        add("Groceries", -2, done: true)
        add("Plan Sunday lunch", 1)
        add("Prep slides for Monday", 2)
        add("Book a haircut", 2)
        add("Car service", 4)
        try? context.save()
    }

    private static func seedEvents(_ store: EKEventStore) {
        // Remove the calendars from the last run, with their events.
        for id in UserDefaults.standard.stringArray(forKey: calendarsKey) ?? [] {
            if let old = store.calendar(withIdentifier: id) { try? store.removeCalendar(old, commit: false) }
        }
        guard let source = store.sources.first(where: { $0.sourceType == .local })
                ?? store.defaultCalendarForNewEvents?.source else { return }
        func makeCalendar(_ title: String, _ hex: UInt32) -> EKCalendar {
            let cal = EKCalendar(for: .event, eventStore: store)
            cal.title = title
            cal.source = source
            cal.cgColor = UIColor(hex: hex).cgColor
            try? store.saveCalendar(cal, commit: false)
            return cal
        }
        let work = makeCalendar("Work", 0x2F7CF6)
        let personal = makeCalendar("Personal", 0xFF9500)
        let family = makeCalendar("Family", 0xE6406B)
        let fitness = makeCalendar("Fitness", 0x2DB55D)
        UserDefaults.standard.set([work, personal, family, fitness].map(\.calendarIdentifier), forKey: calendarsKey)

        let cal = Calendar.current
        let now = Date()
        // Now, rounded down to the quarter hour, so times read like real ones.
        let minute = cal.component(.minute, from: now)
        let base = cal.dateInterval(of: .hour, for: now)!.start.addingTimeInterval(Double(minute / 15 * 15) * 60)
        func add(_ title: String, _ calendar: EKCalendar, from: Double, to: Double, at location: String? = nil,
                 day: Int = 0, allDay: Bool = false) {
            let event = EKEvent(eventStore: store)
            event.title = title
            event.calendar = calendar
            event.location = location
            let dayBase = cal.date(byAdding: .day, value: day, to: base)!
            if allDay {
                event.isAllDay = true
                event.startDate = cal.startOfDay(for: dayBase)
                event.endDate = event.startDate
            } else {
                event.startDate = dayBase.addingTimeInterval(from * 3600)
                event.endDate = dayBase.addingTimeInterval(to * 3600)
            }
            try? store.save(event, span: .thisEvent, commit: false)
        }

        // Today, in hours from now.
        add("Mum's birthday", family, from: 0, to: 0, allDay: true)
        add("Run club", fitness, from: -3.25, to: -2.5, at: "Trinity Bellwoods")
        add("Standup", work, from: -1.75, to: -1.5)
        add("Design review", work, from: -0.25, to: 0.75, at: "Room 4B · Zoom")
        add("Lunch with Sam", personal, from: 1.5, to: 2.5, at: "Pai Northern Thai")
        add("Pick up Theo", family, from: 4, to: 4.5)
        add("Climbing", fitness, from: 6.5, to: 8, at: "Basecamp")

        // The days around it, for the week strip's load bars.
        add("Planning", work, from: -1, to: 1, day: -1)
        add("1:1 with Ana", work, from: 2, to: 2.5, day: -1)
        add("Yoga", fitness, from: -2, to: -1, day: -2)
        add("Offsite", work, from: -2, to: 5, day: -3)
        add("Dinner at Gran's", family, from: 6, to: 8, day: -4)
        add("Dentist", personal, from: 1, to: 2, day: -5)
        add("Brunch", personal, from: 0, to: 1.5, day: 1)
        add("Sprint kickoff", work, from: -1, to: 0, day: 2)
        add("Design crit", work, from: 2, to: 3.5, day: 2)
        add("Swim", fitness, from: 5, to: 6, day: 2)
        add("Parents' evening", family, from: 7, to: 8, day: 3)
        add("All hands", work, from: 1, to: 2, day: 4)
        try? store.commit()
    }
}
#endif
