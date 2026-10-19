import SwiftUI

/// Tryb skupienia: jedno zadanie na cały ekran, widoczny upływ czasu, małe kroki
/// i timer „Tylko 5 minut”, który pomaga zacząć.
struct FocusView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Prefs.keepAwake) private var keepAwake = true

    let taskID: String

    @State private var timerEnd: Date?
    @State private var timerTotal: TimeInterval = 1
    @State private var timerLabel = ""
    @State private var newStep = ""
    @State private var editing: TaskItem?
    @State private var stepHaptic = 0
    @State private var doneHaptic = 0
    @State private var timerHaptic = 0
    @FocusState private var stepFieldFocused: Bool

    private var task: TaskItem? { store.tasks.first { $0.id == taskID } }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if let t = task {
                content(t)
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = keepAwake }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: task == nil) { _, gone in if gone { dismiss() } }
        .sensoryFeedback(.impact(weight: .light), trigger: stepHaptic)
        .sensoryFeedback(.success, trigger: doneHaptic)
        .sensoryFeedback(.warning, trigger: timerHaptic)
        .task(id: timerEnd) {
            guard let end = timerEnd else { return }
            let wait = end.timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
            guard !Task.isCancelled, timerEnd == end else { return }
            timerHaptic += 1
        }
        .sheet(item: $editing) { t in
            TaskEditor(task: t) { _ in }.environmentObject(store)
        }
    }

    private func content(_ t: TaskItem) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                topBar(t)

                VStack(spacing: 6) {
                    Text(t.title)
                        .font(Theme.display(28))
                        .multilineTextAlignment(.center)
                    Text("\(t.time)–\(Day.time(t.endMinutes)) · \(Day.duration(t.dur))")
                        .font(Theme.rounded(.subheadline, .semibold))
                        .foregroundStyle(Theme.muted)
                }

                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    timerRing(t, now: ctx.date)
                }

                timerButtons(t)

                if !t.steps.isEmpty || !t.done { stepsCard(t) }

                if !t.note.isEmpty {
                    Text(t.note)
                        .font(Theme.rounded(.subheadline))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .card(radius: 16)
                }

                actions(t)
            }
            .foregroundStyle(Theme.fg)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: części

    private func topBar(_ t: TaskItem) -> some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(Theme.paper, in: Circle())
            }
            .accessibilityLabel("Zamknij tryb skupienia")
            Spacer()
            Label(t.cat.name, systemImage: t.cat.symbol)
                .font(Theme.rounded(.caption, .bold))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(t.cat.color.opacity(0.18), in: Capsule())
            Spacer()
            Button("Edytuj") { editing = t }
                .font(Theme.rounded(.subheadline, .bold))
                .frame(height: 40)
        }
        .foregroundStyle(Theme.fg)
        .padding(.top, 8)
    }

    private func timerRing(_ t: TaskItem, now: Date) -> some View {
        let state = ringState(t, now: now)
        let color = timerEnd != nil && timerLabel == "Przerwa" ? Theme.ok : t.cat.color
        return ZStack {
            Circle().stroke(Theme.line, lineWidth: 14)
            Circle()
                .trim(from: 0, to: state.progress)
                .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: state.progress)
            VStack(spacing: 4) {
                Text(state.big)
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(state.caption)
                    .font(Theme.rounded(.subheadline, .semibold))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(30)
        }
        .frame(width: 240, height: 240)
        .accessibilityElement(children: .combine)
    }

    /// Licznik: własny timer (5/25/50 min, przerwa) albo czas bloku zadania.
    private func ringState(_ t: TaskItem, now: Date) -> (progress: Double, big: String, caption: String) {
        if let end = timerEnd {
            let left = end.timeIntervalSince(now)
            if left <= 0 {
                return (1, "0:00", timerLabel == "Przerwa" ? "Koniec przerwy – wracamy? 🙂" : "Czas minął! Dalej czy przerwa? 🎉")
            }
            return (1 - left / timerTotal, clock(left), timerLabel)
        }
        if t.done { return (1, "✓", "Zrobione – brawo! ✨") }
        let start = t.startDate, end = t.endDate
        if now < start {
            let left = start.timeIntervalSince(now)
            return (0, left < 3600 ? clock(left) : Day.duration(Int(left / 60)), "do startu")
        }
        if now < end {
            let total = end.timeIntervalSince(start)
            return (now.timeIntervalSince(start) / total, clock(end.timeIntervalSince(now)), "zostało w tym bloku")
        }
        return (1, "–", "Czas bloku minął. Możesz skończyć albo przenieść.")
    }

    private func clock(_ s: TimeInterval) -> String {
        let total = Int(s.rounded(.up))
        let h = total / 3600, m = (total % 3600) / 60, sec = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    private func timerButtons(_ t: TaskItem) -> some View {
        VStack(spacing: 10) {
            if timerEnd != nil {
                Button {
                    timerEnd = nil
                    NotificationManager.shared.cancelFocusTimer()
                } label: {
                    Label("Zatrzymaj timer", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                Button { startTimer(5, label: "Tylko 5 minut – potem zdecydujesz", t) } label: {
                    Label("Tylko 5 minut", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                HStack(spacing: 10) {
                    timerChip("25 min") { startTimer(25, label: "Skupienie 25 min", t) }
                    timerChip("50 min") { startTimer(50, label: "Skupienie 50 min", t) }
                    timerChip("Przerwa") { startTimer(10, label: "Przerwa", t) }
                }
            }
        }
        .font(Theme.rounded(.headline, .bold))
        .buttonBorderShape(.capsule)
        .controlSize(.large)
    }

    private func timerChip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private func startTimer(_ minutes: Int, label: String, _ t: TaskItem) {
        let seconds = TimeInterval(minutes * 60)
        timerTotal = seconds
        timerLabel = label
        timerEnd = Date().addingTimeInterval(seconds)
        let isBreak = label == "Przerwa"
        NotificationManager.shared.scheduleFocusTimer(
            after: seconds,
            title: isBreak ? "☕️ Koniec przerwy" : "⏱ \(minutes) min minęło!",
            body: isBreak ? (Prefs.hideDetailsEnabled ? "Wracamy do zadania" : "Wracamy do: \(t.title)")
                : "Świetnie! Kontynuujesz czy chwila przerwy?"
        )
    }

    private func stepsCard(_ t: TaskItem) -> some View {
        let doneCount = t.steps.filter(\.done).count
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("MAŁE KROKI")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(Theme.muted)
                Spacer()
                if !t.steps.isEmpty {
                    Text("\(doneCount)/\(t.steps.count)")
                        .font(Theme.rounded(.caption, .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(.bottom, 4)

            ForEach(t.steps) { s in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { store.toggleStep(t.id, s.id) }
                    stepHaptic += 1
                    if !s.done && t.steps.filter({ !$0.done }).count == 1 { doneHaptic += 1 }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: s.done ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24))
                            .foregroundStyle(s.done ? t.cat.color : Theme.muted)
                        Text(s.title)
                            .font(Theme.rounded(.body, s.id == t.nextStep?.id ? .bold : .regular))
                            .strikethrough(s.done)
                            .foregroundStyle(s.done ? Theme.muted : Theme.fg)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        if s.id == t.nextStep?.id {
                            Text("teraz")
                                .font(Theme.rounded(.caption2, .heavy))
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(t.cat.color.opacity(0.18), in: Capsule())
                        }
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.muted)
                TextField(t.steps.isEmpty ? "Od czego zaczniesz? Dodaj mały krok" : "Dodaj krok", text: $newStep)
                    .font(Theme.rounded(.body))
                    .focused($stepFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { addStep(t) }
            }
            .padding(.vertical, 8)
        }
        .padding(16)
        .card(radius: 18)
    }

    private func addStep(_ t: TaskItem) {
        let title = newStep.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        withAnimation { store.addStep(t.id, title: title) }
        newStep = ""
        stepFieldFocused = true
    }

    private func actions(_ t: TaskItem) -> some View {
        VStack(spacing: 10) {
            if t.done {
                Button {
                    withAnimation { store.toggle(t.id) }
                } label: {
                    Text("Oznacz jako niezrobione").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    withAnimation { store.toggle(t.id) }
                    doneHaptic += 1
                    timerEnd = nil
                    NotificationManager.shared.cancelFocusTimer()
                } label: {
                    Label("Zrobione", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.ok)

                HStack(spacing: 10) {
                    Button {
                        store.postpone(t.id, minutes: 30)
                    } label: {
                        Text("Za 30 min").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Button {
                        store.moveToTomorrow(t.id)
                        dismiss()
                    } label: {
                        Text("Na jutro").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .font(Theme.rounded(.headline, .bold))
        .buttonBorderShape(.capsule)
        .controlSize(.large)
    }
}
