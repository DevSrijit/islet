import AppKit
import EventKit
import Observation

struct CalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: NSColor
    let calendarID: String
    let location: String?
}

struct CalendarInfo: Identifiable, Equatable {
    let id: String
    let title: String
    let color: NSColor
    let source: String
}

/// Today's events from EventKit, plus a reminder that fires shortly before the next event starts.
@MainActor
@Observable
final class CalendarService {
    private(set) var events: [CalendarEvent] = []
    private(set) var calendars: [CalendarInfo] = []
    private(set) var authorized = false
    private(set) var denied = false

    var onUpcoming: ((CalendarEvent, Int) -> Void)?
    var onHour: (() -> Void)?

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?
    private var refreshTimer: Timer?
    private var reminderTask: Task<Void, Never>?
    private var chimeTask: Task<Void, Never>?
    private var reminded: Set<String> = []
    private var running = false

    var nextEvent: CalendarEvent? {
        let now = Date()
        return events.first { !$0.isAllDay && $0.end > now }
    }

    var currentEvent: CalendarEvent? {
        let now = Date()
        return events.first { !$0.isAllDay && $0.start <= now && $0.end > now }
    }

    func start() {
        guard !running else { return }
        running = true
        Task { await requestAccess() }
    }

    func stop() {
        running = false
        refreshTimer?.invalidate(); refreshTimer = nil
        reminderTask?.cancel(); reminderTask = nil
        chimeTask?.cancel(); chimeTask = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        events = []
    }

    func requestAccess() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess:
            authorized = true
        case .notDetermined:
            authorized = (try? await store.requestFullAccessToEvents()) ?? false
        default:
            authorized = false
        }
        denied = !authorized && status != .notDetermined
        guard authorized, running else { return }
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
        scheduleChime()
    }

    func refresh() {
        guard authorized else { return }
        calendars = store.calendars(for: .event).map {
            CalendarInfo(id: $0.calendarIdentifier, title: $0.title, color: $0.color ?? .systemBlue, source: $0.source.title)
        }.sorted { $0.title < $1.title }

        let excluded = Set(Preferences.shared.calendarExcluded)
        let included = store.calendars(for: .event).filter { !excluded.contains($0.calendarIdentifier) }
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: included)
        events = store.events(matching: predicate)
            .filter { $0.status != .canceled }
            .sorted { ($0.isAllDay ? 0 : 1, $0.startDate) < ($1.isAllDay ? 0 : 1, $1.startDate) }
            .map {
                CalendarEvent(id: $0.eventIdentifier ?? UUID().uuidString, title: $0.title ?? "Untitled",
                              start: $0.startDate, end: $0.endDate, isAllDay: $0.isAllDay,
                              color: $0.calendar.color ?? .systemBlue, calendarID: $0.calendar.calendarIdentifier,
                              location: $0.location)
            }
        scheduleReminder()
    }

    private func scheduleReminder() {
        reminderTask?.cancel()
        let minutes = Preferences.shared.calendarReminderMinutes
        guard minutes > 0 else { return }
        let now = Date()
        guard let next = events.first(where: { !$0.isAllDay && $0.start > now && !reminded.contains($0.id) }) else { return }
        let fireAt = next.start.addingTimeInterval(-Double(minutes * 60))
        let delay = max(fireAt.timeIntervalSince(now), 0)
        reminderTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            self.reminded.insert(next.id)
            let minutesLeft = max(Int(next.start.timeIntervalSinceNow / 60), 0)
            self.onUpcoming?(next, minutesLeft)
            self.scheduleReminder()
        }
    }

    private func scheduleChime() {
        chimeTask?.cancel()
        chimeTask = Task { [weak self] in
            while !Task.isCancelled {
                let now = Date()
                let nextHour = Calendar.current.nextDate(after: now, matching: DateComponents(minute: 0, second: 0), matchingPolicy: .nextTime) ?? now.addingTimeInterval(3600)
                try? await Task.sleep(for: .seconds(nextHour.timeIntervalSince(now)))
                guard !Task.isCancelled else { return }
                if Preferences.shared.hourlyChime { self?.onHour?() }
            }
        }
    }

    func openCalendarApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }
}
