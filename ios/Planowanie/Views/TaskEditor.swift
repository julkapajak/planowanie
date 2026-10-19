import SwiftUI

struct TaskEditor: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    let original: TaskItem?
    var onDone: (String) -> Void

    @State private var title: String
    @State private var date: Date
    @State private var time: Date
    @State private var dur: Int
    @State private var cat: Category
    @State private var note: String
    @State private var steps: [Step]
    @State private var newStep = ""
    @State private var weekly = false
    @State private var confirmDelete = false

    private let durations = [15, 20, 30, 45, 60, 75, 90, 120, 150, 180, 240]

    init(task: TaskItem?, defaultDate: String = Day.today, onDone: @escaping (String) -> Void) {
        original = task
        self.onDone = onDone
        let day = task?.date ?? defaultDate
        let minutes: Int = {
            if let task { return task.startMinutes }
            guard day == Day.today else { return 10 * 60 }
            // najbliższy kwadrans za co najmniej 15 min
            return min(23 * 60, (Day.nowMinutes() + 29) / 15 * 15)
        }()
        _title = State(initialValue: task?.title ?? "")
        _date = State(initialValue: Day.date(day))
        _time = State(initialValue: Day.date(day, minutes: minutes))
        _dur = State(initialValue: task?.dur ?? 60)
        _cat = State(initialValue: task?.cat ?? .life)
        _note = State(initialValue: task?.note ?? "")
        _steps = State(initialValue: task?.steps ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nazwa", text: $title)
                        .font(Theme.rounded(.body, .semibold))
                    Picker("Kategoria", selection: $cat) {
                        ForEach(Category.allCases) { c in
                            Label(c.name, systemImage: c.symbol).tag(c)
                        }
                    }
                }
                Section {
                    DatePicker("Dzień", selection: $date, displayedComponents: .date)
                    DatePicker("Godzina", selection: $time, displayedComponents: .hourAndMinute)
                    Picker("Czas trwania", selection: $dur) {
                        ForEach(durations, id: \.self) { Text(Day.duration($0)).tag($0) }
                        if !durations.contains(dur) { Text(Day.duration(dur)).tag(dur) }
                    }
                    if original == nil {
                        Toggle("Powtarzaj co tydzień do końca planu", isOn: $weekly)
                    }
                }
                Section {
                    ForEach($steps) { $s in
                        TextField("Krok", text: $s.title)
                    }
                    .onDelete { steps.remove(atOffsets: $0) }
                    .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
                    HStack {
                        Image(systemName: "plus.circle.fill").foregroundStyle(Theme.accent)
                        TextField("Dodaj mały krok", text: $newStep)
                            .submitLabel(.done)
                            .onSubmit(addStep)
                    }
                } header: {
                    Text("Małe kroki")
                } footer: {
                    Text("Rozbij zadanie na kroki tak małe, że łatwo je zacząć, np. „Otwórz notatki”.")
                }
                Section("Notatka") {
                    TextField("np. rozdział, ćwiczenia, link", text: $note, axis: .vertical)
                        .lineLimit(2...6)
                }
                if original != nil {
                    Section {
                        Button("Usuń zadanie", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .environment(\.locale, Locale(identifier: "pl_PL"))
            .navigationTitle(original == nil ? "Nowe zadanie" : "Edytuj zadanie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Anuluj") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz", action: save)
                        .fontWeight(.bold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Usunąć „\(original?.title ?? "")”?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Usuń", role: .destructive) {
                    if let original { store.delete(original.id) }
                    onDone("Usunięto")
                    dismiss()
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func addStep() {
        let title = newStep.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        steps.append(Step(id: TaskItem.newID(), title: title))
        newStep = ""
    }

    private func save() {
        var t = original ?? TaskItem(date: "", time: "", dur: 60, cat: .life, title: "")
        t.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        t.date = Day.key(date)
        t.time = Day.time(from: time)
        t.dur = dur
        t.cat = cat
        t.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var all = steps
        let extra = newStep.trimmingCharacters(in: .whitespacesAndNewlines)
        if !extra.isEmpty { all.append(Step(id: TaskItem.newID(), title: extra)) }
        t.steps = all.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
        if original != nil {
            store.update(t)
            onDone("Zapisano")
        } else {
            let n = store.add(t, weekly: weekly)
            onDone(n > 1 ? "Dodano \(n) powtórzeń" : "Dodano zadanie")
        }
        dismiss()
    }
}
