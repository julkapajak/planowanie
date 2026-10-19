import SwiftUI
import UserNotifications

struct DayView: View {
    @EnvironmentObject private var store: Store
    @Binding var selected: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Prefs.notify) private var notifyOn = false
    @AppStorage("bannerDismissed") private var bannerDismissed = false

    @State private var editing: TaskItem?
    @State private var addingNew = false
    @State private var toast: String?
    @State private var confettiID: UUID?
    @State private var authStatus: UNAuthorizationStatus = .authorized
    @State private var hapticTrigger = 0

    private let cheers = ["Brawo! ✨", "Jedno z głowy 💪", "Tak trzymaj!", "Pięknie idzie 🌟", "Kolejne odhaczone ✓", "Super robota!"]

    var body: some View {
        TimelineView(.everyMinute) { ctx in
            let now = ctx.date
            let list = store.tasks(on: selected)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(list: list, now: now)
                    DayStrip(selected: $selected)
                    if authStatus == .notDetermined && !notifyOn && !bannerDismissed { notifyBanner }
                    if selected == Day.key(now) { NextCard(tasks: list, now: now) }
                    if list.isEmpty {
                        Text("Wolny dzień. Odpocznij 🌿")
                            .font(Theme.rounded(.title3, .semibold))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }
                    LazyVStack(spacing: 10) {
                        ForEach(list) { t in
                            TaskRow(task: t, isNow: isNow(t, now)) { toggle(t) }
                                .onTapGesture { editing = t }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 96)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.bg.ignoresSafeArea())
        .overlay(alignment: .bottomTrailing) { fab }
        .overlay(alignment: .top) { toastView }
        .overlay {
            if let id = confettiID { ConfettiView().id(id) }
        }
        .sensoryFeedback(.success, trigger: hapticTrigger)
        .sheet(item: $editing) { t in
            TaskEditor(task: t) { msg in show(msg) }.environmentObject(store)
        }
        .sheet(isPresented: $addingNew) {
            TaskEditor(task: nil, defaultDate: selected) { msg in show(msg) }.environmentObject(store)
        }
        .task { authStatus = await NotificationManager.shared.authorizationStatus() }
    }

    // MARK: części

    private func header(list: [TaskItem], now: Date) -> some View {
        let done = list.filter(\.done).count
        let pct = list.isEmpty ? 0 : Double(done) / Double(list.count)
        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting(now))
                    .font(Theme.rounded(.subheadline, .semibold))
                    .foregroundStyle(Theme.muted)
                Text("\(relativeName(now)), \(Day.long(selected))")
                    .font(Theme.display(26))
                    .foregroundStyle(Theme.fg)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 12)
            ProgressRing(progress: pct)
                .frame(width: 56, height: 56)
        }
        .padding(.top, 8)
    }

    private var notifyBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🔔 Włączyć przypomnienia przed każdym zadaniem?")
                .font(Theme.rounded(.subheadline, .bold))
            HStack {
                Button("Włącz") {
                    Task {
                        let ok = await NotificationManager.shared.requestPermission()
                        notifyOn = ok
                        authStatus = await NotificationManager.shared.authorizationStatus()
                        store.refreshNotifications()
                        show(ok ? "Przypomnienia włączone 🔔" : "Bez zgody nie mogę przypominać")
                    }
                }
                .buttonStyle(.borderedProminent)
                Button("Później") { bannerDismissed = true }
                    .buttonStyle(.bordered)
            }
            .font(Theme.rounded(.subheadline, .bold))
            .buttonBorderShape(.capsule)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var fab: some View {
        Button { addingNew = true } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(Theme.accent, in: Circle())
                .shadow(color: Theme.accent.opacity(0.45), radius: 12, y: 6)
        }
        .accessibilityLabel("Dodaj zadanie")
        .padding(.trailing, 18)
        .padding(.bottom, 14)
    }

    @ViewBuilder private var toastView: some View {
        if let toast {
            Text(toast)
                .font(Theme.rounded(.subheadline, .bold))
                .foregroundStyle(Theme.bg)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(Theme.fg, in: Capsule())
                .padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: logika

    private func toggle(_ t: TaskItem) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { store.toggle(t.id) }
        guard !t.done else { return }
        hapticTrigger += 1
        let p = store.progress(on: t.date)
        if p.done == p.total {
            show("Cały dzień odhaczony! 🎉")
            if !reduceMotion {
                let id = UUID()
                confettiID = id
                Task {
                    try? await Task.sleep(nanoseconds: 3_200_000_000)
                    if confettiID == id { confettiID = nil }
                }
            }
        } else {
            show(cheers.randomElement()!)
        }
    }

    private func show(_ msg: String) {
        withAnimation(.spring) { toast = msg }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeOut) { if toast == msg { toast = nil } }
        }
    }

    private func isNow(_ t: TaskItem, _ now: Date) -> Bool {
        guard t.date == Day.key(now), !t.done else { return false }
        let m = Day.nowMinutes(now)
        return t.startMinutes <= m && m < t.endMinutes
    }

    private func greeting(_ now: Date) -> String {
        let h = Day.calendar.component(.hour, from: now)
        switch h {
        case ..<5: return "Dobranoc 🌙"
        case ..<12: return "Dzień dobry ☀️"
        case ..<18: return "Miłego popołudnia 🌤"
        default: return "Dobry wieczór 🌙"
        }
    }

    private func relativeName(_ now: Date) -> String {
        let today = Day.key(now)
        if selected == today { return "Dziś" }
        if selected == Day.add(today, 1) { return "Jutro" }
        if selected == Day.add(today, -1) { return "Wczoraj" }
        return Day.weekdayNames[Day.weekday(selected)]
    }
}

