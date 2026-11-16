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
                    // Only a status: sync follows the build and the iPhone's iCloud account, so there's
                    // nothing to choose and no page to open.
                    LabeledContent { Text(syncIsOn ? "On" : "Off") } label: {
                        Label("iCloud sync", systemImage: "icloud")
                    }
                } footer: {
                    #if ICLOUD_SYNC
                    Text("Tasks sync with the iCloud account on this iPhone. Events come from the accounts in the Calendar app.")
                    #else
                    Text("Tasks are stored on this iPhone only. Events come from the accounts in the Calendar app.")
                    #endif
                }
                Section {
                    LabeledContent {
                        AppearanceToggle(selected: $appearance)
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

    private var syncIsOn: Bool {
        #if ICLOUD_SYNC
        FileManager.default.ubiquityIdentityToken != nil
        #else
        false
        #endif
    }

    private var calendarsSummary: String {
        guard calendar.hasAccess else { return "Off" }
        let all = calendar.calendars().map(\.calendarIdentifier)
        let hidden = HiddenCalendars.decode(hiddenRaw)
        return "\(all.filter { !hidden.contains($0) }.count) of \(all.count)"
    }
}

/// System, light or dark as three icons on a small track, with a knob of the accent that slides to
/// the one chosen: one tap rather than a menu.
private struct AppearanceToggle: View {
    @Binding var selected: Appearance
    @Namespace private var knob

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Appearance.allCases) { option in
                let isOn = option == selected
                Button {
                    withAnimation(.spring(duration: 0.35, bounce: 0.3)) { selected = option }
                } label: {
                    Image(systemName: option.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isOn ? AnyShapeStyle(.onAccent) : AnyShapeStyle(.secondaryInk))
                        .symbolEffect(.bounce, value: isOn)
                        .frame(width: 38, height: 30)
                        .background {
                            if isOn {
                                Capsule().fill(.tint).matchedGeometryEffect(id: "knob", in: knob)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.name)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(3)
        .background(.past, in: Capsule())
        .sensoryFeedback(.selection, trigger: selected)
    }
}

private extension Appearance {
    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
}

/// Each theme as its own day in miniature, like a tiny phone: the slab with the date and its now dot,
/// then the mark's past, now and future on the paper. The chosen one lifts, ringed in its accent,
/// and its mark draws itself in again.
private struct ThemePicker: View {
    @Binding var selected: Theme

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 12)], spacing: 14) {
            ForEach(Theme.allCases) { theme in
                let isOn = theme == selected
                Button {
                    withAnimation(.spring(duration: 0.4, bounce: 0.35)) { selected = theme }
                } label: {
                    VStack(spacing: 8) {
                        ThemeDay(isSelected: isOn)
                            .environment(\.theme, theme)
                            .tint(theme.color(\.accent))
                        Text(theme.name)
                            .font(.detail.weight(isOn ? .semibold : .regular))
                            .foregroundStyle(isOn ? AnyShapeStyle(theme.color(\.accent)) : AnyShapeStyle(.secondaryInk))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(theme.name)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.vertical, 10)
        .sensoryFeedback(.selection, trigger: selected)
    }
}

/// One theme's day: its slab over its paper, in whichever appearance is showing.
private struct ThemeDay: View {
    let isSelected: Bool
    @Environment(\.theme) private var theme
    @State private var reveal = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let card = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 5) {
                Text("14")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                VStack(alignment: .leading, spacing: 3) {
                    Circle().fill(theme.nowOnSlab).frame(width: 5, height: 5)
                    Capsule().fill(theme.onSlab.opacity(0.85)).frame(width: 22, height: 4)
                    Capsule().fill(theme.onSlab.opacity(0.5)).frame(width: 14, height: 4)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(theme.onSlab)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background {
                UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10, style: .continuous)
                    .fill(theme.slab.gradient)
            }
            AppMarkGlyph(reveal: reveal)
                .frame(height: 30)
                .padding(.vertical, 9)
        }
        .background(.paper)
        .clipShape(card)
        .overlay(card.strokeBorder(Color(.separator), lineWidth: 0.5))
        .padding(3)
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .strokeBorder(.tint, lineWidth: 2.5)
                .opacity(isSelected ? 1 : 0)
        }
        .scaleEffect(isSelected ? 1 : 0.93)
        .offset(y: isSelected ? -2 : 0)
        .shadow(color: .black.opacity(isSelected ? 0.12 : 0), radius: 8, y: 4)
        .onChange(of: isSelected) { _, chosen in
            guard chosen, !reduceMotion else { return }
            reveal = 0
            withAnimation(.easeOut(duration: 0.9).delay(0.1)) { reveal = 1 }
        }
        .accessibilityHidden(true)
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
