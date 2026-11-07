import UIKit

/// Light or dark whatever the system setting, kept in @AppStorage and applied to the app's windows.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appearance"

    var id: Self { self }

    var name: String { rawValue.capitalized }

    /// Set on each window rather than through preferredColorScheme, which leaves an open sheet in the
    /// old style when switching back to System. Sheets, including UIKit ones, inherit the window's style.
    @MainActor func apply() {
        let style: UIUserInterfaceStyle = switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows { window.overrideUserInterfaceStyle = style }
        }
    }
}
