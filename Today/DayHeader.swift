import SwiftUI

/// The date on the slab, like a Lock Screen: a large rounded numeral with the spoken day and the
/// month beside it. Tapping it opens the day picker; scrolling the day folds it to one line.
/// Jumping back to today is the floating pill.
struct DayHeader: View {
    let day: String
    let today: String
    let now: Date
    let collapsed: Bool
    let onPickDate: () -> Void
    let onSettings: () -> Void
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var numeral: CGFloat = 78
    @ScaledMetric(relativeTo: .subheadline) private var dot: CGFloat = 7

    var body: some View {
        let date = DayKey.date(for: day)
        let eyebrow = spokenDay(day, today: today, now: now)
        HStack(alignment: collapsed ? .center : .top) {
            Button(action: onPickDate) {
                Group {
                    if collapsed {
                        // Side by side, or stacked when large text won't fit them on one line.
                        let layout = typeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
                        layout {
                            Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                .font(.foldedDay)
                            Text(foldedTail(eyebrow))
                                .font(.spokenDay)
                                .opacity(0.75)
                        }
                        .transition(fold(anchor: .leading))
                    } else if typeSize.isAccessibilitySize {
                        stackedLockup(date: date, eyebrow: eyebrow)
                            .transition(fold(anchor: .topLeading))
                    } else {
                        lockup(date: date, eyebrow: eyebrow)
                            .transition(fold(anchor: .topLeading))
                    }
                }
                // Wrap at accessibility sizes rather than cut words off.
                .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(typeSize.isAccessibilitySize ? 1 : 0.6)
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

    /// The incoming date grows in; the outgoing one fades out at once, so it doesn't drift over the
    /// week strip as the header folds.
    private func fold(anchor: UnitPoint) -> AnyTransition {
        .asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.9, anchor: anchor)),
                    removal: .opacity.animation(.easeOut(duration: 0.1)))
    }

    /// At accessibility sizes the big numeral would crowd out the words, so the date reads as a
    /// line of text under the spoken day: "Saturday morning" above "November 7 ⌄".
    private func stackedLockup(date: Date, eyebrow: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            spoken(eyebrow)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(date.formatted(.dateTime.month(.wide).day()))
                    .font(.dayMonth)
                    // “September 30” is wider than the space beside the settings button at the
                    // largest sizes; it shrinks a little rather than break the date.
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.bold))
                    .opacity(0.7)
            }
        }
    }

    /// The day as you'd say it, with the mark's now dot in the slab's colours on today.
    private func spoken(_ eyebrow: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if day == today {
                Circle()
                    .fill(theme.nowOnSlab)
                    .frame(width: dot, height: dot)
                    .background(Circle().fill(theme.nowOnSlab.opacity(0.3)).padding(-dot * 0.3))
                    // Beside the first line when the spoken day wraps.
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + dot * 0.6 }
            }
            Text(eyebrow)
                .font(.spokenDay)
                .opacity(0.85)
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
                spoken(eyebrow)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(date.formatted(.dateTime.month(.wide)))
                        .font(.dayMonth)
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.bold))
                        .opacity(0.7)
                }
            }
        }
    }

    /// What the folded line adds to "Sat, Nov 7": the part of the day today, "Tomorrow" or
    /// "Yesterday" next to it, nothing further out.
    private func foldedTail(_ eyebrow: String) -> String {
        switch DayKey.days(from: today, to: day) {
        case 0: DayPart(now).rawValue
        case -1, 1: eyebrow
        default: ""
        }
    }
}
