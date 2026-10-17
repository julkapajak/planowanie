import Foundation

/// Wszystkie zadania, zapisywane jako JSON w katalogu aplikacji.
final class Store: ObservableObject {
    static let shared = Store()

    @Published private(set) var tasks: [TaskItem] {
        didSet {
            save()
            NotificationManager.shared.reschedule(tasks)
        }
    }

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("tasks.json")
    }

    private init() {
        if let data = try? Data(contentsOf: Store.fileURL),
           let saved = try? JSONDecoder().decode([TaskItem].self, from: data) {
            tasks = saved
        } else {
            tasks = Seed.build()
            save()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        try? data.write(to: Store.fileURL, options: .atomic)
    }

    // MARK: odczyt

    func tasks(on day: String) -> [TaskItem] {
        tasks.filter { $0.date == day }.sorted { $0.time < $1.time }
    }

    func progress(on day: String) -> (done: Int, total: Int) {
        let t = tasks.filter { $0.date == day }
        return (t.filter(\.done).count, t.count)
    }

    // MARK: zmiany

    func toggle(_ id: String) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].done.toggle()
    }

    func setDone(_ id: String) {
        guard let i = tasks.firstIndex(where: { $0.id == id }), !tasks[i].done else { return }
        tasks[i].done = true
    }

    func update(_ task: TaskItem) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[i] = task
    }

    /// Dodaje zadanie; z `weekly` powtarza je co tydzień do końca planu. Zwraca liczbę dodanych.
    @discardableResult
    func add(_ task: TaskItem, weekly: Bool) -> Int {
        var new: [TaskItem] = []
        var day = task.date
        repeat {
            var t = task
            t.id = TaskItem.newID()
            t.date = day
            new.append(t)
            day = Day.add(day, 7)
        } while weekly && day <= max(Seed.end, task.date)
        tasks += new
        return new.count
    }

    func delete(_ id: String) {
        tasks.removeAll { $0.id == id }
    }

    func replaceAll(_ new: [TaskItem]) {
        tasks = new
    }

    func resetToSeed() {
        tasks = Seed.build()
    }

    func refreshNotifications() {
        NotificationManager.shared.reschedule(tasks)
    }

    // MARK: kopia zapasowa (zgodna z wersją web: {"tasks": [...]})

    struct Backup: Codable { var tasks: [TaskItem] }

    func backupData() -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? enc.encode(Backup(tasks: tasks))) ?? Data()
    }
}
