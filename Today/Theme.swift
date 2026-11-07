import SwiftUI
import UIKit

/// The app's colour theme, kept in @AppStorage. A theme sets the accent, the page's tinted paper,
/// the ink, and the mark's past, now and future, each in light and dark.
enum Theme: String, CaseIterable, Identifiable {
    /// Indigo, the app icon's colour. Stored as "standard" from when this setting was a highlight colour.
    case standard, clay, moss, tide, plum, graphite
    /// Bolder themes from the design lab: butter-yellow paper, and cobalt paper with a coral now.
    case marigold, cobalt

    /// The themes the picker offers. The bold ones only show with the rich papers in the design lab.
    static var offered: [Theme] {
        PaperStyle.active == .rich ? allCases : [.standard, .clay, .moss, .tide, .plum, .graphite]
    }

    /// The key of the highlight colour setting this replaced, so a stored choice carries over.
    static let storageKey = "highlight"

    /// Also reads the highlight colours the app used to offer, as the theme nearest each one.
    init?(rawValue: String) {
        switch rawValue {
        case "standard", "blue": self = .standard
        case "clay", "orange", "red": self = .clay
        case "moss", "green": self = .moss
        case "tide", "teal": self = .tide
        case "plum", "pink", "purple": self = .plum
        case "graphite": self = .graphite
        case "marigold": self = .marigold
        case "cobalt": self = .cobalt
        default: return nil
        }
    }

    var id: Self { self }

    var name: String { self == .standard ? "Indigo" : rawValue.capitalized }

    /// Colours as sRGB hex for one appearance.
    struct Palette {
        /// Buttons, the selected day, ticked tasks.
        var accent: UInt32
        /// The mark's now: its dot and line, and the words that say what time it is.
        var now: UInt32
        /// The page.
        var paper: UInt32
        /// Rows on a grouped list, such as Settings.
        var card: UInt32
        var ink: UInt32
        var secondaryInk: UInt32
        var tertiaryInk: UInt32
        /// The mark's past bars: hours gone, finished events.
        var past: UInt32
        /// The mark's future bars: hours to come.
        var future: UInt32

        /// Text on the accent, such as the selected day's number: the paper or the ink, whichever reads better.
        var onAccent: UInt32 {
            UIColor(hex: paper).contrastRatio(with: UIColor(hex: accent))
                >= UIColor(hex: ink).contrastRatio(with: UIColor(hex: accent)) ? paper : ink
        }
    }

    func palette(_ scheme: ColorScheme) -> Palette {
        PaperStyle.active == .rich ? richPalette(scheme) : classicPalette(scheme)
    }

