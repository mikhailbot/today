import Combine
import EventKit
import SwiftData
import SwiftUI

struct DayView: View {
    @Environment(CalendarStore.self) private var calendar
    @Environment(\.scenePhase) private var scenePhase
    @State private var today = DayKey.today()
    @State private var day = DayKey.today()
    /// Today at launch; the pager's pages are counted from here.
    @State private var anchor = DayKey.today()
    @State private var showDatePicker = false
    @State private var showSettings = false
    @State private var movingTask: TaskItem?
    @State private var shownEvent: ShownEvent?
    @State private var lastMove: LastMove?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DayTop(day: $day, today: today,
                       onPickDate: { showDatePicker = true },
                       onSettings: { showSettings = true })
                DayPager(day: $day, today: today, anchor: anchor,
                         onMove: move,
                         onPickMove: { movingTask = $0 },
                         onPickEvent: { shownEvent = ShownEvent(event: $0) })
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                VStack {
                    if lastMove != nil {
                        toast
                    } else if day != today {
                        todayPill
                    }
                }
                .animation(.snappy, value: day == today)
            }
        }
        .sheet(isPresented: $showDatePicker) { datePicker }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(item: $movingTask) { task in
            MoveSheet(task: task, today: today, days: DayPager.days(around: anchor)) { move(task, to: $0) }
        }
        .sheet(item: $shownEvent) { EventDetailView(event: $0.event).ignoresSafeArea() }
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
            .font(.detail)
            .foregroundStyle(Color(.systemBackground))
            .tint(Color(.systemBackground))
            .padding()
            .background(Color(.label).opacity(0.9), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// Floats at the bottom while away from today, pointing the way back.
    private var todayPill: some View {
        Button {
            day = today
        } label: {
            HStack(spacing: 5) {
                if day > today { Image(systemName: "chevron.left").imageScale(.small) }
                Text("Today")
                if day < today { Image(systemName: "chevron.right").imageScale(.small) }
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(.tint)
            .padding(.horizontal, 4)
        }
        .glassButton()
        .buttonBorderShape(.capsule)
        .padding(.bottom, 8)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
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
            ), in: DayPager.days(around: anchor), displayedComponents: .date)
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

/// The header and week strip, pinned above the day pages.
private struct DayTop: View {
    @Binding var day: String
    let today: String
    let onPickDate: () -> Void
    let onSettings: () -> Void

    @Query private var openThisWeek: [TaskItem]

    init(day: Binding<String>, today: String, onPickDate: @escaping () -> Void, onSettings: @escaping () -> Void) {
        _day = day
        self.today = today
        self.onPickDate = onPickDate
        self.onSettings = onSettings
        let week = DayKey.week(containing: day.wrappedValue)
        _openThisWeek = Query(filter: #Predicate<TaskItem> { $0.isDone == false && week.contains($0.day) })
    }

    var body: some View {
        VStack(spacing: 8) {
            DayHeader(day: day, today: today, onPickDate: onPickDate, onSettings: onSettings)
            WeekStrip(day: $day, today: today, busyDays: Set(openThisWeek.map(\.day)))
                // Seven days have to fit across the screen; past this size they'd push the whole day
                // view wider than the screen. Long-pressing a day shows it enlarged instead.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }
}

/// Day pages side by side; swiping pages one day at a time, like Calendar.
private struct DayPager: View {
    @Binding var day: String
    let today: String
    /// Pages are days counted from here, so their ids stay put as `day` moves.
    let anchor: String
    let onMove: (TaskItem, String) -> Void
    let onPickMove: (TaskItem) -> Void
    let onPickEvent: (EKEvent) -> Void

    @State private var page: Int?

    static let pages = -3650...3650

    /// The days the pager has pages for, for limiting date pickers.
    static func days(around anchor: String) -> ClosedRange<Date> {
        DayKey.date(for: DayKey.adding(pages.lowerBound, to: anchor))...DayKey.date(for: DayKey.adding(pages.upperBound, to: anchor))
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Self.pages, id: \.self) { n in
                    DayPage(day: DayKey.adding(n, to: anchor), today: today,
                            onMove: onMove, onPickMove: onPickMove, onPickEvent: onPickEvent)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $page)
        .onAppear { page = DayKey.days(from: anchor, to: day) }
        .onChange(of: page) { _, page in
            guard let page else { return }
            let key = DayKey.adding(page, to: anchor)
            if key != day { day = key }
        }
        .onChange(of: day) { _, day in
            let target = DayKey.days(from: anchor, to: day)
            guard let page, target != page else { return }
            // Slide to nearby days; jump straight to far ones.
            if abs(target - page) < 7 {
                withAnimation(WeekStrip.slide) { self.page = target }
            } else {
                self.page = target
            }
        }
    }
}

/// One day's events, leftovers and tasks.
private struct DayPage: View {
    let day: String
    let today: String
    let onMove: (TaskItem, String) -> Void
    let onPickMove: (TaskItem) -> Void
    let onPickEvent: (EKEvent) -> Void

    @Query private var tasks: [TaskItem]
    @Query(sort: \TaskItem.createdAt) private var leftovers: [TaskItem]
    @AppStorage("leftoversHiddenOn") private var leftoversHiddenOn = ""

    init(day: String, today: String,
         onMove: @escaping (TaskItem, String) -> Void,
         onPickMove: @escaping (TaskItem) -> Void,
         onPickEvent: @escaping (EKEvent) -> Void) {
        self.day = day
        self.today = today
        self.onMove = onMove
        self.onPickMove = onPickMove
        self.onPickEvent = onPickEvent

        let yesterday = DayKey.adding(-1, to: today)
        _tasks = Query(filter: #Predicate<TaskItem> { $0.day == day })
        _leftovers = Query(filter: #Predicate<TaskItem> { $0.day == yesterday && $0.isDone == false },
                           sort: \TaskItem.createdAt)
    }

    var body: some View {
        List {
            EventsSection(day: day, today: today, onPickEvent: onPickEvent)

            if day == today && !leftovers.isEmpty && leftoversHiddenOn != today {
                Section {
                    LeftoversBanner(tasks: leftovers, yesterday: DayKey.adding(-1, to: today)) {
                        withAnimation { leftovers.forEach { $0.day = today } }
                    } onDismiss: {
                        withAnimation { leftoversHiddenOn = today }
                    }
                }
                .listRowBackground(Rectangle().fill(.tint.opacity(0.12)))
            }

            TasksSection(day: day, today: today, tasks: TaskItem.ordered(tasks),
                         onMove: onMove, onPickMove: onPickMove)
        }
        .listStyle(.insetGrouped)
        .environment(\.defaultMinListRowHeight, 0)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .contentMargins(.top, 0, for: .scrollContent)
        .scrollDismissesKeyboard(.interactively)
    }
}

/// The date, which opens the day picker, and settings. Jumping back to today is the floating pill.
private struct DayHeader: View {
    let day: String
    let today: String
    let onPickDate: () -> Void
    let onSettings: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var titleCapHeight = UIFont.preferredFont(
        forTextStyle: .largeTitle, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)).capHeight

    var body: some View {
        let date = DayKey.date(for: day)
        let weekday = date.formatted(.dateTime.weekday(.wide))
        let sameYear = Calendar.current.isDate(date, equalTo: .now, toGranularity: .year)
        // The year rides on the weekday line so the date stays short enough for one line.
        let eyebrow = day == today ? "Today · \(weekday)"
            : sameYear ? weekday : "\(weekday) · \(date.formatted(.dateTime.year()))"
        VStack(alignment: .leading, spacing: 0) {
            Text(eyebrow)
                .eyebrow()
                .foregroundStyle(.tint)
            HStack {
                Button(action: onPickDate) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(date.formatted(.dateTime.month(.wide).day()))
                            .font(.dayTitle)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Image(systemName: "chevron.down")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.tint)
                            // Centre on the date's capitals rather than sitting on its baseline.
                            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + titleCapHeight / 2 }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(eyebrow), \(date.formatted(.dateTime.month(.wide).day()))")
                .accessibilityAddTraits(.isHeader)
                .accessibilityHint("Choose a day")
                Spacer(minLength: 12)
                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.body.weight(.medium))
                        .frame(width: 22, height: 22)
                }
                .glassButton()
                .tint(.primary)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Settings")
            }
        }
    }
}

