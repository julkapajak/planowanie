import Foundation

/// Profile i zadania aktywnego profilu, zapisywane jako JSON w katalogu aplikacji:
/// `profiles.json` oraz osobny `tasks-<id profilu>.json` dla każdego profilu.
final class Store: ObservableObject {
    static let shared = Store()

    @Published private(set) var profiles: [Profile]
    @Published private(set) var activeID: String?
    @Published private(set) var tasks: [TaskItem] {
        didSet {
            saveTasks()
            refreshNotifications()
        }
    }

    var active: Profile? { profiles.first { $0.id == activeID } }

    private static let activeKey = "activeProfile"

    private static let dir: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    private static var profilesURL: URL { dir.appendingPathComponent("profiles.json") }
    /// Plik z wersji bez profili – przy pierwszym profilu przenosimy z niego plan.
    private static var legacyURL: URL { dir.appendingPathComponent("tasks.json") }
    private static func tasksURL(_ id: String) -> URL { dir.appendingPathComponent("tasks-\(id).json") }

    private static func loadTasks(_ id: String) -> [TaskItem] {
        loadTasks(from: tasksURL(id)) ?? []
    }

    private static func loadTasks(from url: URL) -> [TaskItem]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([TaskItem].self, from: data)
    }

    private init() {
        let saved = (try? Data(contentsOf: Store.profilesURL))
            .flatMap { try? JSONDecoder().decode([Profile].self, from: $0) } ?? []
        let remembered = UserDefaults.standard.string(forKey: Store.activeKey)
        let id = saved.contains(where: { $0.id == remembered }) ? remembered : saved.first?.id
        profiles = saved
        activeID = id
        tasks = id.map { Store.loadTasks($0) } ?? []

        #if DEBUG
        // Zrzuty ekranu w CI: `-demoProfile Julia` tworzy profil z gotowym planem.
        if saved.isEmpty, let demo = UserDefaults.standard.string(forKey: "demoProfile") {
            createProfile(name: demo, emoji: "🌸", color: Profile.colors[0], withSeed: true)
            saveTasks()
        }
        #endif
    }

    private func saveTasks() {
        guard let id = activeID, let data = try? JSONEncoder().encode(tasks) else { return }
        try? data.write(to: Store.tasksURL(id), options: .atomic)
    }

    private func saveProfiles() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        try? data.write(to: Store.profilesURL, options: .atomic)
    }

    // MARK: profile

    /// Czy jest plan z wersji sprzed profili (zostanie przypisany do pierwszego profilu).
    var hasLegacyPlan: Bool {
        profiles.isEmpty && FileManager.default.fileExists(atPath: Store.legacyURL.path)
    }

    func createProfile(name: String, emoji: String, color: UInt32, withSeed: Bool) {
        var initial = withSeed ? Seed.build() : []
        if hasLegacyPlan, let legacy = Store.loadTasks(from: Store.legacyURL) {
            initial = legacy
            try? FileManager.default.removeItem(at: Store.legacyURL)
        }
        let p = Profile(id: UUID().uuidString, name: name, emoji: emoji, color: color)
        profiles.append(p)
        saveProfiles()
        activate(p.id, tasks: initial)
    }

    func updateProfile(_ p: Profile) {
        guard let i = profiles.firstIndex(where: { $0.id == p.id }) else { return }
        profiles[i] = p
        saveProfiles()
        refreshNotifications()
    }

    func switchTo(_ id: String) {
        guard id != activeID, profiles.contains(where: { $0.id == id }) else { return }
        activate(id, tasks: Store.loadTasks(id))
    }

    /// Usuwa profil razem z jego planem. Po usunięciu ostatniego wraca ekran powitalny.
    func deleteProfile(_ id: String) {
        profiles.removeAll { $0.id == id }
        saveProfiles()
        try? FileManager.default.removeItem(at: Store.tasksURL(id))
        if activeID == id {
            let next = profiles.first?.id
            activate(next, tasks: next.map { Store.loadTasks($0) } ?? [])
        }
    }

    private func activate(_ id: String?, tasks new: [TaskItem]) {
        activeID = id
        UserDefaults.standard.set(id, forKey: Store.activeKey)
        tasks = new
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

    // MARK: kroki i przesuwanie

    /// Odhacza krok. Gdy wszystkie kroki są zrobione, zadanie też jest zrobione.
    func toggleStep(_ taskID: String, _ stepID: String) {
        guard let i = tasks.firstIndex(where: { $0.id == taskID }),
              let j = tasks[i].steps.firstIndex(where: { $0.id == stepID }) else { return }
        var t = tasks[i]
        t.steps[j].done.toggle()
        if t.steps.allSatisfy(\.done) { t.done = true } else if !t.steps[j].done { t.done = false }
        tasks[i] = t
    }

    func addStep(_ taskID: String, title: String) {
        guard let i = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[i].steps.append(Step(id: TaskItem.newID(), title: title))
        tasks[i].done = false
    }

    /// Przesuwa start zadania o `minutes`; po północy zadanie przechodzi na następny dzień.
    func postpone(_ id: String, minutes: Int) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        let m = tasks[i].startMinutes + minutes
        if m >= 24 * 60 {
            tasks[i].date = Day.add(tasks[i].date, 1)
            tasks[i].time = Day.time(m - 24 * 60)
        } else {
            tasks[i].time = Day.time(m)
        }
    }

    func moveToTomorrow(_ id: String) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].date = Day.add(tasks[i].date, 1)
    }

    /// Przenosi wskazane zadania na podany dzień (te same godziny). Zwraca liczbę przeniesionych.
    @discardableResult
    func move(_ ids: [String], to day: String) -> Int {
        let set = Set(ids)
        var copy = tasks
        var n = 0
        for i in copy.indices where set.contains(copy[i].id) {
            copy[i].date = day
            n += 1
        }
        tasks = copy
        return n
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
        NotificationManager.shared.reschedule(tasks, name: active?.name)
    }

    // MARK: kopia zapasowa (zgodna z wersją web: {"tasks": [...]})

    struct Backup: Codable { var tasks: [TaskItem] }

    func backupData() -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? enc.encode(Backup(tasks: tasks))) ?? Data()
    }
}
