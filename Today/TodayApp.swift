import SwiftData
import SwiftUI

@main
struct TodayApp: App {
    @State private var calendar = CalendarStore()

    let container: ModelContainer = {
        #if ICLOUD_SYNC
        // Syncs through the private CloudKit database. Needs the iCloud capability (paid developer account).
        let config = ModelConfiguration(cloudKitDatabase: .automatic)
        #else
        let config = ModelConfiguration(cloudKitDatabase: .none)
        #endif
        do {
            return try ModelContainer(for: TaskItem.self, configurations: config)
        } catch {
            fatalError("Could not open the task store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(calendar)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @Environment(CalendarStore.self) private var calendar
    @AppStorage("skippedCalendarAccess") private var skippedCalendarAccess = false
    @AppStorage(Theme.storageKey) private var theme = Theme.standard
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system
    @AppStorage(PaperStyle.storageKey) private var paperStyle = PaperStyle.classic
    @Environment(\.modelContext) private var context
    #if DEBUG
    @State private var seeded = !DebugSeed.isRequested
    #endif

    var body: some View {
        #if DEBUG
        // The palettes read this when they resolve; `.id` below redraws everything when it changes.
        let _ = (PaperStyle.active = paperStyle)
        #endif
        Group {
            #if DEBUG
            if !seeded {
                Color.clear
            } else if UserDefaults.standard.bool(forKey: "themeGallery") {
                ThemeGallery()
            } else if calendar.status == .notDetermined && !skippedCalendarAccess {
                WelcomeView()
            } else {
                DayView()
            }
            #else
            if calendar.status == .notDetermined && !skippedCalendarAccess {
                WelcomeView()
            } else {
                DayView()
            }
            #endif
        }
        .tint(theme.color(\.accent))
        .environment(\.theme, theme)
        .modifier(DesignLabEnvironment())
        .id(paperStyle)
        .onChange(of: appearance, initial: true) { appearance.apply() }
        #if DEBUG
        .task {
            guard !seeded else { return }
            await DebugSeed.run(context: context, calendar: calendar)
            seeded = true
        }
        #endif
    }
}
