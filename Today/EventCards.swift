import EventKit
import SwiftUI
import UIKit

// Calendar colour: events as cards washed in their calendar's colour, the event in progress as a hero
// card that fills as it runs, like a Live Activity, and the free time between events said out loud.

/// How strongly a card is washed in its calendar's colour.
private func wash(_ scheme: ColorScheme) -> Double { scheme == .dark ? 0.26 : 0.15 }

/// The calendar's colour, darkened or lightened towards the ink until it reads as text on the paper.
private func readable(_ event: EKEvent, theme: Theme, scheme: ColorScheme) -> Color {
    let palette = theme.palette(scheme)
    let paper = UIColor(hex: palette.paper), ink = UIColor(hex: palette.ink)
    var c = UIColor(cgColor: event.calendar.cgColor)
    for _ in 0..<10 where c.contrastRatio(with: paper) < 4.5 { c = c.mixed(with: ink, by: 0.15) }
    return Color(uiColor: c)
}

/// One event: the time in the column on the left, then a card in the calendar's colour, taller for
/// longer events. Past events are grey and struck through, like the mark's past bars.
struct EventCard: View {
    let event: EKEvent
    let time: String
    let past: Bool
    let timeColumn: CGFloat
    let onPick: () -> Void
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: onPick) {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    timeLabel
                    card
                }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    timeLabel
                        .frame(width: timeColumn, alignment: .leading)
                        .padding(.top, past ? 9 : 13)
                    card
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(past ? "Ended" : "")
    }

    private var timeLabel: some View {
        Text(time)
            .font(.time.weight(.medium))
            .foregroundStyle(past ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
    }

    private var card: some View {
        let color = Color(cgColor: event.calendar.cgColor)
        let hours = event.endDate.timeIntervalSince(event.startDate) / 3600
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return HStack(alignment: .top, spacing: 10) {
            Capsule()
                .fill(past ? AnyShapeStyle(.past) : AnyShapeStyle(color))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title ?? "")
                    .fontWeight(past ? .regular : .semibold)
                    .foregroundStyle(past ? .secondary : .primary)
                    .strikethrough(past, color: .secondary)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : past ? 1 : 2)
                if !past {
                    HStack(spacing: 5) {
                        Text(event.calendar.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(readable(event, theme: theme, scheme: scheme))
                        if let location = event.location, !location.isEmpty {
                            Text("· \(location)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.detail)
                    .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                }
            }
            Spacer(minLength: 0)
            if !past && !event.isAllDay {
                let minutes = Int(hours * 60)
                Text(EventsSection.shortDuration(minutes: minutes))
                    .font(.time)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(EventsSection.spokenDuration(minutes: minutes))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, past ? 8 : 10)
        .padding(.leading, 8)
        .padding(.trailing, 12)
        // Longer events stand taller, up to three hours' worth.
        .frame(minHeight: past ? 0 : 40 + 22 * min(hours, 3), alignment: .top)
        .background(past ? AnyShapeStyle(.past.opacity(0.5)) : AnyShapeStyle(color.opacity(wash(scheme))), in: shape)
        .contentShape(shape)
    }
}

/// The event in progress: a large card that fills with its calendar's colour as time passes, with
/// the time left in big rounded numerals.
struct HeroEventCard: View {
    let event: EKEvent
    let now: Date
    let onPick: () -> Void
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var bigSize: CGFloat = 46

    var body: some View {
        let color = Color(cgColor: event.calendar.cgColor)
        let total = event.endDate.timeIntervalSince(event.startDate)
        let fraction = min(max(now.timeIntervalSince(event.startDate) / total, 0), 1)
        let minutes = Int((event.endDate.timeIntervalSince(now) / 60).rounded(.up))
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        Button(action: onPick) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    NowDot(size: 8, pulses: true)
                    Text("Now")
                        .foregroundStyle(.now)
                    Text(event.calendar.title)
                        .foregroundStyle(readable(event, theme: theme, scheme: scheme))
                    Spacer(minLength: 8)
                    Text("\(clock(event.startDate))–\(clock(event.endDate))")
                        .font(.time)
                        .foregroundStyle(.secondary)
                }
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                Text(event.title ?? "")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                    .padding(.top, 2)
                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                        Text(location)
                    }
                        .font(.detail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(minutes < 60 ? "\(minutes)" : EventsSection.shortDuration(minutes: minutes))
                        .font(.system(size: bigSize, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                    Text(minutes < 60 ? "min left" : "left")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text("\(Int(fraction * 100))%")
                        .font(.time.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                .padding(.top, -2)
            }
            .padding(16)
            .background {
                GeometryReader { geo in
                    let x = geo.size.width * fraction
                    ZStack(alignment: .bottomLeading) {
                        color.opacity(wash(scheme) * 0.8)
                        // The time gone fills from the leading edge, fading at now so it reads as light.
                        LinearGradient(stops: [.init(color: color.opacity(scheme == .dark ? 0.34 : 0.26), location: 0),
                                               .init(color: color.opacity(scheme == .dark ? 0.34 : 0.26), location: 0.85),
                                               .init(color: color.opacity(0.08), location: 1)],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: x)
                        // And a slim bar along the foot of the card in the calendar's colour.
                        Rectangle().fill(color).frame(width: x, height: 4)
                    }
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(color.opacity(0.35), lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue("In progress, \(EventsSection.timeLeft(event.endDate.timeIntervalSince(now)).spoken)")
    }

    private func clock(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }
}

/// All-day events as chips washed in their calendar's colour.
struct AllDayChips: View {
    let events: [EKEvent]
    let onPick: (EKEvent) -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chips; Spacer(minLength: 0) }
            VStack(alignment: .leading, spacing: 6) { chips }
        }
    }

    private var chips: some View {
        ForEach(events, id: \.calendarItemIdentifier) { event in
            let color = Color(cgColor: event.calendar.cgColor)
            Button { onPick(event) } label: {
                HStack(spacing: 6) {
                    Circle().fill(color).frame(width: 8, height: 8)
                    Text(event.title ?? "")
                        .font(.detail.weight(.semibold))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(color.opacity(wash(scheme)), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("All day, \(event.title ?? "")")
        }
    }
}

/// The time between two events, said quietly: "45 min free".
struct FreeGap: View {
    let minutes: Int
    let timeColumn: CGFloat
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 10) {
            if !typeSize.isAccessibilitySize {
                Color.clear.frame(width: timeColumn, height: 1)
            }
            Text(minutes < 60 ? "\(minutes) min free" : "\(EventsSection.shortDuration(minutes: minutes)) free")
                .font(.detail)
                .foregroundStyle(.tertiary)
                .fixedSize()
            Line()
                .stroke(.future, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.5, 6]))
                .frame(height: 2)
        }
        .accessibilityElement(children: .combine)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { $0.move(to: CGPoint(x: rect.minX, y: rect.midY)); $0.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) }
        }
    }
}
