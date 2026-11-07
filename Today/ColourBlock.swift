import SwiftUI

/// Colour block: the date as a Lock Screen–style lockup on a slab of the theme colour. A large
/// rounded numeral, with the spoken day and the month beside it. Scrolling the day collapses it to
/// one line.
struct ColourBlockHeader: View {
    let day: String
    let today: String
    let now: Date
    let collapsed: Bool
    let onPickDate: () -> Void
    let onSettings: () -> Void
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .largeTitle) private var numeral: CGFloat = 78
    @ScaledMetric(relativeTo: .subheadline) private var dot: CGFloat = 7

    var body: some View {
        let date = DayKey.date(for: day)
        let eyebrow = spokenDay(day, today: today, now: now)
        HStack(alignment: collapsed ? .center : .top) {
            Button(action: onPickDate) {
                Group {
                    if collapsed {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                .font(.system(.title2, design: .rounded, weight: .bold))
                            Text(eyebrowTail(eyebrow))
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .opacity(0.75)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
                    } else {
                        lockup(date: date, eyebrow: eyebrow)
                            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topLeading)))
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(day == today ? "Today, " : "")\(eyebrow), \(date.formatted(.dateTime.month(.wide).day()))")
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint("Choose a day")
            Spacer(minLength: 12)
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.body.weight(.medium))
                    .frame(width: 22, height: 22)
            }
            .glassButton()
            .tint(theme.onSlab)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Settings")
        }
    }

    /// "Saturday morning" above "November ⌄", beside a big "7".
    private func lockup(date: Date, eyebrow: String) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 12) {
            Text(date.formatted(.dateTime.day()))
                .font(.system(size: numeral, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .padding(.vertical, -numeral * 0.12)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if day == today {
                        Circle()
                            .frame(width: dot, height: dot)
                            .background(Circle().opacity(0.3).padding(-dot * 0.3))
                    }
                    Text(eyebrow)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .opacity(0.85)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(date.formatted(.dateTime.month(.wide)))
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.bold))
                        .opacity(0.7)
                }
            }
        }
    }

    /// "morning" from "Saturday morning"; the collapsed line already names the weekday.
    private func eyebrowTail(_ eyebrow: String) -> String {
        day == today ? String(DayPart(now).rawValue) : ""
    }
}

/// The slab under the header: the theme colour from the top of the screen, with rounded lower corners.
struct ColourSlab: View {
    @Environment(\.theme) private var theme

    var body: some View {
        UnevenRoundedRectangle(bottomLeadingRadius: 30, bottomTrailingRadius: 30, style: .continuous)
            .fill(theme.slab.gradient)
            .accessibilityHidden(true)
    }
}
