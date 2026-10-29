import SwiftUI

struct WelcomeView: View {
    @Environment(CalendarStore.self) private var calendar
    @AppStorage("skippedCalendarAccess") private var skippedCalendarAccess = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            AppMark(size: 96)
            VStack(spacing: 12) {
                Text("Your day, in one place")
                    .font(.largeTitle.bold())
                Text("Today shows events from the calendars already on this iPhone (iCloud, Google, Exchange) next to a short list of things to do.")
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            Label("Events are only read, never changed or copied. Tasks stay in your iCloud.", systemImage: "lock")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            Spacer()
            VStack(spacing: 12) {
                Button {
                    Task { await calendar.requestAccess() }
                } label: {
                    Text("Allow calendar access").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Button("Just tasks for now") { skippedCalendarAccess = true }
                    .controlSize(.large)
            }
        }
        .padding(24)
        .background(Color(.systemGroupedBackground))
    }
}

/// The app icon's now-line mark on an icon-shaped tile.
struct AppMark: View {
    let size: CGFloat

    var body: some View {
        let tile = RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
        Image("LaunchMark")
            .resizable()
            .scaledToFit()
            .padding(size * 0.175)
            .frame(width: size, height: size)
            .background(Color(.systemBackground), in: tile)
            .overlay(tile.stroke(Color(.separator), lineWidth: 0.5))
            .accessibilityHidden(true)
    }
}
