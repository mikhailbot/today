# Today

A small iOS app that shows one day: the events from the calendars already on the phone, and a short list of one-off tasks for that day.

Mockups: https://claude.ai/artifact/NfGdgfthtg9pugdXn53brr

## Scope

What it does:

- Shows the events for the selected day (today when the app opens), read from the calendars set up on the device.
- Lets you add, edit and delete events through Apple's own event screens.
- Lets you add a task to any day, tick it off, fix its title, delete it, and move an unfinished task to another day.
- Syncs tasks across your own devices through iCloud.

What it doesn't do (YAGNI): due times, reminders or notifications, recurrence, priorities, tags, projects, subtasks, notes, a custom event editor, accounts, or any server.

## Screens

| Screen | Purpose |
| --- | --- |
| Day view | Date header with a week strip, then calendar events, then tasks with an inline "Add a task" field. Tap an event for Apple's event detail sheet; the floating calendar button in the corner adds an event on that day. Tap a task's title to edit it. |
| Move to… | Long-press a task for **Tomorrow** (one tap) or **Move…**, which opens a sheet with Tomorrow, Next week and a month picker, and **Delete**. Done tasks only offer Delete. |
| Leftovers prompt | When yesterday still has open tasks, a banner on today offers **Bring to today** (moves them all) or **Not now** (hides the banner until tomorrow). Nothing moves without asking. |
| Settings | Turn individual calendars on or off. Shows iCloud sync status. |
| First run | Asks for calendar access. "Just tasks for now" skips it. |

## Decisions

- **Layout A (stacked)** for the day view: an events card above a tasks card, in the iOS inset-grouped style. The tasks-first (B) and timeline (C) layouts on the canvas were considered and dropped.
- **Finished tasks stay on their day**, crossed out, and drop to the bottom of the list. Unticking one puts it back with the open tasks.
- **Unfinished tasks from yesterday get a prompt to move forward** (the leftovers banner). Older unfinished tasks stay on their day; the week strip's dots still show them. Nothing moves automatically.
- **Tasks can be added to any day** you're viewing, past or future.
- **Tasks can be edited and deleted**: tap the title to edit it in place, long-press for Delete. Task rows have no swipe actions, so a horizontal swipe anywhere on the day always changes the day.
- **Finished tasks are kept forever**, so browsing back shows what got done. No cleanup logic.
- **Events are edited with Apple's screens.** Tapping an event opens Apple's event detail sheet, with its Edit and Delete for events you can change; the floating calendar button opens Apple's event editor, starting at the next hour today or 9:00 on other days, in the default calendar. Apple's detail sheet always shows Delete (`allowsEditing` only hides Edit), so a read-only sheet wasn't possible.
- **Declined invitations are hidden.** All-day events show as a slim row at the top of the events card.
- **iPhone only.** iCloud sync still covers a second iPhone or a reinstall.
- **No quick add from outside the app** in v1 (no Siri, Shortcuts or Control Center).

## Tech

All built-in frameworks, iOS 17+, iPhone only (`TARGETED_DEVICE_FAMILY = 1`).

- **SwiftUI**, one `NavigationStack`, no tab bar.
- **EventKit** for reading events. Only Apple's EventKitUI screens write them.
  - `EKEventStore.requestFullAccessToEvents()` with `NSCalendarsFullAccessUsageDescription` in Info.plist. Write-only access can't read events.
  - `events(matching: predicateForEvents(withStart:end:calendars:))` for the visible day, filtered to the calendars the user has turned on.
  - Skip events where the current user's attendee entry (`isCurrentUser`) has `participantStatus == .declined`.
  - Event detail: `EKEventViewController` with `allowsEditing = true`, wrapped in a `UIViewControllerRepresentable` and shown as a sheet.
  - New event: `EKEventEditViewController` with an unsaved `EKEvent` on the viewed day, also wrapped and shown as a sheet. It saves to the store itself.
  - Listen for `.EKEventStoreChanged` and refetch.
  - Store the IDs of hidden calendars (`calendarIdentifier`) in `@AppStorage`. Events themselves are never stored.
- **SwiftData + CloudKit** (private database) for tasks.
  - Turn on the iCloud capability with a CloudKit container, plus Background Modes → Remote notifications.
  - CloudKit-backed models need every property optional or defaulted, and no `@Attribute(.unique)`.
  - **Turning on iCloud sync.** v1 builds store tasks on the device only, so the app signs with a free Personal Team. Sync needs a paid Apple Developer Program membership. Then, in Signing & Capabilities, add iCloud (CloudKit, with your container) and Background Modes → Remote notifications (`Today/Today-iCloud.entitlements.disabled` has the matching entitlements), and add `ICLOUD_SYNC` to Active Compilation Conditions. Tasks created before sync is turned on are not lost: the sync build opens the same on-device store and uploads the tasks already in it. That only holds while the bundle ID stays the same; a new bundle ID is a new app with an empty store.

### Data model

```swift
@Model
final class TaskItem {
    var id: UUID = UUID()
    var title: String = ""
    var day: String = ""        // "2026-10-29", in the user's calendar
    var isDone: Bool = false
    var createdAt: Date = Date()
}
```

- `day` is a plain date key, not a `Date`, so a task doesn't drift to another day when the device changes time zone.
- Moving a task just sets `day`.
- Sort order: open tasks first, then done tasks (crossed out), each by `createdAt`. No manual reordering in v1.
- Leftovers are `day == yesterday && !isDone`. **Bring to today** sets their `day` to today. **Not now** saves today's date in `@AppStorage` so the banner stays hidden until tomorrow.

## Later, maybe

- A small WidgetKit widget showing the next event and the number of open tasks.
- An "Add to Today" App Intent for Siri, Shortcuts and the Action button.
