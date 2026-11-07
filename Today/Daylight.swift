import SwiftUI
import UIKit

/// Daylight: a sky behind the header and week strip that follows the time of day, in the theme's hue,
/// fading into the paper at the bottom. The sun is a soft glow crossing on an arc from dawn to dusk.
struct DaylightSky: View {
    /// The hour it shows, 0..<24.
    let hour: Double
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    static func hour(of date: Date) -> Double {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Double(c.hour ?? 12) + Double(c.minute ?? 0) / 60
    }

    var body: some View {
        let sky = Sky(hour: hour, theme: theme, dark: scheme == .dark)
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                gradient(sky)
                if let sun = sky.sun {
                    RadialGradient(colors: [Color(uiColor: sun.color).opacity(sun.strength), .clear],
                                   center: .center, startRadius: 0, endRadius: 150)
                        .frame(width: 300, height: 300)
                        .position(x: geo.size.width * sun.x, y: geo.size.height * sun.y)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func gradient(_ sky: Sky) -> some View {
        let (top, side, horizon, paper) = (Color(uiColor: sky.top), Color(uiColor: sky.side),
                                           Color(uiColor: sky.horizon), Color(uiColor: sky.paper))
        if #available(iOS 18, *) {
            MeshGradient(width: 3, height: 4, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.38], [0.55, 0.32], [1, 0.42],
                [0, 0.72], [0.45, 0.7], [1, 0.68],
                [0, 1], [0.5, 1], [1, 1],
            ], colors: [
                top, top.blend(with: side, by: 0.5), side,
                top.blend(with: horizon, by: 0.45), side.blend(with: horizon, by: 0.4), side.blend(with: horizon, by: 0.6),
                horizon.blend(with: paper, by: 0.35), horizon.blend(with: paper, by: 0.45), horizon.blend(with: paper, by: 0.3),
                paper, paper, paper,
            ], smoothsColors: true)
        } else {
            LinearGradient(stops: [.init(color: top, location: 0), .init(color: horizon, location: 0.6),
                                   .init(color: paper, location: 1)], startPoint: .top, endPoint: .bottom)
                .overlay {
                    LinearGradient(colors: [side.opacity(0.7), .clear], startPoint: .topTrailing, endPoint: .bottomLeading)
                        .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                }
        }
    }
}

/// The sky's colours at one hour: interpolated between keyframes, leaned towards the theme's accent,
/// then softened towards the paper until the ink still reads on it.
private struct Sky {
    var top: UIColor, side: UIColor, horizon: UIColor, paper: UIColor
    var sun: (x: CGFloat, y: CGFloat, color: UIColor, strength: Double)?

    /// Top of the sky, the side the light comes from, and the horizon, through a day.
    private static let keys: [(hour: Double, top: UInt32, side: UInt32, horizon: UInt32)] = [
        (0, 0x141B3D, 0x2A2357, 0x4A3F7A),
        (5.5, 0x2B3570, 0x6C5A9C, 0xE59AA0),
        (7, 0x7FA6E6, 0xF4B59A, 0xFFD8B8),
        (10, 0x6FB4F0, 0xA9D4F5, 0xE8F3FB),
        (13, 0x4FA3EE, 0x8CCBF7, 0xDDF0FC),
        (16.5, 0x6F9FE0, 0xF2C98E, 0xFBE7C6),
        (18.5, 0x4C4E9E, 0xF07F6A, 0xFFB98A),
        (20.5, 0x23285E, 0x6D4C8E, 0xC67A8E),
        (24, 0x141B3D, 0x2A2357, 0x4A3F7A),
    ]

    init(hour: Double, theme: Theme, dark: Bool) {
        let h = hour.truncatingRemainder(dividingBy: 24)
        let i = Self.keys.lastIndex { $0.hour <= h } ?? 0
        let a = Self.keys[i], b = Self.keys[min(i + 1, Self.keys.count - 1)]
        let t = b.hour > a.hour ? CGFloat((h - a.hour) / (b.hour - a.hour)) : 0
        func lerp(_ x: UInt32, _ y: UInt32) -> UIColor { UIColor(hex: x).mixed(with: UIColor(hex: y), by: t) }

        let palette = theme.palette(dark ? .dark : .light)
        let accent = UIColor(hex: palette.accent), ink = UIColor(hex: palette.ink)
        let paper = UIColor(hex: palette.paper)
        self.paper = paper
        // In the theme's hue, then darkened (dark) or lightened (light) until the ink reads on it,
        // keeping the colour's hue rather than greying it towards the paper.
        func dress(_ c: UIColor, hue: CGFloat, contrast: Double) -> UIColor {
            var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, al: CGFloat = 0
            c.mixed(with: accent, by: hue).getHue(&h, saturation: &s, brightness: &v, alpha: &al)
            var out = UIColor(hue: h, saturation: s, brightness: v, alpha: 1)
            for _ in 0..<40 where out.contrastRatio(with: ink) < contrast {
                if dark { v *= 0.92 } else { v = min(1, v + 0.04); s *= 0.94 }
                out = UIColor(hue: h, saturation: s, brightness: v, alpha: 1)
            }
            return out
        }
        top = dress(lerp(a.top, b.top), hue: 0.3, contrast: dark ? 8 : 6)
        side = dress(lerp(a.side, b.side), hue: 0.15, contrast: dark ? 7 : 5.5)
        horizon = dress(lerp(a.horizon, b.horizon), hue: 0.1, contrast: dark ? 9 : 8)

        // The sun rises at 6, peaks at 13 and sets at 20; the moon rides lower on the night side.
        if (6...20).contains(h) {
            let p = (h - 6) / 14
            let warm = h < 8.5 || h > 17 ? UIColor(hex: 0xFFB27A) : UIColor(hex: 0xFFF3C4)
            sun = (CGFloat(0.08 + 0.84 * p), CGFloat(0.42 - 0.34 * sin(.pi * p)), warm, dark ? 0.08 : 0.75)
        } else {
            let p = (h < 6 ? h + 4 : h - 20) / 10
            sun = (CGFloat(0.15 + 0.7 * p), 0.18, UIColor(hex: 0xC9D4FF), dark ? 0.22 : 0.4)
        }
    }
}

extension Color {
    /// This colour moved `amount` of the way to another.
    func blend(with other: Color, by amount: CGFloat) -> Color {
        Color(uiColor: UIColor(self).mixed(with: UIColor(other), by: amount))
    }
}
