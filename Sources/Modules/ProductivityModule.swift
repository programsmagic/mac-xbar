import Foundation
import AppKit

public final class ProductivityModule: Module {
    public let id: ModuleID = "productivity"
    public var name: String = "Productivity"
    public var config: ModuleConfig = ModuleConfig(
        id: "productivity",
        name: "Productivity",
        enabled: true,
        refreshInterval: 60.0
    )
    public var state: ModuleState = .active

    public struct ProductivityStatus {
        public let calendarEvents: [CalendarEvent]
        public let focusModeActive: Bool
        public let pomodoroActive: Bool
        public let pomodoroTimeRemaining: TimeInterval?
        public let timers: [CountdownTimer]
        public let worldClocks: [WorldClock]
        public let notes: [String]
    }

    public struct CalendarEvent {
        public let title: String
        public let startDate: Date
        public let endDate: Date
        public let location: String?
    }

    public struct CountdownTimer {
        public let name: String
        public let remaining: TimeInterval
        public let isRunning: Bool
    }

    public struct WorldClock {
        public let city: String
        public let timeZone: String
        public let time: Date
    }

    public func initialize() async throws {
        // Productivity module initialization
    }

    public func refresh() async throws -> ModuleOutput {
        let status = await collectStatus()
        let items = buildMenuItems(from: status)
        return ModuleOutput(items: items, source: id)
    }

    public func invalidate() {}

    public func setEnabled(_ enabled: Bool) {
        state = enabled ? .active : .paused
    }

    private func collectStatus() async -> ProductivityStatus {
        let events = await fetchCalendarEvents()
        let focusMode = isFocusModeActive()
        let pomodoro = getPomodoroStatus()
        let timers = getActiveTimers()
        let clocks = getWorldClocks()
        let notes = getQuickNotes()

        return ProductivityStatus(
            calendarEvents: events,
            focusModeActive: focusMode,
            pomodoroActive: pomodoro.active,
            pomodoroTimeRemaining: pomodoro.remaining,
            timers: timers,
            worldClocks: clocks,
            notes: notes
        )
    }

    private func buildMenuItems(from status: ProductivityStatus) -> [MenuItem] {
        var items: [MenuItem] = []

        if status.focusModeActive {
            items.append(MenuItem(
                title: "Focus Mode Active",
                icon: "target",
                color: "#AF52DE",
                order: 0
            ))
        }

        if status.pomodoroActive, let remaining = status.pomodoroTimeRemaining {
            let mins = Int(remaining) / 60
            let secs = Int(remaining) % 60
            items.append(MenuItem(
                title: "Pomodoro: \(mins):\(String(format: "%02d", secs))",
                icon: "timer",
                badge: "Active",
                color: "#FF9500",
                order: 1
            ))
        }

        if !status.calendarEvents.isEmpty {
            items.append(MenuItem(
                title: "Next: \(status.calendarEvents[0].title)",
                icon: "calendar",
                order: 2
            ))
        }

        for timer in status.timers {
            let mins = Int(timer.remaining) / 60
            let secs = Int(timer.remaining) % 60
            items.append(MenuItem(
                title: "\(timer.name): \(mins):\(String(format: "%02d", secs))",
                icon: timer.isRunning ? "timer" : "pause",
                color: timer.isRunning ? "#34C759" : nil,
                order: 3 + status.timers.firstIndex(where: { $0.name == timer.name }) ?? 0
            ))
        }

        for clock in status.worldClocks {
            let formatter = DateFormatter()
            formatter.timeZone = TimeZone(identifier: clock.timeZone)
            formatter.timeStyle = .short
            items.append(MenuItem(
                title: "\(clock.city): \(formatter.string(from: clock.time))",
                icon: "globe",
                order: 10 + status.worldClocks.firstIndex(where: { $0.city == clock.city }) ?? 0
            ))
        }

        if !status.notes.isEmpty {
            items.append(MenuItem(
                title: "Notes (\(status.notes.count))",
                icon: "note",
                order: 99
            ))
        }

        return items
    }

    private func fetchCalendarEvents() async -> [CalendarEvent] {
        let eventStore = EKEventStore()
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .authorized else { return [] }
        let predicate = eventStore.predicateForEvents(withStart: Date(), end: Date().addingTimeInterval(86400), calendars: nil)
        let events = eventStore.events(matching: predicate)
        return events.prefix(5).map { event in
            CalendarEvent(
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location
            )
        }
    }

    private func isFocusModeActive() -> Bool {
        let center = distributedNotificationCenter()
        return center.object(forName: .init("com.apple.focus.modeChanged")) != nil
    }

    private func getPomodoroStatus() -> (active: Bool, remaining: TimeInterval?) {
        let center = distributedNotificationCenter()
        guard let info = center.object(forName: .init("com.apple.pomodoro.timerState")) as? [String: Any] else {
            return (false, nil)
        }
        let active = info["Running"] as? Bool ?? false
        let remaining = info["RemainingTime"] as? TimeInterval
        return (active, remaining)
    }

    private func getActiveTimers() -> [CountdownTimer] {
        []
    }

    private func getWorldClocks() -> [WorldClock] {
        let defaults = UserDefaults.standard
        guard let clocks = defaults.array(forKey: "worldClocks") as? [[String: String]] else { return [] }
        return clocks.compactMap { clock in
            guard let city = clock["city"], let tz = clock["timezone"] else { return nil }
            return WorldClock(city: city, timeZone: tz, time: Date())
        }
    }

    private func getQuickNotes() -> [String] {
        let defaults = UserDefaults.standard
        return defaults.stringArray(forKey: "quickNotes") ?? []
    }

    private func distributedNotificationCenter() -> DistributedNotificationCenter {
        DistributedNotificationCenter.default()
    }
}