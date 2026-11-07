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
    /// The header folds to one line once the day scrolls.
    @State private var headerCollapsed = false
    @State private var celebrating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DayTop(day: $day, today: today, collapsed: headerCollapsed,
                       onPickDate: { showDatePicker = true },
                       onSettings: { showSettings = true })
                    // Above the pages, so nothing scrolling shows over the slab while it folds.
                    .zIndex(1)
                DayPager(day: $day, today: today, anchor: anchor,
                         onMove: move,
                         onPickMove: { movingTask = $0 },
                         onPickEvent: { shownEvent = ShownEvent(event: $0) },
                         onScrolled: { scrolled in
                             guard scrolled != headerCollapsed else { return }
                             withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0.15)) {
                                 headerCollapsed = scrolled
                             }
                         })
            }
            .onChange(of: day) { withAnimation(reduceMotion ? nil : .snappy) { headerCollapsed = false } }
            .environment(\.onAllDone, {
                withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0.3)) { celebrating = true }
            })
            .overlay {
                if celebrating {
                    AllDoneCelebration()
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(for: .seconds(2.6))
                            withAnimation(.easeIn(duration: 0.3)) { celebrating = false }
                        }
                        .onTapGesture { withAnimation { celebrating = false } }
                }
            }
            // The theme's ink for the page's text. Not set at the root: a foreground style overrides the tint,
            // which would take it off buttons and icons in sheets.
            .foregroundStyle(.ink, .secondaryInk, .tertiaryInk)
            .background(.paper)
            // The slab is a deep colour in every theme, so the status bar reads light on it.
            .background { LightStatusBar().frame(width: 0, height: 0) }
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
            .foregroundStyle(.paper)
            .tint(ThemeColor.paper)
            .padding()
            .background(.ink.opacity(0.9), in: RoundedRectangle(cornerRadius: 14))
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
        .themedSheet()
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

/// The header and week strip on the theme's slab, pinned above the day pages.
private struct DayTop: View {
    @Binding var day: String
    let today: String
    let collapsed: Bool
    let onPickDate: () -> Void
    let onSettings: () -> Void

    @Environment(CalendarStore.self) private var calendar
    @Environment(\.theme) private var theme
    @AppStorage(HiddenCalendars.storageKey) private var hiddenRaw = ""
    /// Tasks in the shown week and the weeks either side, for the week strip's load bars.
    @Query private var nearby: [TaskItem]
    /// Hours of timed events per day around the shown week, for the load bars.
    @State private var eventHours: [String: Double] = [:]

