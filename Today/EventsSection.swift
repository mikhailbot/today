import Combine
import EventKit
import SwiftUI

/// The day's events on the page, read like a schedule: the time leads each row, all-day events
/// sit on top, past events are struck through (and folded away once there are several), the event
/// in progress shows how far through it you are, and the now line carries the time between events.
struct EventsSection: View {
    let day: String
    let today: String
    let onPickEvent: (EKEvent) -> Void
    @Environment(CalendarStore.self) private var calendar
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(HiddenCalendars.storageKey) private var hiddenRaw = ""
    @State private var events: [EKEvent] = []
    @State private var now = Date()
    @State private var showsEarlier = false
    @ScaledMetric(relativeTo: .footnote) private var timeColumn: CGFloat = 46

    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    /// More past events than this fold into one "earlier" row, so what's next stays near the top.
    private let pastShown = 3

    var body: some View {
        Section {
            if calendar.hasAccess {
                eventRows
            } else {
                accessRow
            }
        } header: {
            SectionHeading(title: "Calendar", detail: calendar.hasAccess ? summary : nil)
        }
        .task(id: "\(day)|\(hiddenRaw)|\(calendar.revision)") {
            events = calendar.events(on: day, hidden: HiddenCalendars.decode(hiddenRaw))
        }
        .onReceive(minuteTimer) { date in
            withAnimation(reduceMotion ? nil : .snappy) { now = date }
        }
    }

    /// "3 to go" today, a plain count on other days.
    private var summary: String? {
        if events.isEmpty { return nil }
        if day == today {
            let left = events.filter { !$0.isAllDay && $0.endDate > now }.count
            return left == 0 ? "All done" : "\(left) to go"
        }
        return events.count == 1 ? "1 event" : "\(events.count) events"
    }

    @ViewBuilder private var eventRows: some View {
        let allDay = events.filter(\.isAllDay)
        let timed = events.filter { !$0.isAllDay }
        let isToday = day == today
        let past = isToday ? timed.filter { $0.endDate <= now } : []
        let rest = isToday ? timed.filter { $0.endDate > now } : timed
        let folded = past.count > pastShown && !showsEarlier

        if events.isEmpty {
            emptyRow
        }
        ForEach(allDay, id: \.calendarItemIdentifier) { event in
            row(event, time: "All day", past: false, live: false)
        }
        if folded {
            earlierRow(count: past.count)
        } else {
            if past.count > pastShown { earlierRow(count: past.count) }
            ForEach(past, id: \.calendarItemIdentifier) { event in
                row(event, time: startText(event), past: true, live: false)
            }
        }
        // Between events, or after the last one; an event in progress shows its own progress instead.
        if isToday, !timed.isEmpty, rest.first.map({ $0.startDate > now }) ?? true {
            nowLine
        }
        ForEach(rest, id: \.calendarItemIdentifier) { event in
            row(event, time: startText(event), past: false, live: isToday && event.startDate <= now)
        }
    }