    /// The shipped palettes: near-white tinted papers, near-black dark modes.
    private func classicPalette(_ scheme: ColorScheme) -> Palette {
        let dark = scheme == .dark
        switch self {
        case .marigold, .cobalt:
            return richPalette(scheme)
        case .standard:
            return dark
                ? Palette(accent: 0x93A5FF, now: 0x93A5FF, paper: 0x0F1017, card: 0x1B1C26, ink: 0xECEEF8,
                          secondaryInk: 0xA4A8BC, tertiaryInk: 0x6C7084, past: 0x2F3140, future: 0x303551)
                : Palette(accent: 0x3A56D4, now: 0x3A56D4, paper: 0xF7F8FC, card: 0xFFFFFF, ink: 0x1B1D2B,
                          secondaryInk: 0x585C70, tertiaryInk: 0x9094A6, past: 0xE4E6EE, future: 0xC8D0F2)
        case .clay:
            return dark
                ? Palette(accent: 0xF09A78, now: 0xF09A78, paper: 0x191512, card: 0x25201C, ink: 0xF2EAE1,
                          secondaryInk: 0xB5A89C, tertiaryInk: 0x7D7268, past: 0x3A332D, future: 0x4F362C)
                : Palette(accent: 0xA8432A, now: 0xA8432A, paper: 0xFAF6F0, card: 0xFFFDF9, ink: 0x2B231D,
                          secondaryInk: 0x6B5F56, tertiaryInk: 0xA2968C, past: 0xEAE2D7, future: 0xE6C9BE)
        case .moss:
            return dark
                ? Palette(accent: 0x93CC9B, now: 0x93CC9B, paper: 0x111510, card: 0x1C211B, ink: 0xE7EDE5,
                          secondaryInk: 0xA3AD9F, tertiaryInk: 0x6C7569, past: 0x2E352C, future: 0x324333)
                : Palette(accent: 0x3A6B43, now: 0x3A6B43, paper: 0xF4F6EF, card: 0xFCFDF9, ink: 0x1E261F,
                          secondaryInk: 0x5A6459, tertiaryInk: 0x939C91, past: 0xE0E5D8, future: 0xC6D3C4)
        case .tide:
            return dark
                ? Palette(accent: 0x70CFD9, now: 0x70CFD9, paper: 0x0D1416, card: 0x172023, ink: 0xE2EEF0,
                          secondaryInk: 0x9CB1B4, tertiaryInk: 0x667A7D, past: 0x2A3537, future: 0x264347)
                : Palette(accent: 0x0B6A78, now: 0x0B6A78, paper: 0xF1F6F7, card: 0xFAFDFD, ink: 0x14282B,
                          secondaryInk: 0x546769, tertiaryInk: 0x8DA0A3, past: 0xDCE6E8, future: 0xB8D3D7)
        case .plum:
            return dark
                ? Palette(accent: 0xE79CD1, now: 0xE79CD1, paper: 0x171115, card: 0x231B21, ink: 0xF2E6EE,
                          secondaryInk: 0xB7A4B0, tertiaryInk: 0x7E6C77, past: 0x3A2E36, future: 0x4B3444)
                : Palette(accent: 0x893470, now: 0x893470, paper: 0xFBF6F8, card: 0xFFFCFD, ink: 0x2A1D25,
                          secondaryInk: 0x6C5B66, tertiaryInk: 0xA4949E, past: 0xEDE2E8, future: 0xDEC6D6)
        case .graphite:
            // Pencil on newsprint, with one red mark for now.
            return dark
                ? Palette(accent: 0xE6E4DF, now: 0xFF7D5E, paper: 0x141414, card: 0x1F1F1F, ink: 0xECEAE5,
                          secondaryInk: 0xA8A6A0, tertiaryInk: 0x72716C, past: 0x323230, future: 0x5A5955)
                : Palette(accent: 0x2F2F31, now: 0xB83A26, paper: 0xF4F3EF, card: 0xFBFAF7, ink: 0x1C1C1C,
                          secondaryInk: 0x5E5D59, tertiaryInk: 0x98968F, past: 0xE3E1DB, future: 0xC9C7C0)
        }
    }

