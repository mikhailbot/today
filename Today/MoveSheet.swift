import SwiftUI

struct MoveSheet: View {
    let task: TaskItem
    let today: String
    let onMove: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var picked: Date

    init(task: TaskItem, today: String, onMove: @escaping (String) -> Void) {
        self.task = task
        self.today = today
        self.onMove = onMove
        _picked = State(initialValue: DayKey.date(for: task.day))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    option("Tomorrow", DayKey.adding(1, to: today))
                    option("Next week", DayKey.nextMonday(after: today))
                } header: {
                    Text(task.title)
                        .textCase(nil)
                        .lineLimit(2)
                }
                Section {
                    DatePicker("Day", selection: $picked, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
            }
            .navigationTitle("Move to…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: picked) { _, date in choose(DayKey.key(for: date)) }
        }
        .presentationDetents([.medium, .large])
    }

    private func option(_ name: String, _ day: String) -> some View {
        Button { choose(day) } label: {
            HStack {
                Text(name)
                    .foregroundStyle(.primary)
                Spacer()
                Text(DayKey.date(for: day).formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func choose(_ day: String) {
        onMove(day)
        dismiss()
    }
}