private struct WeekStrip: View {
    @Binding var day: String
    let today: String
    let busyDays: Set<String>
    @ScaledMetric private var circle: CGFloat = 36
    @State private var width: CGFloat = 0
    /// How far the weeks are pulled sideways; the previous and next weeks sit just off screen.
    @State private var offset: CGFloat = 0
    /// The day the strip is drawn around; lags `day` while a week slides in.
    @State private var shownDay: String?

    /// Unhurried and without overshoot, like Calendar.
    static let slide = Animation.spring(duration: 0.5, bounce: 0)

    var body: some View {
        page(0)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .overlay { page(-1).offset(x: -width) }
            .overlay { page(1).offset(x: width) }
            .offset(x: offset)
            .clipped()
            .contentShape(Rectangle())
            .highPriorityGesture(DragGesture(minimumDistance: 20)
                .onChanged { value in
                    if abs(value.translation.width) > abs(value.translation.height) {
                        offset = value.translation.width
                    }
                }
                .onEnded { value in
                    let dx = value.predictedEndTranslation.width
                    guard abs(dx) > width / 2, abs(value.translation.width) > abs(value.translation.height) else {
                        withAnimation(Self.slide) { offset = 0 }
                        return
                    }
                    let step = dx < 0 ? 1 : -1
                    slide(step) { day = DayKey.adding(step * 7, to: day) }
                })
            .onChange(of: day) { _, new in
                let shown = shownDay ?? new
                let from = DayKey.week(containing: shown)[0]
                let to = DayKey.week(containing: new)[0]
                guard offset == 0, from != to else {
                    if offset == 0 { shownDay = new }
                    return
                }
                // Paged into the next or previous week: slide it in. Further jumps just switch.
                let step = to > from ? 1 : -1
                if DayKey.adding(step * 7, to: from) == to {
                    slide(step) {}
                } else {
                    shownDay = new
                }
            }
    }