    /// Design lab: papers you can see the colour of, and dark modes on coloured paper (navy, espresso,
    /// forest, deep sea, aubergine) instead of near-black.
    private func richPalette(_ scheme: ColorScheme) -> Palette {
        let dark = scheme == .dark
        switch self {
        case .standard:
            return dark
                ? Palette(accent: 0x9DAEFF, now: 0x9DAEFF, paper: 0x121A3D, card: 0x1C2550, ink: 0xE9ECFF,
                          secondaryInk: 0xA6AED6, tertiaryInk: 0x7880AD, past: 0x2A3462, future: 0x34418A)
                : Palette(accent: 0x3347D1, now: 0x3347D1, paper: 0xE6EBFD, card: 0xF6F8FF, ink: 0x161A33,
                          secondaryInk: 0x4A5072, tertiaryInk: 0x767C9E, past: 0xD0D6EE, future: 0xAFBBF5)
        case .clay:
            return dark
                ? Palette(accent: 0xFF9D74, now: 0xFF9D74, paper: 0x2A1812, card: 0x38221A, ink: 0xF8E9DE,
                          secondaryInk: 0xC6A997, tertiaryInk: 0x977A69, past: 0x4A3027, future: 0x6B3826)
                : Palette(accent: 0xAE3F1B, now: 0xAE3F1B, paper: 0xF5E3D3, card: 0xFFF6EE, ink: 0x2E1D14,
                          secondaryInk: 0x6E5446, tertiaryInk: 0x987E6F, past: 0xE6D0BF, future: 0xEDB29B)
        case .moss:
            return dark
                ? Palette(accent: 0x8FDB9C, now: 0x8FDB9C, paper: 0x10241A, card: 0x1A3325, ink: 0xE4F1E6,
                          secondaryInk: 0x9DBBA4, tertiaryInk: 0x6E8E79, past: 0x22402F, future: 0x2A5A3B)
                : Palette(accent: 0x2B6537, now: 0x2B6537, paper: 0xE1EBD6, card: 0xF4F8EF, ink: 0x17241A,
                          secondaryInk: 0x4C5F4E, tertiaryInk: 0x728476, past: 0xCCDAC0, future: 0xA6C8A6)
        case .tide:
            return dark
                ? Palette(accent: 0x5FDDE8, now: 0x5FDDE8, paper: 0x0A2429, card: 0x123239, ink: 0xDDF3F5,
                          secondaryInk: 0x8FB8BD, tertiaryInk: 0x618A90, past: 0x1C3F45, future: 0x18565E)
                : Palette(accent: 0x006A76, now: 0x006A76, paper: 0xD9EDEE, card: 0xF1F9F9, ink: 0x0F2A2E,
                          secondaryInk: 0x46666B, tertiaryInk: 0x6A878B, past: 0xC4DCDE, future: 0x98D0D6)
        case .plum:
            return dark
                ? Palette(accent: 0xF29BD8, now: 0xF29BD8, paper: 0x26122A, card: 0x351C3A, ink: 0xF6E4F2,
                          secondaryInk: 0xC4A1BD, tertiaryInk: 0x93708E, past: 0x3F2744, future: 0x5C2C5A)
                : Palette(accent: 0x88276C, now: 0x88276C, paper: 0xF3DFEB, card: 0xFCF3F8, ink: 0x2C1424,
                          secondaryInk: 0x6B4A5F, tertiaryInk: 0x96778B, past: 0xE4CCDA, future: 0xE0AFD1)
        case .graphite:
            return dark
                ? Palette(accent: 0xF0EEE8, now: 0xFF6B4A, paper: 0x1E1D1B, card: 0x2A2926, ink: 0xF0EEE8,
                          secondaryInk: 0xB0ADA5, tertiaryInk: 0x7F7D76, past: 0x3A3936, future: 0x605E58)
                : Palette(accent: 0x1E1E20, now: 0xB3301A, paper: 0xE8E6E0, card: 0xF7F6F2, ink: 0x161616,
                          secondaryInk: 0x55534E, tertiaryInk: 0x84827B, past: 0xD6D3CB, future: 0xBBB7AD)
        case .marigold:
            // Butter-yellow paper with a tomato accent; dark is burnt amber with a marigold accent.
            return dark
                ? Palette(accent: 0xFFB627, now: 0xFFB627, paper: 0x2B1D06, card: 0x3A2A0E, ink: 0xFFF1CF,
                          secondaryInk: 0xD8BE84, tertiaryInk: 0xA38C58, past: 0x4A3815, future: 0x6E4A10)
                : Palette(accent: 0xB93A0A, now: 0xB93A0A, paper: 0xFBE6A6, card: 0xFFF5D6, ink: 0x2A1D05,
                          secondaryInk: 0x67511C, tertiaryInk: 0x8E7841, past: 0xEDD187, future: 0xF2B26A)
        case .cobalt:
            // Cobalt paper with a coral now; dark is deep ultramarine with a yellow accent.
            return dark
                ? Palette(accent: 0xFFD54A, now: 0xFF8466, paper: 0x0C1A52, card: 0x16276A, ink: 0xEEF2FF,
                          secondaryInk: 0xA9B8EC, tertiaryInk: 0x7D8ECD, past: 0x22337A, future: 0x2C47A8)
                : Palette(accent: 0x1A3AD6, now: 0xB52E10, paper: 0xD3E0FF, card: 0xEEF3FF, ink: 0x0A1640,
                          secondaryInk: 0x3A4A80, tertiaryInk: 0x66759F, past: 0xBCCBF2, future: 0x98B0FF)
        }
    }

