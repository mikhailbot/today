import SwiftData
import SwiftUI

struct TasksSection: View {
    let day: String
    let today: String
    let tasks: [TaskItem]
    let onMove: (TaskItem, String) -> Void
    let onPickMove: (TaskItem) -> Void

    @Environment(\.modelContext) private var context
    @State private var newTitle = ""
    @FocusState private var addFocused: Bool

    private let rowInsets = EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 16)
    private let liftInsets = EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
    /// Every row lifts as the same rounded shape when long-pressed, wherever it sits in the list.
    private let liftShape = RoundedRectangle(cornerRadius: 14, style: .continuous)
    private var openCount: Int { tasks.filter { !$0.isDone }.count }

    var body: some View {
        Section {
            ForEach(tasks) { task in
                TaskRow(task: task, isLastOpen: !task.isDone && openCount == 1 && day == today)
                    // The lifted preview is this row's own rounded shape, 12 pt in from both screen
                    // edges, so it lifts inside the page with room to grow. The row inside keeps its
                    // place: the check in line with the plus below, the title clear of the right margin.
                    .padding(EdgeInsets(top: 0, leading: -4, bottom: 0, trailing: 8))
                    .background(.paper)
                    .contentShape(.contextMenuPreview, liftShape)
                    .listRowInsets(liftInsets)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .contextMenu {
                        if !task.isDone {
                            Button("Tomorrow", systemImage: "arrow.right") {
                                onMove(task, DayKey.adding(1, to: today))
                            }
                            Button("Move…", systemImage: "calendar") { onPickMove(task) }
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            withAnimation { context.delete(task) }
                        }
                    }
            }
            addRow
                .listRowInsets(rowInsets)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        } header: {
            SectionHeading(title: "Tasks", detail: tasks.isEmpty ? nil : openCount == 0 ? "All done" : "\(openCount) left")
        }
    }

    private var addRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "plus")
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            TextField(placeholder, text: $newTitle)
                .focused($addFocused)
                .submitLabel(.done)
                .onSubmit(add)
        }
    }

    /// An empty list asks a question instead of showing a bare field.
    private var placeholder: String {
        guard tasks.isEmpty, day >= today else { return "Add a task" }
        if day == today { return "What needs doing today?" }
        return "Plan something for \(DayKey.date(for: day).formatted(.dateTime.weekday(.wide)))"
    }

    private func add() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        withAnimation { context.insert(TaskItem(title: title, day: day)) }
        newTitle = ""
        DispatchQueue.main.async { addFocused = true }
    }
}

private struct TaskRow: View {
    @Bindable var task: TaskItem
    /// Ticking this one finishes the day.
    var isLastOpen = false
    @Environment(\.modelContext) private var context
    @Environment(\.onAllDone) private var onAllDone
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The accent wash that sweeps over the row as it's ticked.
    @State private var wash = 0.0
    /// The row shows its new state at once and keeps its place for a beat before the list reorders,
    /// so the tick plays where you tapped.
    @State private var pendingDone: Bool?
    private var shownDone: Bool { pendingDone ?? task.isDone }
    @State private var draft = ""
    @State private var isEditing = false
    @FocusState private var focused: Bool
    @ScaledMetric private var checkSize: CGFloat = 22

