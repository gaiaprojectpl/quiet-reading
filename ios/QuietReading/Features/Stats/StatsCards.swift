import SwiftUI
import Charts
import SwiftData

// 🧱 Components › Charts: one hue per theme, values on the chart, a one-line summary under each,
// and never colour alone (the current bar is also underlined and labelled).

/// Card shell used by every chart: title, optional control on the right, content, one-line summary.
struct StatsCard<Trailing: View, Content: View>: View {
    let title: LocalizedStringKey
    var summary: String?
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            HStack(spacing: Space.s8) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(theme.palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                trailing
            }
            content
            if let summary {
                Text(summary).font(.footnote).foregroundStyle(theme.palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Space.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous).strokeBorder(theme.palette.line, lineWidth: Size.stroke))
    }
}

extension StatsCard where Trailing == EmptyView {
    init(title: LocalizedStringKey, summary: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: title, summary: summary, trailing: { EmptyView() }, content: content)
    }
}

/// Small outlined pill with a chevron ("2026 ⌄") that opens a menu.
struct PeriodMenu<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value
    @Environment(\.theme) private var theme

    var body: some View {
        Menu {
            Picker("", selection: $selection) {
                ForEach(options, id: \.value) { Text($0.title).tag($0.value) }
            }
        } label: {
            HStack(spacing: Space.s4) {
                Text(options.first { $0.value == selection }?.title ?? "").font(.caption)
                Image("qs.chevron").resizable().frame(width: Size.iconS - 4, height: Size.iconS - 4).rotationEffect(.degrees(90))
            }
            .foregroundStyle(theme.palette.ink2)
            .padding(.horizontal, Space.s8)
            .padding(.vertical, Space.s4)
            .overlay(Capsule().strokeBorder(theme.palette.line, lineWidth: Size.stroke))
            .frame(minHeight: Size.touchIos)
            .contentShape(Rectangle())
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// "Plus" pill with a crown, for Plus-only charts.
struct PlusPill: View {
    @Environment(\.theme) private var theme
    var body: some View {
        HStack(spacing: Space.s2) {
            Image("qs.crown").resizable().frame(width: Size.iconS - 4, height: Size.iconS - 4)
            Text("Plus").font(.caption2.weight(.semibold))
        }
        .foregroundStyle(theme.palette.accentInk)
        .padding(.horizontal, Space.s6)
        .padding(.vertical, Space.s2)
        .background(theme.palette.soft, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Plus")
    }
}

// MARK: - Yearly goal

struct GoalCard: View {
    let goal: ReadingStats.Goal
    let year: Int
    @Binding var selectedYear: Int
    let years: [Int]
    let onEdit: () -> Void
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title) private var ring = Size.coverM + Space.s24
    @State private var shown = 0.0

    private var fraction: Double { goal.goal > 0 ? min(1, Double(goal.done) / Double(goal.goal)) : 0 }

    private var summary: String {
        guard goal.goal > 0 else { return String(localized: "\(goal.done) books in \(String(year)). Set a goal if you'd like one.") }
        if goal.left == 0 { return String(localized: "\(goal.done) of \(goal.goal) books. You reached your goal.") }
        if year != Calendar.current.component(.year, from: .now) {
            return String(localized: "\(goal.done) of \(goal.goal) books.")
        }
        return String(localized: "\(goal.done) of \(goal.goal) books. \(goal.left) to go – on pace for \(goal.onPaceFor). No rush.")
    }

    var body: some View {
        StatsCard(title: "Yearly goal", summary: summary) {
            PeriodMenu(options: years.map { ($0, String($0)) }, selection: $selectedYear)
        } content: {
            Button(action: onEdit) {
                HStack(spacing: Space.s20) {
                    ZStack {
                        Circle().stroke(theme.palette.chartTrack, lineWidth: Space.s8)
                        Circle().trim(from: 0, to: shown)
                            .stroke(theme.palette.accent, style: StrokeStyle(lineWidth: Space.s8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text("\(goal.done)").font(theme.headline(30, relativeTo: .title)).foregroundStyle(theme.palette.ink)
                                .contentTransition(.numericText())
                            if goal.goal > 0 {
                                Text("of \(goal.goal) books").font(.caption2).foregroundStyle(theme.palette.ink2)
                            } else {
                                Text("books").font(.caption2).foregroundStyle(theme.palette.ink2)
                            }
                        }
                    }
                    .frame(width: ring, height: ring)
                    VStack(alignment: .leading, spacing: Space.s4) {
                        if goal.goal > 0 {
                            Text("\(goal.percent)%").font(theme.headline(22, relativeTo: .title2)).foregroundStyle(theme.palette.ink)
                            Text("of your goal").font(.footnote).foregroundStyle(theme.palette.ink2)
                        } else {
                            Text("Set a goal").font(.subheadline.weight(.semibold)).foregroundStyle(theme.palette.accentInk)
                        }
                        Text("≈ \(goal.perMonth.formatted(.number.precision(.fractionLength(0...1)))) books a month")
                            .font(.footnote).foregroundStyle(theme.palette.ink2)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(QsPressStyle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel(summary)
            .accessibilityHint("Edit goal")
        }
        .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: Motion.slow * 2)) { shown = fraction } }
        .onChange(of: fraction) { _, f in withAnimation(reduceMotion ? nil : .easeOut(duration: Motion.slow)) { shown = f } }
    }
}

// MARK: - Weekly rhythm

/// Flexible rhythm: any N days a week count. Rest days show a moon. Nothing ever breaks.
struct RhythmCard: View {
    let week: [ReadingStats.Day]
    @Binding var goalDays: Int
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .body) private var dot = Space.s32

    private var read: Int { week.filter(\.didRead).count }

    private var title: String {
        read >= goalDays
            ? String(localized: "\(read) of \(goalDays) days – done for the week")
            : String(localized: "\(read) of \(goalDays) days so far")
    }

    var body: some View {
        StatsCard(title: "This week’s rhythm",
                  summary: String(localized: "Flexible: any \(goalDays) days count. Rest days show a moon, never a broken streak.")) {
            PeriodMenu(options: (1...7).map { ($0, String(localized: "Goal: \($0) days")) }, selection: $goalDays)
        } content: {
            HStack(spacing: 0) {
                ForEach(week) { day in
                    let today = Calendar.current.isDateInToday(day.date)
                    VStack(spacing: Space.s4) {
                        ZStack {
                            if day.didRead {
                                Circle().fill(theme.palette.accent)
                                Image("qs.check").resizable().frame(width: Size.iconS, height: Size.iconS).foregroundStyle(theme.palette.onAccent)
                            } else if day.date > .now && !today {
                                Circle().strokeBorder(theme.palette.line, lineWidth: Size.stroke)
                            } else {
                                Image("qs.moon").resizable().frame(width: Size.iconS, height: Size.iconS).foregroundStyle(theme.palette.ink2)
                            }
                        }
                        .frame(width: dot, height: dot)
                        .overlay { if today { Circle().strokeBorder(theme.palette.ink, lineWidth: Size.stroke).padding(-Space.s2) } }
                        Text(day.date.formatted(.dateTime.weekday(.narrow))).font(.caption2).foregroundStyle(theme.palette.ink2)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide)))
                    .accessibilityValue(day.didRead ? String(localized: "Read") : String(localized: "Rest day"))
                }
            }
            Text(title).font(theme.headline(18, relativeTo: .headline)).foregroundStyle(theme.palette.ink)
        }
    }
}

// MARK: - Pages this week

struct PagesWeekCard: View {
    let week: [ReadingStats.Day]
    @Environment(\.theme) private var theme

    private var total: Int { week.map(\.pages).reduce(0, +) }
    private var today: Int { week.first { Calendar.current.isDateInToday($0.date) }?.pages ?? 0 }

    var body: some View {
        StatsCard(title: "Pages this week",
                  summary: String(localized: "\(total) pages this week. Today: \(today) pages.")) {
            Chart(week) { day in
                let isToday = Calendar.current.isDateInToday(day.date)
                BarMark(x: .value("Day", day.date, unit: .day), y: .value("Pages", day.pages), width: .ratio(0.45))
                    .foregroundStyle(isToday ? theme.palette.accent : theme.palette.chart3)
                    .clipShape(Capsule())
                    .annotation(position: .top, spacing: Space.s2) {
                        if day.pages > 0 {
                            Text("\(day.pages)").font(.caption2.weight(isToday ? .semibold : .regular)).foregroundStyle(theme.palette.ink)
                        }
                    }
            }
            .chartXAxis { dayAxis(underline: { Calendar.current.isDateInToday($0) }) }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(theme.palette.line)
                AxisValueLabel().foregroundStyle(theme.palette.ink2)
            } }
            .frame(height: Space.s80 * 1.6)
        }
    }

    private func dayAxis(underline: @escaping (Date) -> Bool) -> some AxisContent {
        AxisMarks(values: .stride(by: .day)) { value in
            AxisValueLabel(centered: true) {
                if let d = value.as(Date.self) {
                    Text(d.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2.weight(underline(d) ? .bold : .regular))
                        .underline(underline(d))
                        .foregroundStyle(theme.palette.ink2)
                }
            }
        }
    }
}

