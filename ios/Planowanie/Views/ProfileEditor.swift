import SwiftUI

struct AvatarView: View {
    var emoji: String
    var color: UInt32
    var size: CGFloat

    init(emoji: String, color: UInt32, size: CGFloat) {
        self.emoji = emoji
        self.color = color
        self.size = size
    }

    init(profile: Profile, size: CGFloat) {
        self.init(emoji: profile.emoji, color: profile.color, size: size)
    }

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.52))
            .frame(width: size, height: size)
            .background(Color(hex: color).opacity(0.22), in: Circle())
            .overlay(Circle().strokeBorder(Color(hex: color), lineWidth: max(1.5, size * 0.04)))
            .accessibilityHidden(true)
    }
}

/// Powitanie (pierwszy profil), dodawanie kolejnego profilu albo edycja istniejącego.
struct ProfileEditor: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    let editing: Profile?
    let isOnboarding: Bool

    @State private var name: String
    @State private var emoji: String
    @State private var color: UInt32
    @State private var withSeed: Bool
    @FocusState private var nameFocused: Bool

    init(editing: Profile? = nil, isOnboarding: Bool = false) {
        self.editing = editing
        self.isOnboarding = isOnboarding
        _name = State(initialValue: editing?.name ?? "")
        _emoji = State(initialValue: editing?.emoji ?? Profile.emojis[0])
        _color = State(initialValue: editing?.color ?? Profile.colors[0])
        _withSeed = State(initialValue: isOnboarding)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                AvatarView(emoji: emoji, color: color, size: 104)
                    .animation(.spring(response: 0.35, dampingFraction: 0.6), value: emoji)
                    .animation(.easeInOut, value: color)

                TextField("Twoje imię", text: $name)
                    .font(Theme.rounded(.title3, .bold))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .padding(14)
                    .card(radius: 16)

                section("Avatar") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                        ForEach(Profile.emojis, id: \.self) { e in
                            Button { emoji = e } label: {
                                Text(e)
                                    .font(.system(size: 24))
                                    .frame(maxWidth: .infinity, minHeight: 40)
                                    .background {
                                        if e == emoji {
                                            RoundedRectangle(cornerRadius: 10).fill(Color(hex: color).opacity(0.22))
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Avatar \(e)")
                        }
                    }
                }

                section("Kolor") {
                    HStack(spacing: 10) {
                        ForEach(Profile.colors, id: \.self) { c in
                            Button { color = c } label: {
                                Circle()
                                    .fill(Color(hex: c))
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if c == color {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .heavy))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(c == color ? "Wybrany kolor" : "Kolor")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                if editing == nil {
                    if store.hasLegacyPlan {
                        Label("Twój dotychczasowy plan zostanie przypisany do tego profilu.", systemImage: "checkmark.circle.fill")
                            .font(Theme.rounded(.subheadline, .semibold))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Toggle(isOn: $withSeed) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Zacznij z gotowym planem")
                                    .font(Theme.rounded(.body, .bold))
                                Text("ATPL, PAR, mechanika, Stanford, western i siłownia do końca 2026")
                                    .font(Theme.rounded(.footnote))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        .padding(14)
                        .card(radius: 16)
                    }
                }

                Button(action: save) {
                    Text(isOnboarding ? "Zaczynamy" : editing == nil ? "Dodaj profil" : "Zapisz")
                        .font(Theme.rounded(.headline, .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .disabled(trimmedName.isEmpty)

                if !isOnboarding {
                    Button("Anuluj") { dismiss() }
                        .font(Theme.rounded(.body, .semibold))
                }
            }
            .foregroundStyle(Theme.fg)
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.bg.ignoresSafeArea())
        .tint(Theme.accent)
        .onAppear { if editing == nil { nameFocused = true } }
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder private var header: some View {
        if isOnboarding {
            VStack(spacing: 6) {
                Text("Cześć! 👋")
                    .font(Theme.display(34))
                Text("Stwórz swój profil – plan i przypomnienia będą tylko Twoje.")
                    .font(Theme.rounded(.body, .semibold))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
        } else {
            Text(editing == nil ? "Nowy profil" : "Edytuj profil")
                .font(Theme.display(28))
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(1)
                .foregroundStyle(Theme.muted)
            content()
        }
        .padding(14)
        .card(radius: 16)
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        if var p = editing {
            p.name = trimmedName
            p.emoji = emoji
            p.color = color
            store.updateProfile(p)
        } else {
            withAnimation(.easeInOut) {
                store.createProfile(name: trimmedName, emoji: emoji, color: color, withSeed: withSeed)
            }
        }
        if !isOnboarding { dismiss() }
    }
}
