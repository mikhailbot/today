import SwiftUI

/// The app's type scale. Text takes its style from here so every screen reads as one app.
/// All styles are Dynamic Type text styles, so they scale with the user's text size.
extension Font {
    /// The month beside the day's big numeral at the top of the day. The numeral itself is a scaled
    /// size in `DayHeader`, larger than any text style.
    static let dayMonth = Font.system(.title, design: .rounded, weight: .bold)
    /// The date on one line once the header folds: "Sat, Nov 7".
    static let foldedDay = Font.system(.title2, design: .rounded, weight: .bold)
    /// The spoken day above the month: "Friday morning", "Tomorrow".
    static let spokenDay = Font.system(.subheadline, design: .rounded, weight: .semibold)
    /// Section headings: "Calendar", "Tasks".
    static let sectionTitle = Font.title3.weight(.semibold)
    /// Secondary row text: calendar and location, the leftovers list, the toast.
    static let detail = Font.subheadline
    /// Clock times, with digits that line up down the column.
    static let time = Font.footnote.monospacedDigit()
    /// Day numbers in the week strip.
    static let dayNumber = Font.callout.monospacedDigit()
    /// The smallest marks: week strip letters.
    static let mark = Font.caption.weight(.semibold)
}

/// A section's heading: its name, and a short summary on the trailing side ("3 to go").
/// The summary drops below the name when both won't fit on one line.
struct SectionHeading: View {
    let title: String
    let detail: String?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                name
                Spacer(minLength: 12)
                summary
            }
            VStack(alignment: .leading, spacing: 2) {
                name
                summary
            }
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var name: some View {
        Text(title)
            .font(.sectionTitle)
            .foregroundStyle(.primary)
            .fixedSize()
    }

    @ViewBuilder private var summary: some View {
        if let detail {
            Text(detail)
                .font(.detail)
                .foregroundStyle(.secondary)
                .fixedSize()
                .contentTransition(.numericText())
                .animation(.snappy, value: detail)
        }
    }
}