// MARK: - Reading days (calendar)

struct ReadingDaysCard: View {
    let stats: ReadingStats
    @Binding var month: Date
    @Environment(\.theme) private var theme

    private var days: [ReadingStats.Day] { stats.days(inMonthOf: month) }
    private var months: [Date] {
        let cal = Calendar.current
        let start = cal.dateInterval(of: .month, for: .now)!.start
        return (0..<12).compactMap { cal.date(byAdding: .month, value: -$0, to: start) }
    }

    private func fill(_ level: ReadingStats.Level) -> Color {
        switch level {
        case .rest: theme.palette.surface
        case .little: theme.palette.chart4
        case .more: theme.palette.chart2
        case .lots: theme.palette.accent
        }
    }

    private func ink(_ level: ReadingStats.Level) -> Color {
        level == .lots || level == .more ? theme.palette.onAccent : theme.palette.ink
    }

    var body: some View {
        let cal = Calendar.current
        let lead = ((cal.component(.weekday, from: days.first?.date ?? .now) - cal.firstWeekday) + 7) % 7
        let readCount = days.filter(\.didRead).count
        let monthName = month.formatted(.dateTime.month(.wide))
        StatsCard(title: "Reading days",
                  summary: String(localized: "You read on \(readCount) days in \(monthName). Rest days are part of reading too.")) {
            PeriodMenu(options: months.map { ($0, $0.formatted(.dateTime.month(.wide))) }, selection: $month)
        } content: {
            let columns = Array(repeating: GridItem(.flexible(), spacing: Space.s6), count: 7)
            LazyVGrid(columns: columns, spacing: Space.s6) {
                ForEach(0..<7, id: \.self) { i in
                    Text(cal.veryShortStandaloneWeekdaySymbols[(i + cal.firstWeekday - 1) % 7])
                        .font(.caption2).foregroundStyle(theme.palette.ink2)
                        .accessibilityHidden(true)
                }
                ForEach(0..<lead, id: \.self) { _ in Color.clear.frame(height: 1) }
                ForEach(days) { day in
                    let level = day.didRead ? ReadingStats.level(day.pages) : .rest
                    let today = cal.isDateInToday(day.date)
                    Text("\(cal.component(.day, from: day.date))")
                        .font(.caption2.weight(today ? .bold : .regular))
                        .foregroundStyle(ink(level))
                        .frame(maxWidth: .infinity, minHeight: Space.s24 + Space.s4)
                        .background(fill(level), in: RoundedRectangle(cornerRadius: theme.radii.inner - 2, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: theme.radii.inner - 2, style: .continuous)
                            .strokeBorder(today ? theme.palette.ink : .clear, lineWidth: Size.focusRing))
                        .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
                        .accessibilityValue(day.didRead ? String(localized: "\(day.pages) pages") : String(localized: "Rest day"))
                }
            }
            HStack(spacing: Space.s12) {
                legend(.rest, "Rest"); legend(.little, "A little"); legend(.more, "More"); legend(.lots, "Lots")
            }
            .accessibilityHidden(true)
        }
    }