    init(day: Binding<String>, today: String, collapsed: Bool,
         onPickDate: @escaping () -> Void, onSettings: @escaping () -> Void) {
        _day = day
        self.today = today
        self.collapsed = collapsed
        self.onPickDate = onPickDate
        self.onSettings = onSettings
        let days = Self.days(around: day.wrappedValue)
        _nearby = Query(filter: #Predicate<TaskItem> { days.contains($0.day) })
    }

    static func days(around day: String) -> [String] {
        [-7, 0, 7].flatMap { DayKey.week(containing: DayKey.adding($0, to: day)) }
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(alignment: .leading, spacing: collapsed ? 10 : 16) {
                DayHeader(day: day, today: today, now: context.date, collapsed: collapsed,
                          onPickDate: onPickDate, onSettings: onSettings)
                WeekStrip(day: $day, today: today, load: load)
                    // Seven days have to fit across the screen; past this size they'd push the whole day
                    // view wider than the screen. Long-pressing a day shows it enlarged instead.
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
        }
        .foregroundStyle(theme.onSlab)
        .padding(.horizontal, 20)
        .padding(.top, collapsed ? 2 : 10)
        .padding(.bottom, 14)
        // Fills this view's own frame and runs up under the status bar, so it follows the header
        // frame for frame as it folds.
        .background {
            UnevenRoundedRectangle(bottomLeadingRadius: 30, bottomTrailingRadius: 30, style: .continuous)
                .fill(theme.slab.gradient)
                .ignoresSafeArea(edges: .top)
        }
        .padding(.bottom, 6)
        .task(id: "\(DayKey.week(containing: day)[0])|\(hiddenRaw)|\(calendar.revision)") {
            let hidden = HiddenCalendars.decode(hiddenRaw)
            var hours: [String: Double] = [:]
            for key in Self.days(around: day) {
                let start = DayKey.date(for: key), end = start.addingTimeInterval(86_400)
                hours[key] = calendar.events(on: key, hidden: hidden).filter { !$0.isAllDay }.reduce(0) {
                    $0 + min($1.endDate, end).timeIntervalSince(max($1.startDate, start)) / 3600
                }
            }
            eventHours = hours
        }
    }

    private var load: [String: WeekStrip.Load] {
        var load: [String: WeekStrip.Load] = [:]
        for task in nearby {
            load[task.day, default: .init()].open += task.isDone ? 0 : 1
            load[task.day, default: .init()].done += task.isDone ? 1 : 0
        }
        for (key, hours) in eventHours { load[key, default: .init()].eventHours = hours }
        return load
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
    let onScrolled: (Bool) -> Void

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
                    let key = DayKey.adding(n, to: anchor)
                    DayPage(day: key, today: today,
                            onMove: onMove, onPickMove: onPickMove, onPickEvent: onPickEvent)
                        .onScrolledDown { if key == day { onScrolled($0) } }
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
                .listRowBackground(Color.clear)

            if day == today && !leftovers.isEmpty && leftoversHiddenOn != today {
                Section {
                    LeftoversBanner(tasks: leftovers, yesterday: DayKey.adding(-1, to: today)) {
                        withAnimation { leftovers.forEach { $0.day = today } }
                    } onDismiss: {
                        withAnimation { leftoversHiddenOn = today }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            TasksSection(day: day, today: today, tasks: TaskItem.ordered(tasks),
                         onMove: onMove, onPickMove: onPickMove)
        }
        // Grouped, not inset grouped: rows sit on the page with no card, and an inset-grouped section
        // rounds the top of its first cell, which showed through as larger corners on a lifting row.
        .listStyle(.grouped)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        // Rows sit straight on the page, so their text lines up with the header's 20 pt margin.
        .contentMargins(.horizontal, 4, for: .scrollContent)
        .contentMargins(.top, 4, for: .scrollContent)
        .scrollDismissesKeyboard(.interactively)
    }
}

/// The day as you'd say it: "Friday morning", "Tomorrow", "Wednesday", "Monday · 2027".
/// The year rides on this line so the date below stays short enough for one line.
func spokenDay(_ day: String, today: String, now: Date) -> String {
    let date = DayKey.date(for: day)
    let weekday = date.formatted(.dateTime.weekday(.wide))
    switch DayKey.days(from: today, to: day) {
    case 0: return "\(weekday) \(DayPart(now).rawValue)"
    case 1: return "Tomorrow"
    case -1: return "Yesterday"
    default:
        let sameYear = Calendar.current.isDate(date, equalTo: now, toGranularity: .year)
        return sameYear ? weekday : "\(weekday) · \(date.formatted(.dateTime.year()))"
    }
}

/// The week on the slab. The selected day is a tall pill around its letter and number that glides
/// from day to day; under each day, two of the mark's bars show how full it is.
private struct WeekStrip: View {
    @Binding var day: String
    let today: String
    let load: [String: Load]

    struct Load {
        var eventHours = 0.0
        var open = 0
        var done = 0
    }

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selection
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
            ForEach(keys, id: \.self) { cell($0, selected: $0 == picked, glides: weeks == 0) }
        }
        // The selection glides from day to day within the week.
        .animation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.22), value: day)
    }

    private func cell(_ key: String, selected: Bool, glides: Bool) -> some View {
        let date = DayKey.date(for: key)
        let calendar = Calendar.current
        let letter = calendar.veryShortStandaloneWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
        let dayLoad = load[key] ?? Load()
        // On the pill, the slab's colour; elsewhere, the text colour for the slab.
        let ink = selected ? theme.slab : theme.onSlab
        return Button {
            day = key
        } label: {
            VStack(spacing: 4) {
                Text(letter)
                    .font(.mark)
                    .foregroundStyle(selected ? ink : ink.opacity(0.8))
                Text(date.formatted(.dateTime.day()))
                    .font(.dayNumber.weight(selected || key == today ? .semibold : .regular))
                    .foregroundStyle(selected || key >= today ? ink : ink.opacity(0.8))
                    .frame(width: circle, height: circle * 0.8)
                    // Today keeps a ring while another day is selected.
                    .background {
                        if key == today && !selected {
                            Capsule().strokeBorder(ink.opacity(0.6), lineWidth: 1.5)
                        }
                    }
                loadBars(dayLoad, ink: ink)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.onSlab)
                        .padding(.horizontal, 3)
                        .matchedSelection(glides, in: selection)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(accessibilityValue(dayLoad))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityShowsLargeContentViewer {
            Text(date.formatted(.dateTime.weekday(.abbreviated).day()))
        }
    }

    /// The day's load as two of the mark's bars: hours booked on top (six hours fills it), tasks below
    /// (five fills it). The task bar stays bright while any are open, so leftovers still show, and
    /// dims once they're all done.
    private func loadBars(_ load: Load, ink: Color) -> some View {
        let full: CGFloat = 26
        let events = load.eventHours > 0 ? max(5, full * min(load.eventHours / 6, 1)) : 0
        let tasks = load.open + load.done > 0 ? max(5, full * min(Double(load.open + load.done) / 5, 1)) : 0
        return VStack(alignment: .leading, spacing: 3) {
            Capsule().fill(ink.opacity(0.55)).frame(width: events, height: 4)
            Capsule().fill(load.open > 0 ? ink : ink.opacity(0.35)).frame(width: tasks, height: 4)
        }
        .frame(width: full, height: 11, alignment: .leading)
        .animation(reduceMotion ? nil : .snappy, value: tasks)
        .accessibilityHidden(true)
    }

    private func accessibilityValue(_ load: Load) -> String {
        var parts: [String] = []
        if load.eventHours > 0 { parts.append(EventsSection.spokenDuration(minutes: Int(load.eventHours * 60)) + " of events") }
        if load.open > 0 { parts.append(load.open == 1 ? "1 open task" : "\(load.open) open tasks") }
        return parts.joined(separator: ", ")
    }
}

