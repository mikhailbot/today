import SwiftUI

/// The app's mark, from the icon: the past as grey bars, the present as a tinted dot on a line,
/// the future as light tinted bars. Every "now" in the app is drawn from these pieces.
extension ShapeStyle where Self == Color {
    /// The icon's past bars.
    static var past: Color { Color(light: 0xE5E5EA, dark: 0x3A3A3C) }
}

extension ShapeStyle where Self == TintShapeStyle {
    /// The icon's future bars: the tint, lightened.
    static var future: some ShapeStyle { TintShapeStyle.tint.opacity(0.25) }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        func color(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? color(dark) : color(light) })
    }
}

/// The dot that marks now, with its soft halo.
struct NowDot: View {
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(.tint)
            .frame(width: size, height: size)
            .background(Circle().fill(.future).padding(-size * 0.3))
    }
}

/// The dot at the start of a line running to the trailing edge.
struct NowLine: View {
    var dot: CGFloat = 10
    var thickness: CGFloat = 2.5

    var body: some View {
        HStack(spacing: 0) {
            NowDot(size: dot)
            Capsule()
                .fill(.tint)
                .frame(height: thickness)
                .padding(.leading, -2)
        }
        .frame(height: dot * 1.6)
    }
}

/// The icon's mark drawn in the app, so it follows the highlight colour.
/// Geometry matches `LaunchMark.svg` (viewBox 12 14 76 72).
struct AppMarkGlyph: View {
    var body: some View {
        Canvas { context, size in
            let s = min(size.width / 76, size.height / 72)
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: (x - 12) * s, y: (y - 14) * s) }
            func bar(_ y: CGFloat, _ x2: CGFloat, width: CGFloat, _ shading: GraphicsContext.Shading) {
                var path = Path()
                path.move(to: p(24, y))
                path.addLine(to: p(x2, y))
                context.stroke(path, with: shading, style: StrokeStyle(lineWidth: width * s, lineCap: .round))
            }
            bar(22, 64, width: 7, .color(.past))
            bar(34, 50, width: 7, .color(.past))
            bar(66, 78, width: 7, .style(.future))
            bar(78, 58, width: 7, .style(.future))
            var line = Path()
            line.move(to: p(22, 50))
            line.addLine(to: p(84, 50))
            context.stroke(line, with: .style(.tint), style: StrokeStyle(lineWidth: 5 * s, lineCap: .round))
            let c = p(22, 50)
            context.fill(Path(ellipseIn: CGRect(x: c.x - 8 * s, y: c.y - 8 * s, width: 16 * s, height: 16 * s)), with: .style(.tint))
        }
        .aspectRatio(76 / 72, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The mark on an icon-shaped tile.
struct AppMark: View {
    let size: CGFloat

    var body: some View {
        let tile = RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
        AppMarkGlyph()
            .padding(size * 0.175)
            .frame(width: size, height: size)
            .background(Color(.systemBackground), in: tile)
            .overlay(tile.stroke(Color(.separator), lineWidth: 0.5))
            .accessibilityHidden(true)
    }
}