    var body: some View {
        HStack(spacing: 4) {
            Button(action: tick) {
                CheckMark(isDone: shownDone, size: checkSize, springs: !reduceMotion)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .sensoryFeedback(trigger: shownDone) { _, done in done ? .success : .selection }
            .accessibilityLabel(shownDone ? "Mark not done: \(task.title)" : "Mark done: \(task.title)")

            if isEditing {
                TextField("Task", text: $draft)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(commit)
                    .onChange(of: focused) { _, isFocused in
                        if !isFocused { commit() }
                    }
                    .onAppear { DispatchQueue.main.async { focused = true } }
            } else {
                Text(task.title)
                    .modifier(DrawnStrike(isOn: shownDone, animated: !reduceMotion))
                    .foregroundStyle(shownDone ? .secondary : .primary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        draft = task.title
                        isEditing = true
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Edit title")
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.tint.opacity(0.2 * wash))
                .padding(.leading, 4)
        }
    }

    /// Ticks with the check springing and a wash of the accent; the row waits a beat before it drops
    /// to the done tasks, so the line can draw through it first.
    private func tick() {
        let finishing = !task.isDone
        if finishing && !reduceMotion {
            withAnimation(.easeOut(duration: 0.15)) { wash = 1 }
            Task {
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.easeOut(duration: 0.8)) { wash = 0 }
            }
        }
        // The done state shows on the row at once; the list reorders a moment later.
        withAnimation(.spring(duration: 0.35, bounce: 0.5)) { pendingDone = finishing }
        let last = finishing && isLastOpen
        Task {
            try? await Task.sleep(for: .seconds(reduceMotion ? 0 : 0.6))
            withAnimation(.snappy) {
                task.isDone = finishing
                pendingDone = nil
            }
            if last { onAllDone() }
        }
    }

    /// Saves the edited title; an empty title deletes the task.
    private func commit() {
        guard isEditing else { return }
        isEditing = false
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            withAnimation { context.delete(task) }
        } else {
            task.title = title
        }
    }
}

/// An open task is a ring in the icon's past grey; a done one fills with the tint, like the now dot.
private struct CheckMark: View {
    let isDone: Bool
    let size: CGFloat
    var springs = false

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isDone ? AnyShapeStyle(.clear) : AnyShapeStyle(Color(.tertiaryLabel)), lineWidth: 1.75)
            Circle()
                .fill(.tint)
                .opacity(isDone ? 1 : 0)
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(.onAccent)
                .opacity(isDone ? 1 : 0)
                .symbolEffect(.bounce, value: isDone)
        }
        .frame(width: size, height: size)
        // The check pops past full size and settles, with a ring rippling out.
        .keyframeAnimator(initialValue: 1.0, trigger: springs ? isDone : false) { view, scale in
            view.scaleEffect(scale)
        } keyframes: { _ in
            let pops = springs && isDone
            KeyframeTrack {
                CubicKeyframe(pops ? 0.7 : 1, duration: 0.08)
                SpringKeyframe(pops ? 1.25 : 1, duration: 0.18, spring: .bouncy)
                SpringKeyframe(1, duration: 0.3, spring: .bouncy(duration: 0.3, extraBounce: 0.2))
            }
        }
        .background {
            if springs {
                Circle()
                    .stroke(.tint, lineWidth: 2)
                    .keyframeAnimator(initialValue: Ripple(), trigger: isDone) { view, r in
                        view.scaleEffect(r.scale).opacity(r.opacity)
                    } keyframes: { _ in
                        KeyframeTrack(\.scale) {
                            LinearKeyframe(1, duration: 0.05)
                            CubicKeyframe(isDone ? 2.1 : 1, duration: 0.45)
                        }
                        KeyframeTrack(\.opacity) {
                            LinearKeyframe(isDone ? 0.8 : 0, duration: 0.05)
                            CubicKeyframe(0, duration: 0.45)
                        }
                    }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct Ripple {
    var scale = 1.0
    var opacity = 0.0
}

/// A line drawn across a task's title from the leading edge, like a pen through a diary line.
private struct DrawnStrike: ViewModifier {
    let isOn: Bool
    let animated: Bool
    @State private var drawn: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(.secondary)
                        .frame(width: geo.size.width * drawn, height: 1.5)
                        .frame(maxHeight: .infinity)
                }
                .allowsHitTesting(false)
            }
            .onAppear { drawn = isOn ? 1 : 0 }
            .onChange(of: isOn) { _, on in
                withAnimation(animated ? (on ? .easeOut(duration: 0.35) : .easeIn(duration: 0.2)) : nil) {
                    drawn = on ? 1 : 0
                }
            }
    }
}
