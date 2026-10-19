import UserNotifications

enum Prefs {
    static let notify = "notify"
    static let lead = "lead"
    static let morningOn = "morningOn"
    static let morning = "morningMinutes"
    static let startReminder = "startReminder"
    static let simpleMode = "simpleMode"
    static let keepAwake = "keepAwake"
    static let hideDetails = "hideDetails"
    static let appearance = "appearance"
    static let tutorialDone = "tutorialDone"

    static var defaults: UserDefaults { .standard }
    static var leadMinutes: Int { defaults.object(forKey: lead) as? Int ?? 10 }
    static var morningMinutes: Int { defaults.object(forKey: morning) as? Int ?? 450 }
    static var morningEnabled: Bool { defaults.object(forKey: morningOn) as? Bool ?? true }
    static var startReminderEnabled: Bool { defaults.object(forKey: startReminder) as? Bool ?? true }
    static var hideDetailsEnabled: Bool { defaults.bool(forKey: hideDetails) }
}

/// Lokalne powiadomienia: przypomnienie przed każdym zadaniem i poranne podsumowanie.
/// iOS trzyma najwyżej 64 zaplanowane powiadomienia, więc planujemy najbliższe
/// i odświeżamy listę przy każdej zmianie i przy każdym otwarciu aplikacji.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private var pending: Task<Void, Never>?
    private let maxScheduled = 60
    private let snoozeSuffix = "-snooze"
    private let focusTimerID = "focus-timer"

    func setup() {
        center.delegate = self
        let done = UNNotificationAction(identifier: "DONE", title: "Zrobione ✓", options: [])
        let snooze = UNNotificationAction(identifier: "SNOOZE", title: "Przypomnij za 10 min", options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: "TASK", actions: [done, snooze], intentIdentifiers: [], options: []),
        ])
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func reschedule(_ tasks: [TaskItem], name: String?) {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await apply(tasks, name: name)
        }
    }

    private func apply(_ tasks: [TaskItem], name: String?) async {
        let old = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { !$0.hasSuffix(snoozeSuffix) && $0 != focusTimerID }
        center.removePendingNotificationRequests(withIdentifiers: old)

        guard Prefs.defaults.bool(forKey: Prefs.notify),
              await authorizationStatus() == .authorized else { return }

        let now = Date()
        let lead = Prefs.leadMinutes
        var items: [(Date, UNNotificationRequest)] = []

        let startToo = Prefs.startReminderEnabled && lead > 0
        let hide = Prefs.hideDetailsEnabled
        let hidden = "Otwórz Planowanie, żeby zobaczyć szczegóły"
        for t in tasks where !t.done {
            let first = t.nextStep.map { "Pierwszy krok: \($0.title)" }
            let fire = t.startDate.addingTimeInterval(TimeInterval(-lead * 60))
            if fire > now {
                let c = taskContent(t)
                let when = lead == 0 ? "Teraz" : "Za \(lead) min"
                c.title = hide ? "⏰ \(when): zadanie z planu" : "\(t.cat.emoji) \(when): \(t.title)"
                c.body = hide ? hidden : "\(t.time)–\(Day.time(t.endMinutes))" + (first ?? t.note).prefixed(" · ")
                items.append((fire, request(id: t.id, content: c, at: fire)))
            }
            // Drugie przypomnienie w chwili startu – przejście między zajęciami bywa najtrudniejsze.
            if startToo && t.startDate > now {
                let c = taskContent(t)
                c.title = hide ? "▶︎ Czas na kolejne zadanie" : "▶︎ Zaczynamy: \(t.title)"
                c.body = hide ? hidden : first ?? "Zacznij od 5 minut – reszta przyjdzie sama 💪"
                items.append((t.startDate, request(id: t.id + "-start", content: c, at: t.startDate)))
            }
        }

        if Prefs.morningEnabled {
            let byDay = Dictionary(grouping: tasks, by: \.date)
            for i in 0..<14 {
                let day = Day.add(Day.today, i)
                let fire = Day.date(day, minutes: Prefs.morningMinutes)
                guard fire > now, let list = byDay[day]?.sorted(by: { $0.time < $1.time }), !list.isEmpty else { continue }
                let c = UNMutableNotificationContent()
                let hello = hide ? "Dzień dobry!" : name.map { "Dzień dobry, \($0)!" } ?? "Dzień dobry!"
                c.title = "\(hello) Dziś \(list.count) \(Day.tasksWord(list.count)) ☀️"
                c.body = hide ? "Otwórz Planowanie, żeby zobaczyć plan dnia"
                    : list.filter { $0.cat != .food }.map { "\($0.time) \($0.shortTitle)" }.joined(separator: " · ")
                c.sound = .default
                c.threadIdentifier = "morning"
                items.append((fire, request(id: "morning-\(day)", content: c, at: fire)))
            }
        }

        for (_, r) in items.sorted(by: { $0.0 < $1.0 }).prefix(maxScheduled) {
            try? await center.add(r)
        }
    }

    private func taskContent(_ t: TaskItem) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.sound = .default
        c.categoryIdentifier = "TASK"
        c.threadIdentifier = t.date
        c.userInfo = ["id": t.id]
        return c
    }

    /// Powiadomienie po końcu timera w trybie skupienia (działa też przy zablokowanym telefonie).
    func scheduleFocusTimer(after seconds: TimeInterval, title: String, body: String) {
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.sound = .default
        center.add(UNNotificationRequest(identifier: focusTimerID, content: c,
                                         trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)))
    }

    func cancelFocusTimer() {
        center.removePendingNotificationRequests(withIdentifiers: [focusTimerID])
    }

    private func request(id: String, content: UNNotificationContent, at date: Date) -> UNNotificationRequest {
        let comps = Day.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return UNNotificationRequest(identifier: id, content: content,
                                     trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
    }

    func sendTest() {
        let c = UNMutableNotificationContent()
        c.title = "✈️ Za 10 min: ATPL EASA"
        c.body = "Tak będą wyglądały przypomnienia 🙂"
        c.sound = .default
        center.add(UNNotificationRequest(identifier: "test", content: c,
                                         trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
    }

    // MARK: UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let content = response.notification.request.content
        guard let id = content.userInfo["id"] as? String else { return }
        switch response.actionIdentifier {
        case "DONE":
            await MainActor.run { Store.shared.setDone(id) }
        case "SNOOZE":
            let c = (content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
            c.title = content.title.replacingOccurrences(of: #"(Za \d+ min|Teraz)"#, with: "Przypomnienie", options: .regularExpression)
            try? await center.add(UNNotificationRequest(identifier: id + snoozeSuffix, content: c,
                                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 600, repeats: false)))
        default:
            break
        }
    }
}

private extension String {
    /// "" zostaje pustym tekstem, a niepusty tekst dostaje przedrostek.
    func prefixed(_ p: String) -> String { isEmpty ? "" : p + self }
}