    /// Slides the neighbouring week in, then redraws around it with nothing moving.
    private func slide(_ step: Int, then: @escaping () -> Void) {
        withAnimation(Self.slide, completionCriteria: .removed) {
            offset = CGFloat(-step) * width
        } completion: {
            then()
            shownDay = day
            offset = 0
        }
    }

    /// The week `weeks` away from the shown one. A week holding `day` selects it; a neighbour
    /// otherwise previews the same weekday.
    private func page(_ weeks: Int) -> some View {
        let start = DayKey.adding(weeks * 7, to: shownDay ?? day)
        let keys = DayKey.week(containing: start)
        let picked = keys.contains(day) ? day : weeks == 0 ? nil : start
        return HStack(spacing: 0) {
            ForEach(keys, id: \.self) { cell($0, selected: $0 == picked) }
        }
    }

    private func cell(_ key: String, selected: Bool) -> some View {
        let date = DayKey.date(for: key)
        let calendar = Calendar.current
        let letter = calendar.veryShortStandaloneWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
        return Button {
            day = key
        } label: {
            VStack(spacing: 4) {
                Text(letter)
                    .font(.mark)
                    .foregroundStyle(.secondary)
                Text(date.formatted(.dateTime.day()))
                    .font(.dayNumber.weight(selected || key == today ? .semibold : .regular))
                    .foregroundStyle(selected ? AnyShapeStyle(.white) : key == today ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                    .frame(width: circle, height: circle)
                    .background(Circle().fill(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear)))
                Circle()
                    .fill(busyDays.contains(key) ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear))
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(busyDays.contains(key) ? "Has open tasks" : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityShowsLargeContentViewer {
            Text(date.formatted(.dateTime.weekday(.abbreviated).day()))
        }
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
                .font(.detail)
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

extension View {
    /// Liquid Glass where available, a bordered button before it.
    @ViewBuilder func glassButton() -> some View {
        if #available(iOS 26, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }
}
