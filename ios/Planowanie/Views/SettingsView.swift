import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.openURL) private var openURL

    @AppStorage(Prefs.notify) private var notifyOn = false
    @AppStorage(Prefs.lead) private var lead = 10
    @AppStorage(Prefs.morningOn) private var morningOn = true
    @AppStorage(Prefs.morning) private var morningMinutes = 450
    @AppStorage(Prefs.startReminder) private var startReminder = true
    @AppStorage(Prefs.simpleMode) private var simpleMode = true
    @AppStorage(Prefs.keepAwake) private var keepAwake = true

    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var exporting = false
    @State private var importing = false
    @State private var confirmReset = false
    @State private var message: String?
    @State private var editingProfile: Profile?
    @State private var addingProfile = false
    @State private var confirmDeleteProfile = false

    var body: some View {
        NavigationStack {
            Form {
                if let me = store.active { profileSection(me) }

                Section {
                    Toggle("Powiadomienia", isOn: Binding(get: { notifyOn && authStatus == .authorized }, set: setNotify))
                    Picker("Ile minut wcześniej", selection: $lead) {
                        Text("o czasie").tag(0)
                        ForEach([5, 10, 15, 30], id: \.self) { Text("\($0) min").tag($0) }
                    }
                    Toggle("Poranne podsumowanie dnia", isOn: $morningOn)
                    if morningOn {
                        DatePicker("Godzina podsumowania", selection: morningTime, displayedComponents: .hourAndMinute)
                    }
                    Button("Wyślij testowe powiadomienie") {
                        NotificationManager.shared.sendTest()
                        message = "Za 5 sekund przyjdzie test. Możesz zablokować telefon."
                    }
                    .disabled(authStatus != .authorized)
                } header: {
                    Text("🔔 Przypomnienia")
                } footer: {
                    Text(authStatus == .denied
                         ? "Powiadomienia są wyłączone w Ustawieniach iPhone’a. Włącz je tam dla aplikacji Planowanie."
                         : "Przypomnienia przychodzą też przy zamkniętej aplikacji. W powiadomieniu możesz od razu odhaczyć zadanie albo odłożyć je o 10 minut.")
                }

                Section {
                    Toggle("Prosty widok dnia", isOn: $simpleMode)
                    Toggle("Drugie przypomnienie w chwili startu", isOn: $startReminder)
                    Toggle("Nie wygaszaj ekranu w trybie skupienia", isOn: $keepAwake)
                } header: {
                    Text("🧠 Wsparcie skupienia")
                } footer: {
                    Text("Prosty widok pokazuje tylko 3 najbliższe zadania. Dotknij zadania, żeby otworzyć tryb skupienia z timerem i małymi krokami.")
                }

                if authStatus == .denied {
                    Button("Otwórz Ustawienia iPhone’a") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }

                Section {
                    Button("Zapisz kopię zapasową") { exporting = true }
                    Button("Wczytaj kopię (także z wersji web)") { importing = true }
                    Button("Przywróć plan startowy", role: .destructive) { confirmReset = true }
                } header: {
                    Text("💾 Dane")
                } footer: {
                    Text("Plan jest zapisany tylko na tym iPhonie. Kopia zapasowa i przywracanie dotyczą aktywnego profilu.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Ustawienia")
            .environment(\.locale, Locale(identifier: "pl_PL"))
        }
        .task { authStatus = await NotificationManager.shared.authorizationStatus() }
        .onChange(of: lead) { store.refreshNotifications() }
        .onChange(of: morningOn) { store.refreshNotifications() }
        .onChange(of: morningMinutes) { store.refreshNotifications() }
        .onChange(of: startReminder) { store.refreshNotifications() }
        .fileExporter(isPresented: $exporting, document: BackupDocument(data: store.backupData()),
                      contentType: .json, defaultFilename: "planowanie-kopia-\(Day.today)") { result in
            if case .success = result { message = "Kopia zapisana" }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url),
               let backup = try? JSONDecoder().decode(Store.Backup.self, from: data) {
                store.replaceAll(backup.tasks)
                message = "Wczytano \(backup.tasks.count) \(Day.tasksWord(backup.tasks.count))"
            } else {
                message = "To nie jest poprawna kopia planu"
            }
        }
        .confirmationDialog("Przywrócić plan startowy? Twoje zmiany i odhaczenia znikną.", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Przywróć", role: .destructive) {
                store.resetToSeed()
                message = "Przywrócono plan startowy"
            }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func profileSection(_ me: Profile) -> some View {
        Section {
            HStack(spacing: 12) {
                AvatarView(profile: me, size: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text(me.name).font(Theme.rounded(.headline, .bold))
                    Text("Aktywny profil").font(Theme.rounded(.caption)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Button("Edytuj") { editingProfile = me }
                    .buttonStyle(.borderless)
            }
            .sheet(item: $editingProfile) { p in ProfileEditor(editing: p).environmentObject(store) }

            ForEach(store.profiles.filter { $0.id != me.id }) { p in
                Button {
                    withAnimation(.easeInOut) { store.switchTo(p.id) }
                } label: {
                    HStack(spacing: 12) {
                        AvatarView(profile: p, size: 32)
                        Text(p.name).foregroundStyle(Theme.fg)
                        Spacer()
                        Text("Przełącz").foregroundStyle(Theme.accent)
                    }
                }
            }

            Button { addingProfile = true } label: {
                Label("Dodaj profil", systemImage: "person.badge.plus")
            }
            .sheet(isPresented: $addingProfile) { ProfileEditor().environmentObject(store) }

            Button("Usuń ten profil", role: .destructive) { confirmDeleteProfile = true }
                .confirmationDialog("Usunąć profil „\(me.name)” razem z jego planem?", isPresented: $confirmDeleteProfile, titleVisibility: .visible) {
                    Button("Usuń profil", role: .destructive) {
                        withAnimation(.easeInOut) { store.deleteProfile(me.id) }
                    }
                }
        } header: {
            Text("👤 Profil")
        } footer: {
            Text("Każdy profil ma własny plan. Przypomnienia przychodzą dla profilu, który jest aktywny.")
        }
    }

    private var morningTime: Binding<Date> {
        Binding(
            get: { Day.date(Day.today, minutes: morningMinutes) },
            set: { morningMinutes = Day.nowMinutes($0) }
        )
    }

    private func setNotify(_ on: Bool) {
        guard on else {
            notifyOn = false
            store.refreshNotifications()
            return
        }
        Task {
            if authStatus == .denied {
                message = "Najpierw włącz powiadomienia dla Planowania w Ustawieniach iPhone’a."
                return
            }
            let ok = await NotificationManager.shared.requestPermission()
            authStatus = await NotificationManager.shared.authorizationStatus()
            notifyOn = ok
            store.refreshNotifications()
        }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