    /// Colour block's slab: the light accent, deepened a little in dark mode so it stays a colour
    /// rather than a pastel. Graphite uses its red now, its one colour.
    var slab: Color {
        Color(uiColor: UIColor { traits in
            let light = self.palette(.light)
            let base = UIColor(hex: self == .graphite ? light.now : light.accent)
            return traits.userInterfaceStyle == .dark ? base.mixed(with: .black, by: 0.28) : base
        })
    }

    /// Text on the slab: white or the ink, whichever reads better.
    var onSlab: Color {
        Color(uiColor: UIColor { traits in
            let slab = UIColor(self.slab).resolvedColor(with: traits)
            let ink = UIColor(hex: self.palette(.light).ink)
            return slab.contrastRatio(with: .white) >= slab.contrastRatio(with: ink) ? .white : ink
        })
    }

    /// One palette colour, following light and dark.
    func color(_ role: KeyPath<Palette, UInt32>) -> Color { Color(uiColor: uiColor(role)) }

    func uiColor(_ role: KeyPath<Palette, UInt32>) -> UIColor {
        let light = palette(.light)[keyPath: role], dark = palette(.dark)[keyPath: role]
        return UIColor { UIColor(hex: $0.userInterfaceStyle == .dark ? dark : light) }
    }
}

extension EnvironmentValues {
    /// Set at the root from the stored theme; the Settings previews set their own.
    @Entry var theme = Theme.standard
}

/// A colour from the theme in the environment, so `.fill(.past)` follows the theme wherever it's drawn.
struct ThemeColor: ShapeStyle {
    let role: KeyPath<Theme.Palette, UInt32> & Sendable

    func resolve(in environment: EnvironmentValues) -> Color {
        environment.theme.color(role)
    }
}

extension ShapeStyle where Self == ThemeColor {
    static var paper: ThemeColor { ThemeColor(role: \.paper) }
    static var card: ThemeColor { ThemeColor(role: \.card) }
    static var ink: ThemeColor { ThemeColor(role: \.ink) }
    static var secondaryInk: ThemeColor { ThemeColor(role: \.secondaryInk) }
    static var tertiaryInk: ThemeColor { ThemeColor(role: \.tertiaryInk) }
    static var onAccent: ThemeColor { ThemeColor(role: \.onAccent) }
    /// The icon's past bars.
    static var past: ThemeColor { ThemeColor(role: \.past) }
    /// The icon's dot and line.
    static var now: ThemeColor { ThemeColor(role: \.now) }
    /// The icon's future bars.
    static var future: ThemeColor { ThemeColor(role: \.future) }
}

extension View {
    /// The theme's paper behind a sheet and the lists in it.
    func themedSheet() -> some View {
        scrollContentBackground(.hidden)
            .presentationBackground(.paper)
    }

    /// Rows on the theme's card colour, for the sections of a themed sheet.
    func themedRows() -> some View {
        listRowBackground(Rectangle().fill(.card))
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    /// This colour moved `amount` of the way to another, in sRGB.
    func mixed(with other: UIColor, by amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * amount, green: g1 + (g2 - g1) * amount,
                       blue: b1 + (b2 - b1) * amount, alpha: a1 + (a2 - a1) * amount)
    }

    /// WCAG relative luminance of the colour in sRGB.
    var relativeLuminance: Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ c: CGFloat) -> Double {
            let c = Double(min(max(c, 0), 1))
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    /// WCAG contrast ratio, from 1 to 21. Body text needs at least 4.5.
    func contrastRatio(with other: UIColor) -> Double {
        let (a, b) = (relativeLuminance, other.relativeLuminance)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
