import SwiftUI

// The app's mark, from the icon: the past as grey bars, the present as a dot on a line, the future
// as light bars, each in its theme colour (`.past`, `.now`, `.future`). Every "now" in the app is
// drawn from these pieces.

/// The dot that marks now, with its soft halo. A pulsing dot sends a slow ripple out from the
/// halo, like a clock ticking; it holds still when Reduce Motion is on.
struct NowDot: View {
    var size: CGFloat = 10
    var pulses = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(.now)
            .frame(width: size, height: size)
            .background(Circle().fill(.now.opacity(0.25)).padding(-size * 0.3))
            .background {
                if pulses && !reduceMotion {
                    PhaseAnimator([false, true]) { spread in
                        Circle()
                            .fill(.now.opacity(0.4))
                            .scaleEffect(spread ? 2.4 : 1)
                            .opacity(spread ? 0 : 1)
                    } animation: { spread in
                        spread ? .easeOut(duration: 2.4) : nil
                    }
                }
            }
    }
}

/// The dot at the start of a line running to the trailing edge.
struct NowLine: View {
    var dot: CGFloat = 10
    var thickness: CGFloat = 2.5

    var body: some View {
        HStack(spacing: 0) {
            NowDot(size: dot, pulses: true)
            Capsule()
                .fill(.now)
                .frame(height: thickness)
                .padding(.leading, -2)
        }
        .frame(height: dot * 1.6)
    }
}

/// The icon's mark drawn in the app, so it follows the theme.
/// Geometry matches `LaunchMark.svg` (viewBox 12 14 76 72). `reveal` draws it in from 0 to 1:
/// the past bars first, then the dot and its line, then the future.
struct AppMarkGlyph: View, Animatable {
    var reveal: Double = 1

    var animatableData: Double {
        get { reveal }
        set { reveal = newValue }
    }

    /// How far through its own stretch of the reveal one piece is, 0...1.
    private func stage(_ from: Double, _ to: Double) -> CGFloat {
        CGFloat(min(max((reveal - from) / (to - from), 0), 1))
    }

    var body: some View {
        let past = stage(0, 0.4), now = stage(0.3, 0.75), future = stage(0.55, 1)
        Canvas { context, size in
            let s = min(size.width / 76, size.height / 72)
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: (x - 12) * s, y: (y - 14) * s) }
            func bar(_ y: CGFloat, from x1: CGFloat, to x2: CGFloat, width: CGFloat, grown t: CGFloat,
                     _ shading: GraphicsContext.Shading) {
                guard t > 0 else { return }
                var path = Path()
                path.move(to: p(x1, y))
                path.addLine(to: p(x1 + (x2 - x1) * t, y))
                context.stroke(path, with: shading, style: StrokeStyle(lineWidth: width * s, lineCap: .round))
            }
            bar(22, from: 24, to: 64, width: 7, grown: past, .style(.past))
            bar(34, from: 24, to: 50, width: 7, grown: past, .style(.past))
            bar(66, from: 24, to: 78, width: 7, grown: future, .style(.future))
            bar(78, from: 24, to: 58, width: 7, grown: future, .style(.future))
            bar(50, from: 22, to: 84, width: 5, grown: now, .style(.now))
            let c = p(22, 50), r = 8 * s * min(now * 2, 1)
            context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .style(.now))
        }
        .aspectRatio(76 / 72, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The mark on an icon-shaped tile. An animated mark draws itself in when it appears,
/// or shows complete when Reduce Motion is on.
struct AppMark: View {
    let size: CGFloat
    var animated = false
    @State private var reveal = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let tile = RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
        AppMarkGlyph(reveal: animated && !reduceMotion ? reveal : 1)
            .padding(size * 0.175)
            .frame(width: size, height: size)
            .background(.card, in: tile)
            .overlay(tile.stroke(Color(.separator), lineWidth: 0.5))
            .accessibilityHidden(true)
            .onAppear {
                guard animated, !reduceMotion else { return }
                withAnimation(.easeOut(duration: 1.4).delay(0.25)) { reveal = 1 }
            }
    }
}
