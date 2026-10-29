import EventKit
import Observation
import UIKit

@Observable
final class CalendarStore {
    let store = EKEventStore()
    private(set) var status = EKEventStore.authorizationStatus(for: .event)
    /// Bumped whenever the calendar database changes, so views refetch.
    private(set) var revision = 0

    var hasAccess: Bool { status == .fullAccess }

    init() {
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            self?.refresh()
        }
    }

    func requestAccess() async {
        _ = try? await store.requestFullAccessToEvents()
        await MainActor.run { refresh() }
    }

    func refresh() {
        status = EKEventStore.authorizationStatus(for: .event)
        revision += 1
    }

    func calendars() -> [EKCalendar] {
        guard hasAccess else { return [] }
        return store.calendars(for: .event)
    }

    /// Events on the given day from visible calendars, without declined invitations.
    func events(on day: String, hidden: Set<String>) -> [EKEvent] {
        guard hasAccess else { return [] }
        let visible = calendars().filter { !hidden.contains($0.calendarIdentifier) }
        guard !visible.isEmpty else { return [] }
        let start = DayKey.date(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: visible)
        return store.events(matching: predicate)
            .filter { $0.attendees?.first(where: \.isCurrentUser)?.participantStatus != .declined }
            .sorted { $0.startDate < $1.startDate }
    }

    static func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

/// Hidden calendar IDs, kept in @AppStorage as newline-separated text.
enum HiddenCalendars {
    static let storageKey = "hiddenCalendarIDs"

    static func decode(_ raw: String) -> Set<String> {
        Set(raw.split(separator: "\n").map(String.init))
    }

    static func encode(_ ids: Set<String>) -> String {
        ids.sorted().joined(separator: "\n")
    }
}