    private func legend(_ level: ReadingStats.Level, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: Space.s4) {
            RoundedRectangle(cornerRadius: Space.s2).fill(fill(level))
                .overlay(RoundedRectangle(cornerRadius: Space.s2).strokeBorder(theme.palette.line))
                .frame(width: Space.s12, height: Space.s12)
            Text(text).font(.caption2).foregroundStyle(theme.palette.ink2)
        }
    }
}

// MARK: - Books per month

struct BooksPerMonthCard: View {
    let counts: [Int]
    let year: Int
    @Binding var selectedYear: Int
    let years: [Int]
    @Environment(\.theme) private var theme

    private var currentMonth: Int? {
        year == Calendar.current.component(.year, from: .now) ? Calendar.current.component(.month, from: .now) - 1 : nil
    }

    private var summary: String {
        let names = Calendar.current.standaloneMonthSymbols
        let busiest = counts.enumerated().max { $0.element < $1.element }
        var parts: [String] = []
        if let m = currentMonth {
            parts.append(String(localized: "\(names[m]): \(counts[m]) books so far."))
        }
        if let b = busiest, b.element > 0 {
            parts.append(String(localized: "Busiest month: \(names[b.offset]), \(b.element) books."))
        }
        return parts.isEmpty ? String(localized: "No finished books in \(String(year)) yet.") : parts.joined(separator: " ")
    }

