import Foundation
import Testing
@testable import Today

struct TimeLeftTests {
    private func text(minutes: Double) -> String {
        EventsSection.timeLeft(minutes * 60).text
    }

    @Test func readsMinutesUnderAnHourThenHoursAndMinutes() {
        #expect(text(minutes: 45) == "45 min left")
        #expect(text(minutes: 59) == "59 min left")
        #expect(text(minutes: 60) == "1h left")
        #expect(text(minutes: 61) == "1h 1m left")
        #expect(text(minutes: 136) == "2h 16m left")
        #expect(text(minutes: 180) == "3h left")
    }

    @Test func countsAStartedMinuteAsAWholeOne() {
        #expect(text(minutes: 0.25) == "1 min left")
        #expect(text(minutes: 58.5) == "59 min left")
        #expect(text(minutes: 59.5) == "1h left")
        #expect(text(minutes: 60.01) == "1h 1m left")
    }

    @Test func durationLabelsReadTheSameWay() {
        #expect(EventsSection.shortDuration(minutes: 45) == "45m")
        #expect(EventsSection.shortDuration(minutes: 120) == "2h")
        #expect(EventsSection.shortDuration(minutes: 90) == "1h 30m")
    }
}
