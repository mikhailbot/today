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
                VStack(alignment: .trailing, spacing: 2) {
                    Text(event.startDate.formatted(date: .omitted, time: .shortened))
                    Text(event.endDate.formatted(date: .omitted, time: .shortened))
                        .foregroundStyle(.secondary)
                }
                .font(.time)
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
                Circle()
                    .fill(Color(cgColor: event.calendar.cgColor))
                    .frame(width: 8, height: 8)
                    // Centre the dot on the title's lowercase letters rather than sitting on the baseline.
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title ?? "")
                        .fontWeight(.semibold)
                        .foregroundStyle(past ? .secondary : .primary)
                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                            Text(location)
                        }
                        .font(.detail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                time()
            }
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
            .opacity(past ? 0.7 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16))
    }

    private var nowLine: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(.tint)
                .frame(height: 1)
            Text(now.formatted(date: .omitted, time: .shortened))
                .font(.mark.monospacedDigit())
                .foregroundStyle(.tint)
        }
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