    private func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }

    /// Every row shares the same padding so the gaps between events are even.
    private let rowInsets = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
    /// The calendar bars' width and the gap after them. The now dots centre on the bars.
    private let barWidth: CGFloat = 4
    private let barGap: CGFloat = 10
    private let nowDot: CGFloat = 10

    /// The calendar's colour as one of the icon's short bars; grey once the event is over.
    private func bar(_ event: EKEvent, past: Bool) -> some View {
        Capsule()
            .fill(past ? AnyShapeStyle(.past) : AnyShapeStyle(Color(cgColor: event.calendar.cgColor)))
            .frame(width: barWidth, height: 16)
            // Centre on the title's lowercase letters rather than sitting on the baseline.
            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
    }

    /// Started on an earlier day and runs into this one, like a late call that crosses midnight.
    private func isCarriedOver(_ event: EKEvent) -> Bool {
        !event.isAllDay && event.startDate < DayKey.date(for: day)
    }

    @ViewBuilder private func timeLabel(_ text: String, past: Bool) -> some View {
        Text(text)
            .font(.time.weight(.medium))
            .foregroundStyle(past ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
    }

    /// The start time, or "until 00:15" for an event carried over from the day before.
    private func startText(_ event: EKEvent) -> String {
        isCarriedOver(event) ? "until \(time(event.endDate))" : time(event.startDate)
    }

    private func row(_ event: EKEvent, time: String, past: Bool, live: Bool) -> some View {
        Button {
            onPickEvent(event)
        } label: {
            Group {
                if typeSize.isAccessibilitySize {
                    // Too big for columns: the time goes above the title, and the title wraps.
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            timeLabel(time, past: past)
                            Spacer()
                            if !past && !event.isAllDay && !isCarriedOver(event) { durationLabel(event) }
                        }
                        HStack(alignment: .firstTextBaseline, spacing: barGap) {
                            bar(event, past: past)
                            details(event, past: past, live: live)
                        }
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: barGap) {
                        timeLabel(time, past: past)
                            .frame(width: timeColumn, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        bar(event, past: past)
                        details(event, past: past, live: live)
                        Spacer(minLength: 0)
                        if !past && !event.isAllDay && !isCarriedOver(event) { durationLabel(event) }
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(live ? EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16) : rowInsets)
        .listRowSeparator(.hidden)
        .accessibilityElement(children: .combine)
        .accessibilityValue(past ? "Ended" : live ? "In progress" : "")
    }

    @ViewBuilder private func details(_ event: EKEvent, past: Bool, live: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.title ?? "")
                .fontWeight(past ? .regular : .semibold)
                .foregroundStyle(past ? .secondary : .primary)
                // Ticked off, like a line in a paper diary.
                .strikethrough(past, color: .secondary)
                // Wrap at accessibility sizes rather than cut words off.
                .lineLimit(typeSize.isAccessibilitySize ? nil : past ? 1 : 2)
            if isCarriedOver(event) {
                Text("From \(event.startDate.formatted(.dateTime.weekday(.wide)))")
                    .font(.detail)
                    .foregroundStyle(.secondary)
            }
            if !past, let location = event.location, !location.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "location")
                    Text(location)
                }
                .font(.detail)
                .foregroundStyle(.secondary)
                .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
            }
            if live {
                ProgressLine(fraction: now.timeIntervalSince(event.startDate) / event.endDate.timeIntervalSince(event.startDate))
                    // Starts under the calendar bar, so the dot sets off from the bar's centre.
                    .padding(.leading, -(barGap + barWidth / 2))
                    .padding(.top, 6)
                Text("\(Int((event.endDate.timeIntervalSince(now) / 60).rounded(.up))) min left")
                    .font(.detail)
                    .foregroundStyle(.now)
                    .contentTransition(.numericText(countsDown: true))
            }
        }
    }

    /// "45m", "2h", "1h 30m".
    private func durationLabel(_ event: EKEvent) -> some View {
        let minutes = Int(event.endDate.timeIntervalSince(event.startDate) / 60)
        let text = minutes < 60 ? "\(minutes)m" : minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
        return Text(text)
            .font(.time)
            .foregroundStyle(.tertiary)
            .accessibilityLabel(Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .wide)))
    }

    /// Folds the past away behind a few grey bars, the icon's past.
    private func earlierRow(count: Int) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy) { showsEarlier.toggle() }
        } label: {
            HStack(spacing: 10) {
                if !typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 3) {
                        Capsule().fill(.past).frame(width: 22, height: 4)
                        Capsule().fill(.past).frame(width: 14, height: 4)
                    }
                    .frame(width: timeColumn, alignment: .leading)
                    .accessibilityHidden(true)
                }
                Text(showsEarlier ? "Hide earlier" : "\(count) earlier")
                    .font(.detail)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(showsEarlier ? 180 : 0))
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(rowInsets)
        .listRowSeparator(.hidden)
        .accessibilityLabel(showsEarlier ? "Hide earlier events" : "Show \(count) earlier events")
    }

    /// The icon's mark between events, carrying the time, with its dot centred on the calendar bars.
    @ViewBuilder private var nowLine: some View {
        let line = NowLine(dot: nowDot).padding(.leading, (barWidth - nowDot) / 2)
        let label = Text(time(now))
            .font(.time.weight(.bold))
            .foregroundStyle(.now)
        Group {
            if typeSize.isAccessibilitySize {
                // The bars sit at the start of the row here, under the time.
                VStack(alignment: .leading, spacing: 2) {
                    label
                    line
                }
            } else {
                HStack(spacing: barGap) {
                    label.frame(width: timeColumn, alignment: .leading)
                    line
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 0))
        .listRowSeparator(.hidden)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Now, \(time(now))")
    }

    /// One of the icon's bars, past or future, beside a word about the day.
    private var emptyRow: some View {
        let past = day < today
        return HStack(spacing: 10) {
            Capsule()
                .fill(past ? AnyShapeStyle(.past) : AnyShapeStyle(.future))
                .frame(width: 28, height: 5)
                .frame(width: typeSize.isAccessibilitySize ? nil : timeColumn, alignment: .leading)
                .accessibilityHidden(true)
            Text(past ? "Nothing was scheduled" : "A clear day")
                .foregroundStyle(.secondary)
        }
        .listRowInsets(rowInsets)
        .listRowSeparator(.hidden)
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
            .foregroundStyle(.tint)
        }
        .listRowInsets(rowInsets)
        .listRowSeparator(.hidden)
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
                    .fill(.future)
                    .frame(height: 4)
                Capsule()
                    .fill(.now)
                    .frame(width: x, height: 4)
                NowDot(size: 12)
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
