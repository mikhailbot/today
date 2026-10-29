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
    private var openCount: Int { tasks.filter { !$0.isDone }.count }

    var body: some View {
        Section {
            ForEach(tasks) { task in
                TaskRow(task: task)
                    .listRowInsets(rowInsets)
                    .swipeActions(edge: .trailing) {
                        if !task.isDone {
                            Button("Tomorrow") { onMove(task, DayKey.adding(1, to: today)) }
                                .tint(.accentColor)
                            Button("Move…") { onPickMove(task) }
                                .tint(.gray)
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button("Delete", role: .destructive) {
                            withAnimation { context.delete(task) }
                        }
                    }
            }
            addRow
                .listRowInsets(rowInsets)
        } header: {
            HStack {
                Text("TASKS")
                Spacer()
                if !tasks.isEmpty {
                    Text(openCount == 0 ? "All done" : "\(openCount) left")
                }
            }
            .textCase(nil)
        }
    }

    private var addRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "plus")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            TextField("Add a task", text: $newTitle)
                .focused($addFocused)
                .submitLabel(.done)
                .onSubmit(add)
        }
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
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: checkSize))
                    .foregroundStyle(task.isDone ? Color.accentColor : Color.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
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
                    .strikethrough(task.isDone)
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
