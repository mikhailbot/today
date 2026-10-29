import SwiftUI

/// The app's highlight colour, kept in @AppStorage and applied as the root tint.
enum Highlight: String, CaseIterable, Identifiable {
    case standard, blue, teal, green, orange, red, pink, purple

    static let storageKey = "highlight"

    var id: Self { self }

    var name: String { self == .standard ? "Indigo" : rawValue.capitalized }

    var color: Color {
        switch self {
        case .standard: Color("AccentColor")
        case .blue: .blue
        case .teal: .teal
        case .green: .green
        case .orange: .orange
        case .red: .red
        case .pink: .pink
        case .purple: .purple
        }
    }
}
