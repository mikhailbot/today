import SwiftUI
import UIKit

/// The app's highlight colour, kept in @AppStorage and applied as the root tint.
enum Highlight: String, CaseIterable, Identifiable {
    case standard, blue, teal, green, orange, red, pink, purple

    static let storageKey = "highlight"

    var id: Self { self }

    var name: String { self == .standard ? "Indigo" : rawValue.capitalized }

    var color: Color { Color(uiColor: uiColor) }

    private var uiColor: UIColor {
        switch self {
        case .standard: UIColor(named: "AccentColor")!
        case .blue: .systemBlue
        case .teal: .systemTeal
        case .green: .systemGreen
        case .orange: .systemOrange
        case .red: .systemRed
        case .pink: .systemPink
        case .purple: .systemPurple
        }
    }

    /// Text on a filled highlight, such as the selected day: white or black, whichever contrasts more.
    /// White on the light dark-mode indigo is only 2.3:1, while black on it is 9:1.
    func textOnFill(_ scheme: ColorScheme) -> Color {
        let fill = uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light))
        return fill.contrastRatio(with: .white) >= fill.contrastRatio(with: .black) ? .white : .black
    }
}

extension UIColor {
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
