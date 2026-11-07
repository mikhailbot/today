import SwiftUI

// A small celebration from the mark when the day's last task is ticked off.

extension EnvironmentValues {
    /// Called when the last open task on the day is ticked off.
    @Entry var onAllDone: () -> Void = {}
}

/// The mark celebrates a finished day: the future bars sweep across to the past colour, the dot
/// lands at the end of its line, and "All done" settles underneath.
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
