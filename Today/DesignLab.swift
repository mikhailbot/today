import SwiftUI

// Design exploration switches. Each one defaults to the shipped design, and only DEBUG builds read
// them, so a Release build always looks like the current design.
//
// They're plain UserDefaults keys, so a launch argument sets them for one run, for screenshots:
//   -designDirection daylight|colourBlock|calendarColour   -paperStyle rich   -livelyInteractions YES
//   -skyHour 19.5   (pins Daylight's sky to a time of day)   -seedSampleDay YES   (see DebugSeed.swift)

/// How the day view is dressed.
enum DesignDirection: String, CaseIterable, Identifiable {
    /// The shipped design: ink on tinted paper.
    case current
    /// A sky behind the header that follows the time of day.
    case daylight
    /// The date and week strip on a slab of the theme colour.
    case colourBlock
    /// Events as cards in their calendar's colour, the one in progress as a hero card.
    case calendarColour

    static let storageKey = "designDirection"
    var id: Self { self }

    var name: String {
        switch self {
        case .current: "Current"
        case .daylight: "Daylight"
        case .colourBlock: "Colour block"
        case .calendarColour: "Calendar colour"
        }
    }
}

/// The themes' papers: the shipped near-white ones, or richer, more saturated ones with coloured dark modes.
enum PaperStyle: String, CaseIterable, Identifiable {
    case classic, rich

    static let storageKey = "paperStyle"
    var id: Self { self }
    var name: String { rawValue.capitalized }

    /// Read by `Theme.palette`, which resolves inside dynamic UIColors with no environment to hand.
    /// RootView keeps it in step with the stored setting.
    nonisolated(unsafe) static var active = PaperStyle.classic
}

enum DesignLab {
    static let livelyKey = "livelyInteractions"
    /// Pins Daylight's sky to an hour, 0..<24; negative follows the clock.
    static let skyHourKey = "skyHour"
}

extension EnvironmentValues {
    @Entry var designDirection = DesignDirection.current
    /// Springier ticks, a celebration for the last task, load bars and a gliding selection in the week strip.
    @Entry var livelyInteractions = false
}

/// Reads the stored design switches and hands them to the views below. Release builds ignore them.
struct DesignLabEnvironment: ViewModifier {
    @AppStorage(DesignDirection.storageKey) private var direction = DesignDirection.current
    @AppStorage(DesignLab.livelyKey) private var lively = false

    func body(content: Content) -> some View {
        #if DEBUG
        content
            .environment(\.designDirection, direction)
            .environment(\.livelyInteractions, lively)
        #else
        content
        #endif
    }
}

#if DEBUG
/// The Design lab section in Settings.
struct DesignLabSettings: View {
    @AppStorage(DesignDirection.storageKey) private var direction = DesignDirection.current
    @AppStorage(PaperStyle.storageKey) private var paper = PaperStyle.classic
    @AppStorage(DesignLab.livelyKey) private var lively = false
    @AppStorage(DesignLab.skyHourKey) private var skyHour = -1.0

    var body: some View {
        Section {
            Picker("Direction", selection: $direction) {
                ForEach(DesignDirection.allCases) { Text($0.name).tag($0) }
            }
            Picker("Paper", selection: $paper) {
                ForEach(PaperStyle.allCases) { Text($0.name).tag($0) }
            }
            Toggle("Lively interactions", isOn: $lively)
            if direction == .daylight {
                Picker("Sky", selection: $skyHour) {
                    Text("Follow the clock").tag(-1.0)
                    Text("Dawn").tag(6.5)
                    Text("Morning").tag(9.5)
                    Text("Midday").tag(13.0)
                    Text("Dusk").tag(18.5)
                    Text("Night").tag(22.5)
                }
            }
        } header: {
            Text("Design lab")
        } footer: {
            Text("DEBUG builds only. Each switch defaults to the shipped design.")
        }
    }
}
#endif
