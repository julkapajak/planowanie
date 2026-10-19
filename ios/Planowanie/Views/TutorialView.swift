import SwiftUI

/// Krótka instrukcja po utworzeniu profilu (dostępna też z Ustawień).
/// Mało tekstu na ekranie, jedna myśl na stronę.
struct TutorialView: View {
    @EnvironmentObject private var store: Store
    @AppStorage(Prefs.notify) private var notifyOn = false
    @AppStorage(Prefs.appearance) private var appearance = 0
    @AppStorage(Prefs.hideDetails) private var hideDetails = false
    var onFinish: () -> Void

    @State private var page = 0
    @State private var lockMethod: String?
    @State private var lockMessage: String?

    private struct Page {
        let icon: String, color: Color, title: String, text: String
    }

    private let pages = [
        Page(icon: "sun.max.fill", color: Theme.accent, title: "Twój dzień w skrócie",
             text: "Na ekranie Dzień widzisz tylko 3 najbliższe zadania – reszta spokojnie czeka niżej. Dotknij kółka, żeby odhaczyć zadanie."),
        Page(icon: "scope", color: Category.par.color, title: "Tryb skupienia",
             text: "Dotknij zadania, a zobaczysz tylko je. Trudno zacząć? Kliknij „Tylko 5 minut”. Duże zadania są podzielone na małe kroki."),
        Page(icon: "heart.fill", color: Category.clean.color, title: "Gdy coś nie wyjdzie",
             text: "To normalne. Przytrzymaj palec na zadaniu, żeby przesunąć je o godzinę albo na jutro. Zaległe przeniesiesz jednym dotknięciem."),
        Page(icon: "bell.badge.fill", color: Category.atpl.color, title: "Przypomnienia",
             text: "Przypomnę Ci przed każdym zadaniem i w chwili startu – z pierwszym krokiem. Z powiadomienia od razu odhaczysz zadanie."),
        Page(icon: "lock.fill", color: Category.mech.color, title: "Prywatność i wygląd",
             text: "Twój plan jest tylko na tym telefonie. Możesz go dodatkowo chronić i wybrać jasny albo ciemny wygląd."),
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if !isLast {
                    Button("Pomiń", action: onFinish)
                        .font(Theme.rounded(.body, .semibold))
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 20)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    pageView(i).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Theme.accent : Theme.line)
                        .frame(width: i == page ? 22 : 8, height: 8)
                }
            }
            .animation(.snappy, value: page)
            .padding(.bottom, 18)
            .accessibilityHidden(true)

            Button {
                if isLast { onFinish() } else { withAnimation(.snappy) { page += 1 } }
            } label: {
                Text(isLast ? "Zaczynamy" : "Dalej")
                    .font(Theme.rounded(.headline, .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .foregroundStyle(Theme.fg)
        .background(Theme.bg.ignoresSafeArea())
        .tint(Theme.accent)
        .task { lockMethod = Lock.shared.methodName }
    }

    private func pageView(_ i: Int) -> some View {
        let p = pages[i]
        return ScrollView {
            VStack(spacing: 18) {
                Image(systemName: p.icon)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 120, height: 120)
                    .background(p.color.gradient, in: Circle())
                    .shadow(color: p.color.opacity(0.35), radius: 16, y: 8)
                    .padding(.top, 24)
                Text(p.title)
                    .font(Theme.display(28))
                    .multilineTextAlignment(.center)
                Text(p.text)
                    .font(Theme.rounded(.title3, .medium))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if i == 3 { notificationsControl }
                if i == 4 { privacyControls }
            }
            .padding(.horizontal, 28)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var notificationsControl: some View {
        Group {
            if notifyOn {
                Label("Przypomnienia włączone", systemImage: "checkmark.circle.fill")
                    .font(Theme.rounded(.headline, .bold))
                    .foregroundStyle(Theme.ok)
            } else {
                Button {
                    Task {
                        notifyOn = await NotificationManager.shared.requestPermission()
                        store.refreshNotifications()
                    }
                } label: {
                    Label("Włącz przypomnienia", systemImage: "bell.fill")
                        .font(Theme.rounded(.headline, .bold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            }
        }
        .padding(.top, 8)
    }

    private var privacyControls: some View {
        VStack(spacing: 14) {
            Picker("Wygląd", selection: $appearance) {
                Text("Auto").tag(0)
                Text("Jasny").tag(1)
                Text("Ciemny").tag(2)
            }
            .pickerStyle(.segmented)

            if let lockMethod {
                Toggle("Chroń plan: \(lockMethod)", isOn: Binding(
                    get: { store.active?.locked ?? false },
                    set: { on in
                        Task {
                            let ok = await Lock.shared.setLocked(on, store: store)
                            lockMessage = ok ? nil : "Nie udało się potwierdzić. Spróbuj jeszcze raz."
                        }
                    }
                ))
                .font(Theme.rounded(.body, .semibold))
            }
            Toggle("Ukryj nazwy zadań w powiadomieniach", isOn: $hideDetails)
                .font(Theme.rounded(.body, .semibold))
            if let lockMessage {
                Text(lockMessage)
                    .font(Theme.rounded(.footnote))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(16)
        .card(radius: 18)
        .padding(.top, 8)
        .onChange(of: hideDetails) { store.refreshNotifications() }
    }
}
