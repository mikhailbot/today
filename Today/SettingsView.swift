import EventKit
import SwiftUI

struct SettingsView: View {
    @Environment(CalendarStore.self) private var calendar
    @Environment(\.dismiss) private var dismiss
    @AppStorage(HiddenCalendars.storageKey) private var hiddenRaw = ""
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system
    /// Kept here and passed down: when the picker in its List row kept its own @AppStorage, the row
    /// stopped redrawing after the first change and the checkmark stayed on the first theme picked.
    @AppStorage(Theme.storageKey) private var theme = Theme.standard

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
                Section("Theme") {
                    ThemePicker(selected: $theme)
                }
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                }
            }
            .themedRows()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .themedSheet()
    }

    private var calendarsSummary: String {
        guard calendar.hasAccess else { return "Off" }
        let all = calendar.calendars().map(\.calendarIdentifier)
        let hidden = HiddenCalendars.decode(hiddenRaw)
        return "\(all.filter { !hidden.contains($0) }.count) of \(all.count)"
    }
}

/// Each theme as a small preview of its day, on its own paper.
private struct ThemePicker: View {
    @Binding var selected: Theme

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 12)], spacing: 14) {
            ForEach(Theme.allCases) { theme in
                Button {
                    withAnimation(.snappy) { selected = theme }
                } label: {
                    VStack(spacing: 6) {
                        ThemePreview(isSelected: theme == selected)
                            .environment(\.theme, theme)
                            .tint(theme.color(\.accent))
                        HStack(spacing: 4) {
                            Text(theme.name)
                            if theme == selected {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.tint)
                            }
                        }
                        .font(.detail.weight(theme == selected ? .semibold : .regular))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(theme.name)
                .accessibilityAddTraits(theme == selected ? .isSelected : [])
            }
        }
        .padding(.vertical, 8)
    }
}

/// A theme's day in miniature: the mark as the day's progress, a finished event, the now line,
/// the next event, and a ticked and an open task.
private struct ThemePreview: View {
    let isSelected: Bool

    var body: some View {
        let tile = RoundedRectangle(cornerRadius: 14, style: .continuous)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                Capsule().fill(.past).frame(width: 30, height: 3)
                Circle().fill(.now).frame(width: 7, height: 7)
                    .background(Circle().fill(.now.opacity(0.25)).padding(-2))
                Capsule().fill(.future).frame(height: 3)
            }
            .padding(.bottom, 2)
            row(Capsule().fill(.past).frame(width: 2.5, height: 9), line: .tertiaryInk, width: 0.55)
            HStack(spacing: 0) {
                Circle().fill(.now).frame(width: 5, height: 5)
                Capsule().fill(.now).frame(height: 1.5)
            }
            row(Capsule().fill(.orange).frame(width: 2.5, height: 9), line: .ink, width: 0.8)
            row(Circle().fill(.tint).frame(width: 9, height: 9), line: .secondaryInk, width: 0.5)
            row(Circle().strokeBorder(.tertiaryInk, lineWidth: 1).frame(width: 9, height: 9), line: .ink, width: 0.7)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.paper, in: tile)
        .overlay {
            tile.strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(.separator)),
                              lineWidth: isSelected ? 2 : 0.5)
        }
        .accessibilityHidden(true)
    }

    /// A marker, then a line of "text" taking `width` of what's left.
    private func row(_ marker: some View, line: ThemeColor, width: CGFloat) -> some View {
        HStack(spacing: 5) {
            marker.frame(width: 9)
            GeometryReader { geo in
                Capsule().fill(line).frame(width: geo.size.width * width, height: 4)
                    .frame(maxHeight: .infinity)
            }
            .frame(height: 9)
        }
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
        .themedRows()
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
        .themedRows()
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
                        .foregroundStyle(.secondaryInk)
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
                    .foregroundStyle(.secondaryInk)
            }
        }
        .themedRows()
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
