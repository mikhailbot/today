import EventKit
import SwiftUI

struct SettingsView: View {
    @Environment(CalendarStore.self) private var calendar
    @Environment(\.dismiss) private var dismiss
    @AppStorage(HiddenCalendars.storageKey) private var hiddenRaw = ""
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        CalendarsSettings()
                    } label: {
                        LabeledContent { Text(calendarsSummary) } label: {
                            Label("Calendars", systemImage: "calendar")
                        }
                    }
                    NavigationLink {
                        SyncSettings()
                    } label: {
                        LabeledContent { Text(SyncSettings.isOn ? "On" : "Off") } label: {
                            Label("Sync", systemImage: "icloud")
                        }
                    }
                }
                Section {
                    Picker(selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.name).tag($0) }
                    } label: {
                        Label("Appearance", systemImage: "circle.lefthalf.filled")
                    }
                }
                Section("Highlight colour") {
                    HighlightPicker()
                }
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
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

    private var calendarsSummary: String {
        guard calendar.hasAccess else { return "Off" }
        let all = calendar.calendars().map(\.calendarIdentifier)
        let hidden = HiddenCalendars.decode(hiddenRaw)
        return "\(all.filter { !hidden.contains($0) }.count) of \(all.count)"
    }
}

private struct HighlightPicker: View {
    @AppStorage(Highlight.storageKey) private var highlight = Highlight.standard
    @ScaledMetric private var size: CGFloat = 30

    var body: some View {
        HStack {
            ForEach(Highlight.allCases) { option in
                Button {
                    highlight = option
                } label: {
                    Circle()
                        .fill(option.color)
                        .frame(width: size, height: size)
                        .overlay {
                            if option == highlight {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.name)
                .accessibilityAddTraits(option == highlight ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CalendarsSettings: View {
    @Environment(CalendarStore.self) private var calendar
    @AppStorage(HiddenCalendars.storageKey) private var hiddenRaw = ""

    var body: some View {
        List {
            if calendar.hasAccess {
                calendarSections
            } else {
                Section {
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
        }
        .navigationTitle("Calendars")
        .navigationBarTitleDisplayMode(.inline)
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

private struct SyncSettings: View {
    static var isOn: Bool {
        #if ICLOUD_SYNC
        FileManager.default.ubiquityIdentityToken != nil
        #else
        false
        #endif
    }

    var body: some View {
        List {
            Section {
                LabeledContent("iCloud sync", value: Self.isOn ? "On" : "Off")
            } footer: {
                #if ICLOUD_SYNC
                Text("Tasks sync with the iCloud account signed in on this iPhone. Change it in the Settings app.")
                #else
                Text("Tasks are stored on this iPhone only.")
                #endif
            }
            Section {
                LabeledContent("Calendar events", value: "From iOS")
            } footer: {
                Text("Events come from the accounts in the Calendar app and stay in sync with them.")
            }
        }
        .navigationTitle("Sync")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AboutView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    AppMark(size: 80, animated: true)
                    Text("Today")
                        .font(.title2.bold())
                    Text("Your events and tasks for the day, in one place.")
                        .font(.detail)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            Section {
                LabeledContent("Version", value: version)
            }
            Section("Privacy") {
                Text("Calendar events are only read, never changed. Nothing leaves your device except through your own iCloud account.")
                    .font(.detail)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
