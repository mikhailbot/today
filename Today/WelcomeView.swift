import SwiftUI

struct WelcomeView: View {
    @Environment(CalendarStore.self) private var calendar
    @AppStorage("skippedCalendarAccess") private var skippedCalendarAccess = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AppMark(size: 72, animated: true)
                    .padding(.bottom, 8)
                Text("Your day, in one place")
                    .font(.largeTitle.bold())
                Text("Today shows events from the calendars already on this iPhone (iCloud, Google, Exchange) next to a short list of things to do.")
                    .foregroundStyle(.secondary)
                Group {
                    #if ICLOUD_SYNC
                    Label("Events are only read. Tasks stay in your iCloud.", systemImage: "lock")
                    #else
                    Label("Events are only read. Tasks stay on this iPhone.", systemImage: "lock")
                    #endif
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 72)
        }
        .scrollBounceBehavior(.basedOnSize)
        // The choice stays in reach at the bottom, however large the text.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button {
                    Task { await calendar.requestAccess() }
                } label: {
                    Text("Allow calendar access")
                        .frame(maxWidth: .infinity)
                        // White on the light dark-mode tint is too faint; the page colour reads on both.
                        .foregroundStyle(Color(.systemBackground))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Button("Just tasks for now") { skippedCalendarAccess = true }
                    .controlSize(.large)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
    }
}
