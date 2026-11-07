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
                TaskRow(task: task)
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
    @Environment(\.modelContext) private var context
    @State private var draft = ""
    @State private var isEditing = false
    @FocusState private var focused: Bool
    @ScaledMetric private var checkSize: CGFloat = 22

    var body: some View {
        HStack(spacing: 4) {
            Button {
                withAnimation { task.isDone.toggle() }
            } label: {
                CheckMark(isDone: task.isDone, size: checkSize)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .sensoryFeedback(trigger: task.isDone) { _, done in done ? .success : .selection }
            .accessibilityLabel(task.isDone ? "Mark not done: \(task.title)" : "Mark done: \(task.title)")

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
                    .strikethrough(task.isDone, color: .secondary)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
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
        .accessibilityHidden(true)
    }
}