private struct LeftoversBanner: View {
    let tasks: [TaskItem]
    let yesterday: String
    let onBring: () -> Void
    let onDismiss: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // A quiet prompt: the icon's grey past bar on the left ties it to yesterday.
        HStack(alignment: .top, spacing: 12) {
            Capsule()
                .fill(.past)
                .frame(width: 4)
                .accessibilityHidden(true)
            prompt
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var prompt: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(tasks.count) unfinished from \(DayKey.date(for: yesterday).formatted(.dateTime.weekday(.wide)))")
                .font(.headline)
            Text(tasks.map(\.title).joined(separator: ", "))
                .font(.detail)
                .foregroundStyle(.secondary)
                .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
            // Side by side, or stacked when large text won't fit them on one line.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { buttons }
                VStack(alignment: .leading, spacing: 8) { buttons }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder private var buttons: some View {
        Button(action: onBring) {
            Text("Bring to today")
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.bordered)
        .foregroundStyle(.tint)
        Button("Not now", action: onDismiss)
            .buttonStyle(.borderless)
            .foregroundStyle(.tint)
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

extension View {
    /// Reports whether the scroll view inside has scrolled down from the top. iOS 18 and later.
    @ViewBuilder func onScrolledDown(_ action: @escaping (Bool) -> Void) -> some View {
        if #available(iOS 18, *) {
            onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > 24 } action: { _, down in
                action(down)
            }
        } else {
            self
        }
    }
}

extension View {
    /// Glides between days when on; a neighbouring week's preview keeps its own place.
    @ViewBuilder fileprivate func matchedSelection(_ on: Bool, in namespace: Namespace.ID) -> some View {
        if on { matchedGeometryEffect(id: "selected", in: namespace) } else { self }
    }
}
