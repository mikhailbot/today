import Combine
import EventKit
import SwiftUI

struct EventsSection: View {
    let day: String
    let today: String
    let onPickEvent: (EKEvent) -> Void
    @Environment(CalendarStore.self) private var calendar
    @AppStorage(HiddenCalendars.storageKey) private var hiddenRaw = ""
    @State private var events: [EKEvent] = []
    @State private var now = Date()
    @ScaledMetric private var timeWidth: CGFloat = 68

    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Section {
            if calendar.hasAccess {
                eventRows
            } else {
                accessRow
            }
        } header: {
            HStack {
                Text("Calendar")
                Spacer()
                if calendar.hasAccess {
                    Text(events.count == 1 ? "1 event" : "\(events.count) events")
                }
            }
            .eyebrow()
            .foregroundStyle(.secondary)
        }
        .task(id: "\(day)|\(hiddenRaw)|\(calendar.revision)") {
            events = calendar.events(on: day, hidden: HiddenCalendars.decode(hiddenRaw))
        }
        .onReceive(minuteTimer) { now = $0 }
    }

    @ViewBuilder private var eventRows: some View {
        let allDay = events.filter(\.isAllDay)
        let timed = events.filter { !$0.isAllDay }
        let isToday = day == today
        let nowIndex = isToday ? (timed.firstIndex { $0.endDate > now } ?? timed.count) : nil

        if events.isEmpty {
            Text("No events")
                .foregroundStyle(.secondary)
        }
        ForEach(allDay, id: \.calendarItemIdentifier) { event in
            row(event, past: false) {
                Text("All day")
                    .font(.detail)
                    .foregroundStyle(.secondary)
            }
        }
        ForEach(Array(timed.enumerated()), id: \.element.calendarItemIdentifier) { index, event in
            if index == nowIndex {
                nowLine
            }
            row(event, past: isToday && event.endDate <= now) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.startDate.formatted(date: .omitted, time: .shortened))
                        .font(.time.weight(.semibold))
                    Text(event.endDate.formatted(date: .omitted, time: .shortened))
                        .font(.time)
                        .foregroundStyle(.secondary)
                }
            }
        }
        if let nowIndex, nowIndex == timed.count, !timed.isEmpty {
            nowLine
        }
    }

    private func row(_ event: EKEvent, past: Bool, @ViewBuilder time: () -> some View) -> some View {
        Button {
            onPickEvent(event)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                time()
                    .frame(width: timeWidth, alignment: .leading)
                Circle()
                    .fill(Color(cgColor: event.calendar.cgColor))
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title ?? "")
                        .foregroundStyle(past ? .secondary : .primary)
                    if !event.isAllDay {
                        Text([event.calendar.title, event.location ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.detail)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
            .opacity(past ? 0.7 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var nowLine: some View {
        HStack(spacing: 8) {
            Text(now.formatted(date: .omitted, time: .shortened))
                .font(.mark.monospacedDigit())
                .foregroundStyle(.tint)
            Rectangle()
                .fill(.tint)
                .frame(height: 1)
        }
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowSeparator(.hidden)
        .accessibilityLabel("Now, \(now.formatted(date: .omitted, time: .shortened))")
    }

    private var accessRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Calendar access is off")
                Text("Turn it on to see your events here.")
                    .font(.detail)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Turn On") {
                if calendar.status == .notDetermined {
                    Task { await calendar.requestAccess() }
                } else {
                    CalendarStore.openSettings()
                }
            }
            .buttonStyle(.bordered)
        }
    }
}
