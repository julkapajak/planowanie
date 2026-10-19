import SwiftUI

@main
struct PlanowanieApp: App {
    @StateObject private var store = Store.shared

    init() {
        NotificationManager.shared.setup()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .tint(Theme.accent)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: Store
    @ObservedObject private var lock = Lock.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Prefs.appearance) private var appearance = 0
    @AppStorage(Prefs.tutorialDone) private var tutorialDone = false
    @State private var tab = 0
    @State private var selected = Day.today
    @State private var showTutorial = false

    init() {
        #if DEBUG
        // Zrzuty ekranu w CI: `-startTab 1` otwiera od razu wybraną zakładkę.
        _tab = State(initialValue: UserDefaults.standard.integer(forKey: "startTab"))
        #endif
    }

    var body: some View {
        Group {
            if store.active == nil {
                ProfileEditor(isOnboarding: true)
            } else if let p = store.active, lock.needsUnlock(p) {
                LockScreen(profile: p)
            } else {
                tabs
            }
        }
        .overlay {
            // w przełączniku aplikacji chroniony plan jest zasłonięty
            if scenePhase != .active && store.active?.locked == true { PrivacyCover() }
        }
        .fullScreenCover(isPresented: $showTutorial) {
            TutorialView {
                tutorialDone = true
                showTutorial = false
            }
            .environmentObject(store)
        }
        .onAppear {
            applyAppearance()
            showTutorialIfNeeded()
        }
        .onChange(of: appearance) { applyAppearance() }
        .onChange(of: store.activeID) { showTutorialIfNeeded() }
        .onChange(of: lock.unlockedID) { showTutorialIfNeeded() }
        .onChange(of: tutorialDone) { showTutorialIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            lock.sceneChanged(phase)
            if phase == .active {
                applyAppearance()
                store.refreshNotifications()
            }
        }
        #if targetEnvironment(macCatalyst)
        .onAppear {
            // Na Macu: rozsądny rozmiar okna, jak wysoki notes.
            for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
                scene.sizeRestrictions?.minimumSize = CGSize(width: 420, height: 640)
            }
        }
        #endif
    }

    private func showTutorialIfNeeded() {
        if store.active != nil && !tutorialDone && !lock.needsUnlock(store.active) { showTutorial = true }
    }

    /// Jasny / ciemny / automatyczny wygląd dla całego okna (także arkuszy i trybu skupienia).
    private func applyAppearance() {
        let style: UIUserInterfaceStyle = appearance == 1 ? .light : appearance == 2 ? .dark : .unspecified
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.windows.forEach { $0.overrideUserInterfaceStyle = style }
        }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            DayView(selected: $selected)
                .tabItem { Label("Dzień", systemImage: "sun.max.fill") }
                .tag(0)
            WeekView(selected: $selected) { day in
                selected = day
                tab = 0
            }
            .tabItem { Label("Tydzień", systemImage: "calendar") }
            .tag(1)
            SettingsView()
                .tabItem { Label("Ustawienia", systemImage: "gearshape.fill") }
                .tag(2)
        }
    }
}