// MARK: - Komponenty

struct ProgressRing: View {
    var progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(Theme.line, lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            Text("\(Int((progress * 100).rounded()))%")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.fg)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Postęp dnia \(Int(progress * 100)) procent")
    }
}

struct DayStrip: View {
    @EnvironmentObject private var store: Store
    @Binding var selected: String

    var body: some View {
        let start = Day.startOfWeek(selected)
        let today = Day.today
        HStack(spacing: 2) {
            arrow("chevron.left", label: "Poprzedni tydzień") { selected = Day.add(selected, -7) }
            ForEach(0..<7, id: \.self) { i in
                let day = Day.add(start, i)
                let cats = categories(on: day)
                Button {
                    withAnimation(.snappy) { selected = day }
                } label: {
                    VStack(spacing: 3) {
                        Text(Day.weekdayShort[Day.weekday(day)].uppercased())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.muted)
                        Text("\(Day.dayNumber(day))")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(day == today ? Theme.accent : Theme.fg)
                        HStack(spacing: 2) {
                            ForEach(cats, id: \.self) { c in
                                Circle().fill(c.color).frame(width: 5, height: 5)
                            }
                        }
                        .frame(height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if day == selected {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.paper)
                                .shadow(color: .black.opacity(0.07), radius: 8, y: 3)
                        }
                    }
                    .opacity(day < today && day != selected ? 0.55 : 1)
                }
                .buttonStyle(.plain)
            }
            arrow("chevron.right", label: "Następny tydzień") { selected = Day.add(selected, 7) }
        }
        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
            guard abs(v.translation.width) > abs(v.translation.height) else { return }
            withAnimation(.snappy) { selected = Day.add(selected, v.translation.width < 0 ? 7 : -7) }
        })
    }

    /// Kolorowe kropki pod dniem: do 4 różnych kategorii w kolejności z planu.
    private func categories(on day: String) -> [Category] {
        var seen = Set<Category>()
        return Array(store.tasks(on: day).map(\.cat).filter { seen.insert($0).inserted }.prefix(4))
    }

    private func arrow(_ name: String, label: String, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.snappy) { action() } } label: {
            Image(systemName: name)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.muted)
                .frame(width: 26, height: 44)
        }
        .accessibilityLabel(label)
    }
}

struct NextCard: View {
    let tasks: [TaskItem]
    let now: Date

    var body: some View {
        let m = Day.nowMinutes(now)
        let open = tasks.filter { !$0.done }
        let current = open.first { $0.startMinutes <= m && m < $0.endMinutes }
        let next = open.first { $0.startMinutes > m }

        if !tasks.isEmpty && open.isEmpty {
            content(kicker: "Dzień zamknięty", title: "Wszystko zrobione 🎉", sub: "Reszta dnia jest Twoja.",
                    colors: [Theme.ok, Category.par.color])
        } else if let t = current ?? next {
            let left = current != nil ? t.endMinutes - m : t.startMinutes - m
            let sub = current != nil ? "jeszcze \(Day.duration(left))"
                : left < 60 ? "za \(left) min" : "o \(t.time) · za \(Day.duration(left))"
            content(kicker: current != nil ? "Teraz" : "Następne", title: t.title, sub: sub,
                    colors: [t.cat.color, t.cat.color.opacity(0.75)], symbol: t.cat.symbol)
        }
    }

    private func content(kicker: String, title: String, sub: String, colors: [Color], symbol: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(kicker.uppercased())
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(1)
                .opacity(0.85)
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol) }
                Text(title).lineLimit(2)
            }
            .font(Theme.display(21))
            Text(sub)
                .font(Theme.rounded(.subheadline, .semibold))
                .opacity(0.9)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background {
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(.white.opacity(0.12)).frame(width: 130, height: 130).offset(x: 40, y: -50)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .shadow(color: colors[0].opacity(0.3), radius: 12, y: 6)
    }
}

struct TaskRow: View {
    let task: TaskItem
    let isNow: Bool
    let onToggle: () -> Void

    var body: some View {
        let c = task.cat.color
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(task.time)
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .monospacedDigit()
                Text(Day.duration(task.dur))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.muted)
            }
            .frame(width: 52, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(Theme.rounded(.body, .bold))
                    .strikethrough(task.done, color: c)
                if !task.note.isEmpty {
                    Text(task.note)
                        .font(Theme.rounded(.footnote))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onToggle) {
                ZStack {
                    Circle().strokeBorder(c, lineWidth: 2.5)
                    if task.done {
                        Circle().fill(c)
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 34, height: 34)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.done ? "Odznacz \(task.title)" : "Oznacz jako zrobione: \(task.title)")
        }
        .foregroundStyle(Theme.fg)
        .padding(.vertical, 12)
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .background(alignment: .leading) {
            ZStack(alignment: .leading) {
                Theme.paper
                c.frame(width: 5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .overlay {
            if isNow {
                RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(c, lineWidth: 2)
            }
        }
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        .opacity(task.done ? 0.55 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}
