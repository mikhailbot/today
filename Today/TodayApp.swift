import SwiftData
import SwiftUI

@main
struct TodayApp: App {
    @State private var calendar = CalendarStore()

    let container: ModelContainer = {
        // Syncs through the private CloudKit database when the app is signed with iCloud, local otherwise.
        let config = ModelConfiguration(cloudKitDatabase: .automatic)
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

    var body: some View {
        if calendar.status == .notDetermined && !skippedCalendarAccess {
            WelcomeView()
        } else {
            DayView()
        }
    }
}
