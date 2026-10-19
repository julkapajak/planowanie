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
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = 0
    @State private var selected = Day.today

    var body: some View {
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
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refreshNotifications() }
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
}
