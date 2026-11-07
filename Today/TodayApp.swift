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
    #if DEBUG
    @Environment(\.modelContext) private var context
    #endif

    var body: some View {
        Group {
            if calendar.status == .notDetermined && !skippedCalendarAccess {
                WelcomeView()
            } else {
                DayView()
            }
        }
        .tint(theme.color(\.accent))
        .environment(\.theme, theme)
        .onChange(of: appearance, initial: true) { appearance.apply() }
        #if DEBUG
        .task {
            if DebugSeed.isRequested { await DebugSeed.run(context: context, calendar: calendar) }
        }
        #endif
    }
}
