import SwiftUI

struct WeekView: View {
    @EnvironmentObject private var store: Store
    @Binding var selected: String
    var openDay: (String) -> Void

    var body: some View {
        let start = Day.startOfWeek(selected)
        let today = Day.today
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Twój tydzień")
                    .font(Theme.display(30))
                    .foregroundStyle(Theme.fg)
                    .padding(.top, 8)

                HStack {
                    shiftButton("chevron.left", -7)
                    Spacer()
                    VStack(spacing: 0) {
                        Text("\(Day.short(start)) – \(Day.short(Day.add(start, 6)))")
                            .font(Theme.display(19))
                        if let label = Seed.gymWeekLabel(start) {
                            Text("Siłownia: \(label)")
                                .font(Theme.rounded(.caption, .semibold))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    Spacer()
                    shiftButton("chevron.right", 7)
                }
                .foregroundStyle(Theme.fg)

                ForEach(0..<7, id: \.self) { i in
                    let day = Day.add(start, i)
                    dayCard(day, isToday: day == today)
                        .onTapGesture { openDay(day) }
                }

                FlowLayout(spacing: 12) {
                    ForEach(Category.allCases) { c in
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 3).fill(c.color).frame(width: 10, height: 10)
                            Text(c.name)
                        }
                        .font(Theme.rounded(.caption, .semibold))
                        .foregroundStyle(Theme.muted)
                    }
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .gesture(DragGesture(minimumDistance: 40).onEnded { v in
            guard abs(v.translation.width) > abs(v.translation.height) * 1.5 else { return }
            withAnimation(.snappy) { selected = Day.add(selected, v.translation.width < 0 ? 7 : -7) }
        })
    }

    private func shiftButton(_ symbol: String, _ days: Int) -> some View {
        Button { withAnimation(.snappy) { selected = Day.add(selected, days) } } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.muted)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(days < 0 ? "Poprzedni tydzień" : "Następny tydzień")
    }

    private func dayCard(_ day: String, isToday: Bool) -> some View {
        let list = store.tasks(on: day)
        let done = list.filter(\.done).count
        let visible = list.filter { $0.cat != .food }
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(Day.weekdayNames[Day.weekday(day)])
                    .font(Theme.rounded(.headline, .heavy))
                Text(Day.short(day) + (Seed.holidays[day].map { " · \($0)" } ?? ""))
                    .font(Theme.rounded(.subheadline, .semibold))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text("\(done)/\(list.count)")
                    .font(Theme.rounded(.subheadline, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.muted)
            }
            FlowLayout {
                if visible.isEmpty {
                    chip("wolne", color: Category.life.color, done: false)
                }
                ForEach(visible) { t in
                    chip("\(t.time) \(t.shortTitle)", color: t.cat.color, done: t.done)
                }
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule().fill(Theme.accent)
                        .frame(width: list.isEmpty ? 0 : g.size.width * CGFloat(done) / CGFloat(list.count))
                }
            }
            .frame(height: 5)
        }
        .foregroundStyle(Theme.fg)
        .padding(14)
        .card()
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.accent, lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
    }

    private func chip(_ text: String, color: Color, done: Bool) -> some View {
        Text(text)
            .font(Theme.rounded(.caption, .bold))
            .strikethrough(done)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.16), in: Capsule())
            .opacity(done ? 0.55 : 1)
    }
}
