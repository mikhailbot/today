import Combine
import EventKit
import SwiftUI

/// One card with no separators: all-day events pinned on top, past events shrunk to grey single lines,
/// the event in progress tinted with a progress line, and the now line between events.
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
        // Nil once every event has ended, so the line disappears at the end of the day.
        let nowIndex = isToday ? timed.firstIndex { $0.endDate > now } : nil

        if events.isEmpty {
            Text("No events")
                .foregroundStyle(.secondary)
        }
        ForEach(allDay, id: \.calendarItemIdentifier) { event in
            compactRow(event, past: false, trailing: "All day")
                .listRowSeparator(.hidden)
        }
        ForEach(Array(timed.enumerated()), id: \.element.calendarItemIdentifier) { index, event in
            // Between events only: an event in progress shows its own progress line instead.
            if index == nowIndex, index > 0, event.startDate > now {
                nowLine
            }
            Group {
                if isToday && event.endDate <= now {
                    compactRow(event, past: true, trailing: event.startDate.formatted(date: .omitted, time: .shortened))
                } else {
                    fullRow(event, live: isToday && event.startDate <= now)
                }
            }
            .listRowSeparator(.hidden)
        }
    }

    /// Every row shares the same padding so the gaps between events are even.
    private let rowInsets = EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)

    private func dot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            // Centre the dot on the title's lowercase letters rather than sitting on the baseline.
            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
    }

    /// A single line: all-day events, and past events greyed out.
    private func compactRow(_ event: EKEvent, past: Bool, trailing: String) -> some View {
        Button {
            onPickEvent(event)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                dot(past ? Color(.systemGray3) : Color(cgColor: event.calendar.cgColor))
                Text(event.title ?? "")
                    .fontWeight(past ? .regular : .semibold)
                    .foregroundStyle(past ? .secondary : .primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(trailing)
                    .font(.time)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(rowInsets)
    }

    private func fullRow(_ event: EKEvent, live: Bool) -> some View {
        Button {
            onPickEvent(event)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                dot(Color(cgColor: event.calendar.cgColor))
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title ?? "")
                        .fontWeight(.semibold)
                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                            Text(location)
                        }
                        .font(.detail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                    if live {
                        ProgressLine(fraction: now.timeIntervalSince(event.startDate) / event.endDate.timeIntervalSince(event.startDate))
                            .padding(.top, 6)
                        Text("\(Int((event.endDate.timeIntervalSince(now) / 60).rounded(.up))) min left")
                            .font(.detail)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(event.startDate.formatted(date: .omitted, time: .shortened))
                    Text(event.endDate.formatted(date: .omitted, time: .shortened))
                        .foregroundStyle(.secondary)
                }
                .font(.time)
            }
            .background {
                if live {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.tint.opacity(0.09))
                        .padding(.horizontal, -8)
                        .padding(.vertical, -8)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // The event in progress gets extra room so its tint doesn't crowd its neighbours.
        .listRowInsets(live ? EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16) : rowInsets)
    }

    /// The app icon's mark: a dot on the left end of a line, lined up with the event dots.
    private var nowLine: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(.tint)
                .frame(width: 10, height: 10)
                .background(Circle().fill(.tint.opacity(0.22)).padding(-3))
            Capsule()
                .fill(.tint)
                .frame(height: 2.5)
                .padding(.leading, -2)
        }
        .padding(.leading, -1)
        .frame(height: 16)
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
        .listRowSeparator(.hidden)
        .accessibilityLabel("Now")
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

/// How far through the event in progress we are: a track with the icon's dot riding along it.
private struct ProgressLine: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            let x = geo.size.width * min(max(fraction, 0), 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.tint.opacity(0.22))
                    .frame(height: 4)
                Capsule()
                    .fill(.tint)
                    .frame(width: x, height: 4)
                Circle()
                    .fill(.tint)
                    .frame(width: 12, height: 12)
                    .offset(x: x - 6)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 12)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(fraction * 100)) percent")
    }
}
