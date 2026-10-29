import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID = UUID()
    var title: String = ""
    var day: String = ""        // "2026-10-29", in the user's calendar
    var isDone: Bool = false
    var createdAt: Date = Date()

    init(title: String, day: String, createdAt: Date = Date()) {
        self.title = title
        self.day = day
        self.createdAt = createdAt
    }

    /// Open tasks first, then done ones, each by creation time.
    static func ordered(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted { a, b in
            a.isDone != b.isDone ? !a.isDone : a.createdAt < b.createdAt
        }
    }
}
