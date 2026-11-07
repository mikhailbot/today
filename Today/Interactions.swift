import SwiftUI

// Lively interactions: a tick that springs, washes the row in the accent and draws its line across,
// and a small celebration from the mark when the day's last task is done.

extension EnvironmentValues {
    /// Called when the last open task on the day is ticked off.
    @Entry var onAllDone: () -> Void = {}
}

/// A line drawn across a task's title from the leading edge, like a pen through a diary line.
struct DrawnStrike: ViewModifier {
    let isOn: Bool
    let animated: Bool
    @State private var drawn: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(.secondary)
                        .frame(width: geo.size.width * drawn, height: 1.5)
                        .frame(maxHeight: .infinity)
                }
                .allowsHitTesting(false)
            }
            .onAppear { drawn = isOn ? 1 : 0 }
            .onChange(of: isOn) { _, on in
                withAnimation(animated ? (on ? .easeOut(duration: 0.35) : .easeIn(duration: 0.2)) : nil) {
                    drawn = on ? 1 : 0
                }
            }
    }
}

/// The mark celebrates a finished day: the future bars sweep across to the past colour, the dot
/// lands at the end of its line, and \"All done\" settles underneath.
struct AllDoneCelebration: View {
    @State private var sweep = 0.0
    @State private var dot = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 14) {
            SweptMark(sweep: sweep, dot: dot)
                .frame(width: 96, height: 90)
            Text("All done")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.ink)
            Text("Every task for today is ticked off.")
                .font(.detail)
                .foregroundStyle(.secondaryInk)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .background(.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 30, y: 12)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .onAppear {
            guard !reduceMotion else { sweep = 1; dot = 1; return }
            withAnimation(.easeInOut(duration: 0.9).delay(0.15)) { sweep = 1 }
            withAnimation(.spring(duration: 0.6, bounce: 0.45).delay(0.75)) { dot = 1 }
        }
        .sensoryFeedback(.success, trigger: dot == 1)
    }
}

/// The icon's mark, with the future bars turning to past as `sweep` runs 0 to 1 and the dot sliding
/// from the start of its line to the end as `dot` runs 0 to 1.
private struct SweptMark: View, Animatable {
    var sweep: Double
    var dot: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(sweep, dot) }
        set { sweep = newValue.first; dot = newValue.second }
    }

    var body: some View {
        Canvas { context, size in
            let s = min(size.width / 76, size.height / 72)
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: (x - 12) * s, y: (y - 14) * s) }
            func bar(_ y: CGFloat, _ x1: CGFloat, _ x2: CGFloat, width: CGFloat, _ shading: GraphicsContext.Shading) {
                guard x2 > x1 else { return }
                var path = Path()
                path.move(to: p(x1, y))
                path.addLine(to: p(x2, y))
                context.stroke(path, with: shading, style: StrokeStyle(lineWidth: width * s, lineCap: .round))
            }
            bar(22, 24, 64, width: 7, .style(.past))
            bar(34, 24, 50, width: 7, .style(.past))
            // Each future bar fills with the past from its start, staggered.
            for (y, end, delay) in [(CGFloat(66), CGFloat(78), 0.0), (78, 58, 0.2)] {
                let t = CGFloat(min(max((sweep - delay) / 0.8, 0), 1))
                let edge = 24 + (end - 24) * t
                bar(y, 24, end, width: 7, .style(.future))
                if t > 0 { bar(y, 24, edge, width: 7, .style(.past)) }
            }
            bar(50, 22, 84, width: 5, .style(.now))
            let x = 22 + 62 * CGFloat(dot)
            let c = p(x, 50), r = 8 * s * (1 + 0.25 * sin(.pi * CGFloat(dot)))
            context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .style(.now))
        }
        .aspectRatio(76 / 72, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

#if DEBUG
/// Every theme side by side in miniature, light above dark, for comparing the papers.
/// Shown instead of the day when launched with `-themeGallery YES`.
struct ThemeGallery: View {
    @AppStorage(PaperStyle.storageKey) private var paper = PaperStyle.classic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(paper.name) papers")
                    .font(.title2.bold())
                    .padding(.horizontal, 4)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                          spacing: 12) {
                    ForEach(Theme.offered) { theme in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                tile(theme, .light)
                                tile(theme, .dark)
                            }
                            Text(theme.name).font(.footnote.weight(.semibold))
                        }
                    }
                }
            }
            .padding(14)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func tile(_ theme: Theme, _ scheme: ColorScheme) -> some View {
        ThemePreview(isSelected: false)
            .environment(\.theme, theme)
            .tint(theme.color(\.accent))
            .environment(\.colorScheme, scheme)
    }
}
#endif
