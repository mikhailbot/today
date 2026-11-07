import SwiftUI
import UIKit

/// The app's colour theme, kept in @AppStorage. A theme sets the accent, the page's tinted paper,
/// the ink, and the mark's past, now and future, each in light and dark.
enum Theme: String, CaseIterable, Identifiable {
    /// Indigo, the app icon's colour. Stored as "standard" from when this setting was a highlight colour.
    case standard, clay, moss, tide, plum, graphite

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
        let dark = scheme == .dark
        switch self {
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
