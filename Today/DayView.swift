import Combine
import SwiftData
import SwiftUI

struct DayView: View {
    @Environment(CalendarStore.self) private var calendar
    @Environment(\.scenePhase) private var scenePhase
    @State private var today = DayKey.today()
    @State private var day = DayKey.today()
    @State private var showDatePicker = false
    @State private var showSettings = false
    @State private var movingTask: TaskItem?
    @State private var lastMove: LastMove?

    var body: some View {
        NavigationStack {
            DayList(day: $day, today: today,
                    onMove: move,
                    onPickMove: { movingTask = $0 },
                    onPickDate: { showDatePicker = true },
                    onSettings: { showSettings = true })
                .toolbar(.hidden, for: .navigationBar)
                .overlay(alignment: .bottom) { toast }
        }
        .sheet(isPresented: $showDatePicker) { datePicker }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(item: $movingTask) { task in
            MoveSheet(task: task, today: today) { move(task, to: $0) }
        }
        .task(id: lastMove?.id) {
            guard lastMove != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation { lastMove = nil }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
            updateToday()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                updateToday()
                calendar.refresh()
            }
        }
    }

    private func updateToday() {
        let now = DayKey.today()
        guard now != today else { return }
        if day == today { day = now }
        today = now
    }

    private func move(_ task: TaskItem, to newDay: String) {
        guard task.day != newDay else { return }
        withAnimation {
            lastMove = LastMove(task: task, title: task.title, from: task.day, to: newDay)
            task.day = newDay
        }
    }

    @ViewBuilder private var toast: some View {
        if let move = lastMove {
            HStack {
                Text("Moved “\(move.title)” to \(dayName(move.to))")
                    .lineLimit(2)
                Spacer()
                Button("Undo") {
                    withAnimation {
                        move.task.day = move.from
                        lastMove = nil
                    }
                }
                .bold()
            }
            .font(.subheadline)
            .foregroundStyle(Color(.systemBackground))
            .tint(Color(.systemBackground))
            .padding()
            .background(Color(.label).opacity(0.9), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// "Friday" within the coming week, "Mon, Nov 9" further out.
    private func dayName(_ key: String) -> String {
        let date = DayKey.date(for: key)
        let days = Calendar.current.dateComponents([.day], from: DayKey.date(for: today), to: date).day ?? 0
        return (0..<7).contains(days)
            ? date.formatted(.dateTime.weekday(.wide))
            : date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private var datePicker: some View {
        NavigationStack {
            DatePicker("Go to day", selection: Binding(
                get: { DayKey.date(for: day) },
                set: { day = DayKey.key(for: $0); showDatePicker = false }
            ), displayedComponents: .date)
            .datePickerStyle(.graphical)
            .padding(.horizontal)
            .navigationTitle("Go to day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Today") { day = today; showDatePicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showDatePicker = false }
                }
            }
            Spacer(minLength: 0)
        }
        .presentationDetents([.medium, .large])
    }
}

struct LastMove {
    let id = UUID()
    let task: TaskItem
    let title: String
    let from: String
    let to: String
}

/// The scrolling day: header, week strip, events, leftovers and tasks.
private struct DayList: View {
    @Binding var day: String
    let today: String
    let onMove: (TaskItem, String) -> Void
    let onPickMove: (TaskItem) -> Void
    let onPickDate: () -> Void
    let onSettings: () -> Void

    @Query private var tasks: [TaskItem]
    @Query private var openThisWeek: [TaskItem]
    @Query(sort: \TaskItem.createdAt) private var leftovers: [TaskItem]
    @AppStorage("leftoversHiddenOn") private var leftoversHiddenOn = ""

    init(day: Binding<String>, today: String,
         onMove: @escaping (TaskItem, String) -> Void,
         onPickMove: @escaping (TaskItem) -> Void,
         onPickDate: @escaping () -> Void,
         onSettings: @escaping () -> Void) {
        _day = day
        self.today = today
        self.onMove = onMove
        self.onPickMove = onPickMove
        self.onPickDate = onPickDate
        self.onSettings = onSettings

        let key = day.wrappedValue
        let week = DayKey.week(containing: key)
        let yesterday = DayKey.adding(-1, to: today)
        _tasks = Query(filter: #Predicate<TaskItem> { $0.day == key })
        _openThisWeek = Query(filter: #Predicate<TaskItem> { $0.isDone == false && week.contains($0.day) })
        _leftovers = Query(filter: #Predicate<TaskItem> { $0.day == yesterday && $0.isDone == false },
                           sort: \TaskItem.createdAt)
    }

    var body: some View {
        List {
            Section {
                DayHeader(day: $day, today: today, onPickDate: onPickDate, onSettings: onSettings)
                    .listRowInsets(EdgeInsets(top: 16, leading: 4, bottom: 4, trailing: 4))
                WeekStrip(day: $day, today: today, busyDays: Set(openThisWeek.map(\.day)))
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
            .listRowSeparator(.hidden)

            EventsSection(day: day, today: today)

            if day == today && !leftovers.isEmpty && leftoversHiddenOn != today {
                Section {
                    LeftoversBanner(tasks: leftovers, yesterday: DayKey.adding(-1, to: today)) {
                        withAnimation { leftovers.forEach { $0.day = today } }
                    } onDismiss: {
                        withAnimation { leftoversHiddenOn = today }
                    }
                }
                .listRowBackground(Color.accentColor.opacity(0.12))
            }

            TasksSection(day: day, today: today, tasks: TaskItem.ordered(tasks),
                         onMove: onMove, onPickMove: onPickMove)
        }
        .listStyle(.insetGrouped)
        .environment(\.defaultMinListRowHeight, 0)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollDismissesKeyboard(.interactively)
    }
}

private struct DayHeader: View {
    @Binding var day: String
    let today: String
    let onPickDate: () -> Void
    let onSettings: () -> Void

    var body: some View {
        let date = DayKey.date(for: day)
        let weekday = date.formatted(.dateTime.weekday(.wide))
        let sameYear = Calendar.current.isDate(date, equalTo: .now, toGranularity: .year)
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text((day == today ? "Today · \(weekday)" : weekday).uppercased())
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text(sameYear ? date.formatted(.dateTime.month(.wide).day())
                              : date.formatted(.dateTime.month(.wide).day().year()))
                    .font(.largeTitle.bold())
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer()
            HStack(spacing: 16) {
                if day != today {
                    Button("Today") { withAnimation { day = today } }
                        .font(.subheadline.weight(.semibold))
                }
                Button(action: onPickDate) {
                    Image(systemName: "calendar")
                }
                .accessibilityLabel("Go to day")
                Button(action: onSettings) {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Settings")
            }
            .font(.title3)
            .buttonStyle(.borderless)
            .padding(.bottom, 6)
        }
    }
}

private struct WeekStrip: View {
    @Binding var day: String
    let today: String
    let busyDays: Set<String>
    @ScaledMetric private var circle: CGFloat = 36

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DayKey.week(containing: day), id: \.self) { key in
                cell(key)
            }
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 20).onEnded { value in
            let dx = value.translation.width
            guard abs(dx) > 50, abs(dx) > abs(value.translation.height) else { return }
            withAnimation { day = DayKey.adding(dx < 0 ? 7 : -7, to: day) }
        })
    }

    private func cell(_ key: String) -> some View {
        let date = DayKey.date(for: key)
        let calendar = Calendar.current
        let letter = calendar.veryShortStandaloneWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
        let selected = key == day
        return Button {
            withAnimation { day = key }
        } label: {
            VStack(spacing: 4) {
                Text(letter)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(date.formatted(.dateTime.day()))
                    .font(.callout.weight(selected || key == today ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.white : key == today ? Color.accentColor : Color.primary)
                    .frame(width: circle, height: circle)
                    .background(Circle().fill(selected ? Color.accentColor : Color.clear))
                Circle()
                    .fill(busyDays.contains(key) ? Color.accentColor : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(busyDays.contains(key) ? "Has open tasks" : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct LeftoversBanner: View {
    let tasks: [TaskItem]
    let yesterday: String
    let onBring: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(tasks.count) unfinished from \(DayKey.date(for: yesterday).formatted(.dateTime.weekday(.wide)))")
                .font(.headline)
            Text(tasks.map(\.title).joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 12) {
                Button("Bring to today", action: onBring)
                    .buttonStyle(.borderedProminent)
                Button("Not now", action: onDismiss)
                    .buttonStyle(.borderless)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 6)
    }
}