    var body: some View {
        let letters = Calendar.current.veryShortStandaloneMonthSymbols
        StatsCard(title: "Books per month", summary: summary) {
            PeriodMenu(options: years.map { ($0, String($0)) }, selection: $selectedYear)
        } content: {
            Chart(Array(counts.enumerated()), id: \.offset) { item in
                let isCurrent = item.offset == currentMonth
                BarMark(x: .value("Month", "\(item.offset)"), y: .value("Books", item.element), width: .ratio(0.5))
                    .foregroundStyle(isCurrent ? theme.palette.accent : theme.palette.chart3)
                    .clipShape(Capsule())
                    .annotation(position: .top, spacing: Space.s2) {
                        if item.element > 0 {
                            Text("\(item.element)").font(.caption2.weight(isCurrent ? .semibold : .regular)).foregroundStyle(theme.palette.ink)
                        }
                    }
                    .accessibilityLabel(Calendar.current.standaloneMonthSymbols[item.offset])
                    .accessibilityValue(String(localized: "\(item.element) books"))
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let s = value.as(String.self), let i = Int(s) {
                            Text(letters[i]).font(.caption2.weight(i == currentMonth ? .bold : .regular))
                                .underline(i == currentMonth).foregroundStyle(theme.palette.ink2)
                        }
                    }
                }
            }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(theme.palette.line)
                AxisValueLabel().foregroundStyle(theme.palette.ink2)
            } }
            .frame(height: Space.s80 * 1.6)
        }
    }
}

// MARK: - Shelf of spines

/// Every finished book adds a spine in its cover colour. Tap a spine to open the book.
struct ShelfCard: View {
    let books: [Book]
    let year: Int
    let onOpen: (Book) -> Void
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .body) private var shelfHeight = Space.s80 + Space.s20

    var body: some View {
        StatsCard(title: "Your \(String(year)) shelf",
                  summary: String(localized: "Every finished book adds a spine in its cover colour. Tap a spine to open the book.")) {
            Text("\(books.count) books").font(.caption).foregroundStyle(theme.palette.ink2)
        } content: {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: Space.s2) {
                        ForEach(Array(books.enumerated()), id: \.element.persistentModelID) { index, book in
                            let pages = Double(book.pageCount ?? 300)
                            Button { onOpen(book) } label: {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(SpineColor.of(book.coverData, fallback: index.isMultiple(of: 2) ? theme.palette.chart2 : theme.palette.tintStrong))
                                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.palette.ink.opacity(0.12)))
                                    .frame(width: min(max(pages / 28, 12), 22), height: shelfHeight * (0.72 + 0.28 * Double((index * 37) % 10) / 10))
                                    .rotationEffect(.degrees(index % 7 == 4 ? -6 : 0), anchor: .bottomTrailing)
                            }
                            .buttonStyle(QsPressStyle())
                            .frame(minHeight: Size.touchIos)
                            .accessibilityLabel(book.title)
                            .accessibilityHint("Open the book")
                        }
                    }
                    .padding(.horizontal, Space.s8)
                }
                .frame(height: shelfHeight)
                // Wooden plank. No "wood" token in Figma yet, so it uses the warm theme roles.
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(colors: [theme.palette.tintStrong, theme.palette.warning],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: Space.s8)
                    .accessibilityHidden(true)
            }
        }
    }
}
