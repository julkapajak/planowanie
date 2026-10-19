import LocalAuthentication
import SwiftUI

/// Ochrona profilu Face ID / Touch ID / kodem telefonu.
/// Odblokowany profil zostaje otwarty, dopóki aplikacja nie leży w tle dłużej niż minutę.
final class Lock: ObservableObject {
    static let shared = Lock()

    @Published private(set) var unlockedID: String?
    private var backgroundAt: Date?

    func needsUnlock(_ p: Profile?) -> Bool {
        guard let p, p.locked else { return false }
        return unlockedID != p.id
    }

    /// Nazwa zabezpieczenia w telefonie albo nil, gdy telefon nie ma ustawionego kodu.
    var methodName: String? {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return nil }
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "kod telefonu"
        }
    }

    @MainActor
    func unlock(_ p: Profile) async -> Bool {
        let ctx = LAContext()
        var error: NSError?
        // Telefon bez kodu nie ma czym chronić – nie zamykamy planu na zawsze.
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            unlockedID = p.id
            return true
        }
        let ok = (try? await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Odblokuj plan: \(p.name)")) ?? false
        if ok { unlockedID = p.id }
        return ok
    }

    /// Włącza albo wyłącza ochronę aktywnego profilu – zawsze po potwierdzeniu tożsamości.
    @MainActor
    func setLocked(_ on: Bool, store: Store) async -> Bool {
        guard var p = store.active, methodName != nil else { return false }
        let ctx = LAContext()
        let reason = on ? "Włącz ochronę planu" : "Wyłącz ochronę planu"
        guard (try? await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) == true else { return false }
        p.locked = on
        store.updateProfile(p)
        unlockedID = p.id
        return true
    }

    func sceneChanged(_ phase: ScenePhase) {
        switch phase {
        case .background:
            backgroundAt = Date()
        case .active:
            if let t = backgroundAt, Date().timeIntervalSince(t) > 60 { unlockedID = nil }
            backgroundAt = nil
        default:
            break
        }
    }
}

struct LockScreen: View {
    @EnvironmentObject private var store: Store
    @ObservedObject private var lock = Lock.shared
    let profile: Profile
    @State private var failed = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            AvatarView(profile: profile, size: 96)
            Text(profile.name)
                .font(Theme.display(30))
            Label("Plan jest chroniony", systemImage: "lock.fill")
                .font(Theme.rounded(.subheadline, .semibold))
                .foregroundStyle(Theme.muted)
            Button {
                Task { failed = !(await lock.unlock(profile)) }
            } label: {
                Label("Odblokuj", systemImage: "faceid")
                    .font(Theme.rounded(.headline, .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 240)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .padding(.top, 8)
            if failed {
                Text("Nie udało się. Spróbuj jeszcze raz.")
                    .font(Theme.rounded(.footnote))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            if store.profiles.count > 1 {
                Menu {
                    ForEach(store.profiles.filter { $0.id != profile.id }) { p in
                        Button("\(p.emoji) \(p.name)") { store.switchTo(p.id) }
                    }
                } label: {
                    Text("Przełącz profil")
                        .font(Theme.rounded(.subheadline, .bold))
                }
                .padding(.bottom, 12)
            }
        }
        .foregroundStyle(Theme.fg)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.bg.ignoresSafeArea())
        .task(id: profile.id) { failed = !(await lock.unlock(profile)) }
    }
}

/// Zasłona w przełączniku aplikacji, żeby nikt nie podejrzał chronionego planu.
struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            Image(systemName: "lock.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.muted)
        }
    }
}
