import SwiftUI
import Charts

/// Flow 8b › Patterns (Plus): moods, pace, time of day, ratings, this year vs last year.
/// Free readers see a soft preview with one calm way in. Basic stats stay free.
struct PatternsView: View {
    let stats: ReadingStats
    @Environment(\.theme) private var theme
    @Environment(PlusAccess.self) private var plus
    @State private var range: ReadingStats.Range = .year

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s16) {
                HStack { QsBackButton(title: "Stats"); Spacer() }
                ScreenTitle(title: "Patterns")
                QsSegmented(options: [(ReadingStats.Range.month, String(localized: "Month")),
                                      (.year, String(localized: "Year")),
                                      (.all, String(localized: "All time"))], selection: $range)
                ZStack(alignment: .top) {
                    VStack(spacing: Space.s16) {
                        moods
                        pace
                        timeOfDay
                        ratings
                        yearVsYear
                    }
                    .blur(radius: plus.isUnlocked ? 0 : 6)
                    .allowsHitTesting(plus.isUnlocked)
                    .accessibilityHidden(!plus.isUnlocked)
                    if !plus.isUnlocked { lockedCard.padding(.top, Space.s48) }
                }
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s8)
            .padding(.bottom, Space.s24)
            .gentleAnimation(range)
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var lockedCard: some View {
        VStack(spacing: Space.s12) {
            Text("Your patterns live in Plus").font(theme.headline(22, relativeTo: .title2)).foregroundStyle(theme.palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Moods, pace, when you read, ratings and year vs year. Basic stats stay free.")
                .font(.subheadline).foregroundStyle(theme.palette.ink2).multilineTextAlignment(.center)
            Button("See Plus") { plus.showPaywall = true }
                .buttonStyle(QsButtonStyle(priority: .primary, size: .small))
                .fixedSize()
        }
        .padding(Space.s24)
        .frame(maxWidth: .infinity)
        .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
        .shadow(color: theme.palette.scrim.opacity(0.12), radius: 12, y: 6)
    }

    private var rangeName: String {
        switch range {
        case .month: String(localized: "this month")
        case .year: String(localized: "this year")
        case .all: String(localized: "so far")
        }
    }

    // MARK: Moods (donut)

    private var moodColors: [Color] { [theme.palette.accent, theme.palette.chart2, theme.palette.chart3, theme.palette.chart4, theme.palette.tintStrong] }

    private var moods: some View {
        let data = Array(stats.moods(in: range).prefix(5))
        let total = max(1, data.map(\.value).reduce(0, +))
        let pct = { (v: Int) in Int((Double(v) / Double(total) * 100).rounded()) }
        let summary = data.isEmpty
            ? String(localized: "Add moods when you finish a book and they gather here.")
            : String(localized: "Mostly \(data[0].name.lowercased()) (\(pct(data[0].value))%) \(rangeName).")
        return StatsCard(title: "Moods", summary: summary) { PlusPill() } content: {
            if !data.isEmpty {
                HStack(spacing: Space.s20) {
                    Chart(Array(data.enumerated()), id: \.element.id) { i, m in
                        SectorMark(angle: .value("Books", m.value), innerRadius: .ratio(0.62), angularInset: 1.5)
                            .foregroundStyle(moodColors[i % moodColors.count])
                    }
                    .chartBackground { _ in
                        VStack(spacing: 0) {
                            Text("\(pct(data[0].value))%").font(theme.headline(18, relativeTo: .headline)).foregroundStyle(theme.palette.ink)
                            Text(data[0].name).font(.caption2).foregroundStyle(theme.palette.ink2)
                        }
                    }
                    .frame(width: Space.s80 + Space.s20, height: Space.s80 + Space.s20)
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Space.s6) {
                        ForEach(Array(data.enumerated()), id: \.element.id) { i, m in
                            HStack(spacing: Space.s6) {
                                RoundedRectangle(cornerRadius: 2).fill(moodColors[i % moodColors.count]).frame(width: Space.s8, height: Space.s8)
                                Text(m.name).font(.caption).foregroundStyle(theme.palette.ink)
                                Spacer()
                                Text("\(pct(m.value))%").font(.caption).foregroundStyle(theme.palette.ink2)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }

    // MARK: Reading pace (area)

    private var pace: some View {
        let data = stats.pace()
        let last = data.last?.perDay ?? 0
        let first = data.first?.perDay ?? 0
        let summary = String(localized: "Average \(Int(last.rounded())) pages a day this week, \(Int(first.rounded())) twelve weeks ago.")
        return StatsCard(title: "Reading pace", summary: summary) { PlusPill() } content: {
            Chart(data) { w in
                AreaMark(x: .value("Week", w.start), y: .value("Pages a day", w.perDay))
                    .foregroundStyle(theme.palette.chart4)
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Week", w.start), y: .value("Pages a day", w.perDay))
                    .foregroundStyle(theme.palette.accent)
                    .interpolationMethod(.monotone)
            }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(theme.palette.line); AxisValueLabel().foregroundStyle(theme.palette.ink2)
            } }
            .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated)).foregroundStyle(theme.palette.ink2)
            } }
            .frame(height: Space.s80 * 1.4)
            .overlay(alignment: .topTrailing) {
                Text("\(Int(last.rounded())) p/day").font(.caption2.weight(.semibold)).foregroundStyle(theme.palette.onAccent)
                    .padding(.horizontal, Space.s6).padding(.vertical, Space.s2)
                    .background(theme.palette.accent, in: Capsule())
            }
        }
    }

    // MARK: When you read

    private var timeOfDay: some View {
        let data = stats.timeOfDay(in: range)
        let total = max(1, data.map(\.value).reduce(0, +))
        let top = data.max { $0.value < $1.value }
        let summary = (top?.value ?? 0) > 0
            ? String(localized: "Mostly in the \(top!.name.lowercased()).")
            : String(localized: "Update your page now and then, and your reading times show up here.")
        return StatsCard(title: "When you read", summary: summary) { PlusPill() } content: {
            VStack(spacing: Space.s8) {
                ForEach(data) { item in
                    let share = Double(item.value) / Double(total)
                    let isTop = item.id == top?.id && item.value > 0
                    HStack(spacing: Space.s12) {
                        Text(item.name).font(.caption).foregroundStyle(theme.palette.ink)
                            .frame(width: Space.s80, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(theme.palette.chartTrack)
                                Capsule().fill(isTop ? theme.palette.accent : theme.palette.chart3)
                                    .frame(width: max(geo.size.width * share, share > 0 ? Space.s8 : 0))
                            }
                        }
                        .frame(height: Space.s8)
                        Text("\(Int((share * 100).rounded()))%").font(.caption.weight(isTop ? .semibold : .regular))
                            .foregroundStyle(theme.palette.ink).frame(width: Space.s40, alignment: .trailing)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(item.name)
                    .accessibilityValue("\(Int((share * 100).rounded()))%")
                }
            }
        }
    }

    // MARK: Ratings

    private var ratings: some View {
        let data = stats.ratings(in: range)
        let top = data.max { $0.count < $1.count }
        let label = { (s: Double) in s.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(s))" : "\(Int(s))½" }
        let summary = (top?.count ?? 0) > 0
            ? String(localized: "Most books get \(label(top!.stars)) stars.")
            : String(localized: "Rate a book when you finish it and your ratings gather here.")
        return StatsCard(title: "Your ratings", summary: summary) { PlusPill() } content: {
            Chart(data, id: \.stars) { item in
                let isTop = item.stars == top?.stars && item.count > 0
                BarMark(x: .value("Stars", label(item.stars)), y: .value("Books", item.count), width: .ratio(0.5))
                    .foregroundStyle(isTop ? theme.palette.accent : theme.palette.chart3)
                    .clipShape(Capsule())
                    .annotation(position: .top, spacing: Space.s2) {
                        if item.count > 0 { Text("\(item.count)").font(.caption2).foregroundStyle(theme.palette.ink) }
                    }
            }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(theme.palette.line); AxisValueLabel().foregroundStyle(theme.palette.ink2)
            } }
            .chartXAxis { AxisMarks { AxisValueLabel().foregroundStyle(theme.palette.ink2) } }
            .frame(height: Space.s80 * 1.4)
        }
    }

    // MARK: Year vs year

    private var yearVsYear: some View {
        let y = stats.currentYear
        let now = stats.cumulative(year: y)
        let before = stats.cumulative(year: y - 1)
        let thisSoFar = now.last ?? 0
        let lastAtSameTime = before.count >= now.count ? before[max(0, now.count - 1)] : (before.last ?? 0)
        let diff = thisSoFar - lastAtSameTime
        let summary = diff == 0
            ? String(localized: "\(thisSoFar) books so far – the same as this time last year.")
            : diff > 0 ? String(localized: "\(thisSoFar) books so far – \(diff) more than this time last year.")
                       : String(localized: "\(thisSoFar) books so far – \(-diff) fewer than this time last year. Every year reads differently.")
        let points = now.enumerated().map { (id: "a\($0.offset)", series: String(y), month: $0.offset + 1, value: $0.element) }
            + before.enumerated().map { (id: "b\($0.offset)", series: String(y - 1), month: $0.offset + 1, value: $0.element) }
        return StatsCard(title: "\(String(y)) vs \(String(y - 1))", summary: summary) { PlusPill() } content: {
            Chart(points, id: \.id) { p in
                LineMark(x: .value("Month", p.month), y: .value("Books", p.value), series: .value("Year", p.series))
                    .foregroundStyle(p.series == String(y) ? theme.palette.accent : theme.palette.chart2)
                    .lineStyle(p.series == String(y) ? StrokeStyle(lineWidth: 2.5) : StrokeStyle(lineWidth: 2, dash: [5, 4]))
            }
            .chartXScale(domain: 1...12)
            .chartXAxis { AxisMarks(values: [1, 6, 12]) { v in
                AxisValueLabel { if let m = v.as(Int.self) { Text(Calendar.current.shortMonthSymbols[m - 1]) } }
                    .foregroundStyle(theme.palette.ink2)
            } }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(theme.palette.line); AxisValueLabel().foregroundStyle(theme.palette.ink2)
            } }
            .chartLegend(.hidden)
            .frame(height: Space.s80 * 1.4)
            HStack(spacing: Space.s16) {
                legend(solid: true, "\(String(y)) · \(thisSoFar) books")
                legend(solid: false, "\(String(y - 1)) · \(before.last ?? 0) books")
            }
        }
    }

    private func legend(solid: Bool, _ text: String) -> some View {
        HStack(spacing: Space.s6) {
            Path { p in p.move(to: .init(x: 0, y: 1)); p.addLine(to: .init(x: 16, y: 1)) }
                .stroke(solid ? theme.palette.accent : theme.palette.chart2,
                        style: solid ? StrokeStyle(lineWidth: 2.5) : StrokeStyle(lineWidth: 2, dash: [4, 3]))
                .frame(width: 16, height: 2)
            Text(text).font(.caption).foregroundStyle(theme.palette.ink2)
        }
    }
}
