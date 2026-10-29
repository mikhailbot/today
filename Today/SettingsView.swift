import EventKit
import SwiftUI

struct SettingsView: View {
    @Environment(CalendarStore.self) private var calendar
    @Environment(\.dismiss) private var dismiss
    @AppStorage(HiddenCalendars.storageKey) private var hiddenRaw = ""

    var body: some View {
        NavigationStack {
            List {
                if calendar.hasAccess {
                    calendarSections
                } else {
                    Section("Calendars") {
                        if calendar.status == .notDetermined {
                            Button("Allow calendar access") {
                                Task { await calendar.requestAccess() }
                            }
                        } else {
                            Text("Today can't read your calendars.")
                            Button("Open Settings") { CalendarStore.openSettings() }
                        }
                    }
                }
                Section {
                    #if ICLOUD_SYNC
                    LabeledContent("iCloud sync", value: FileManager.default.ubiquityIdentityToken != nil ? "On" : "Off")
                    #else
                    LabeledContent("iCloud sync", value: "Off")
                    #endif
                } header: {
                    Text("Tasks")
                } footer: {
                    #if ICLOUD_SYNC
                    Text("Tasks sync with the iCloud account signed in on this iPhone. Change it in the Settings app.")
                    #else
                    Text("Tasks are stored on this iPhone only.")
                    #endif
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder private var calendarSections: some View {
        let groups = Dictionary(grouping: calendar.calendars()) { $0.source?.title ?? "Other" }
        ForEach(groups.keys.sorted(), id: \.self) { source in
            Section(source) {
                ForEach(groups[source]!.sorted { $0.title < $1.title }, id: \.calendarIdentifier) { cal in
                    Toggle(isOn: shown(cal.calendarIdentifier)) {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(cgColor: cal.cgColor))
                                .frame(width: 10, height: 10)
                            Text(cal.title)
                        }
                    }
                }
            }
        }
    }

    private func shown(_ id: String) -> Binding<Bool> {
        Binding {
            !HiddenCalendars.decode(hiddenRaw).contains(id)
        } set: { isShown in
            var hidden = HiddenCalendars.decode(hiddenRaw)
            if isShown { hidden.remove(id) } else { hidden.insert(id) }
            hiddenRaw = HiddenCalendars.encode(hidden)
        }
    }
}
