import SwiftUI

/// The app's type scale. Text takes its style from here so every screen reads as one app.
/// All styles are Dynamic Type text styles, so they scale with the user's text size.
extension Font {
    /// The date at the top of the day.
    static let dayTitle = Font.largeTitle.bold()
    /// The spoken day above the date: "Friday morning", "Tomorrow".
    static let spokenDay = Font.subheadline.weight(.semibold)
    /// Section headings: "Calendar", "Tasks".
    static let sectionTitle = Font.title3.weight(.semibold)
    /// Small uppercase labels: the weekday above the date and section headings. Use `eyebrow()`.
    static let eyebrow = Font.footnote.weight(.semibold)
    /// Secondary row text: calendar and location, the leftovers list, the toast.
    static let detail = Font.subheadline
    /// Clock times, with digits that line up down the column.
    static let time = Font.footnote.monospacedDigit()
    /// Day numbers in the week strip.
    static let dayNumber = Font.callout.monospacedDigit()
    /// The smallest marks: week strip letters and the now line.
    static let mark = Font.caption.weight(.semibold)
}

extension View {
    /// The uppercase label style shared by the weekday above the date and every section heading.
    func eyebrow() -> some View {
        font(.eyebrow)
            .textCase(.uppercase)
            .tracking(0.4)
    }
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
        }
    }
}
