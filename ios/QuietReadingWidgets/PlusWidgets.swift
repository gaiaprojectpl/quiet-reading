import WidgetKit
import SwiftUI
import AppIntents

// Plus widgets (Figma › Widgets Final): Soft (Blush, Lilac, Butter, Sage mist), Colourful (Cover tone, Sunset, Pop),
// Large Up next, Modern "This week", Quote. Readers pick the style by editing the widget.
// Without Plus they show one calm card that opens the Plus screen.

// MARK: - Configuration

enum ReadingStyle: String, AppEnum {
    case blush, lilac, butter, sageMist, coverTone, sunset, pop

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Style"
    static let caseDisplayRepresentations: [ReadingStyle: DisplayRepresentation] = [
        .blush: "Soft · Blush", .lilac: "Soft · Lilac", .butter: "Soft · Butter", .sageMist: "Soft · Sage mist",
        .coverTone: "Colourful · Cover tone", .sunset: "Colourful · Sunset", .pop: "Colourful · Pop",
    ]

    var token: WidgetStyleID? {
        switch self {
        case .blush: .blush
        case .lilac: .lilac
        case .butter: .butter
        case .sageMist: .sageMist
        case .sunset: .sunset
        case .pop: .pop
        case .coverTone: nil
        }
    }
}

struct ReadingStyleIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Style"
    static let description = IntentDescription("Choose how your book looks.")
    @Parameter(title: "Style", default: .blush) var style: ReadingStyle
}

enum GoalStyle: String, AppEnum {
    case appTheme, blush, lilac, butter, sageMist

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Style"
    static let caseDisplayRepresentations: [GoalStyle: DisplayRepresentation] = [
        .appTheme: "App theme", .blush: "Soft · Blush (Plus)", .lilac: "Soft · Lilac (Plus)",
        .butter: "Soft · Butter (Plus)", .sageMist: "Soft · Sage mist (Plus)",
    ]

    var token: WidgetStyleID? {
        switch self {
        case .appTheme: nil
        case .blush: .blush
        case .lilac: .lilac
        case .butter: .butter
        case .sageMist: .sageMist
        }
    }
}

struct GoalStyleIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Style"
    static let description = IntentDescription("Choose how your goal looks.")
    @Parameter(title: "Style", default: .appTheme) var style: GoalStyle
}

struct StyledEntry<Intent: WidgetConfigurationIntent>: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let configuration: Intent
}

struct StyledProvider<Intent: WidgetConfigurationIntent>: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> StyledEntry<Intent> { StyledEntry(date: .now, snapshot: .preview, configuration: Intent()) }

    func snapshot(for configuration: Intent, in context: Context) async -> StyledEntry<Intent> {
        StyledEntry(date: .now, snapshot: WidgetSnapshot.load() ?? .preview, configuration: configuration)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<StyledEntry<Intent>> {
        let entry = StyledEntry(date: .now, snapshot: WidgetSnapshot.load() ?? WidgetSnapshot(), configuration: configuration)
        return Timeline(entries: [entry], policy: .after(Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))))
    }
}

// MARK: - Look

/// Resolved colours for a style; Cover tone is built from the current book's cover.
struct StylePalette {
    let background: [Color]
    let ink: Color, ink2: Color, accent: Color, track: Color, button: Color, buttonInk: Color, hairline: Color
    let family: String

    init(_ id: WidgetStyleID) {
        let p = id.palette
        background = p.background; ink = p.ink; ink2 = p.ink2; accent = p.accent; track = p.track
        button = p.button; buttonInk = p.buttonInk; hairline = p.hairline; family = id.family
    }

    /// Cover tone: the cover's colour (already deepened for contrast by the app), light text on top.
    init(coverTone hex: String?, fallback theme: ThemeID) {
        let tone = hex.flatMap { UInt32($0, radix: 16) }.map { Color(hex: $0) } ?? theme.palette.accent
        background = [tone, tone.mix(with: .black, by: 0.25)]
        ink = Color(hex: 0xFFFDF8); ink2 = Color(hex: 0xFFFDF8).opacity(0.88); accent = Color(hex: 0xFFFDF8)
        track = .white.opacity(0.25); button = Color(hex: 0xFFFDF8); buttonInk = tone.mix(with: .black, by: 0.3)
        hairline = .clear; family = "colourful"
    }
}

private struct StyledBackground: View {
    let palette: StylePalette
    var body: some View {
        LinearGradient(colors: palette.background, startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(ContainerRelativeShape().strokeBorder(palette.hairline, lineWidth: 1))
    }
}

/// Silk ribbon bookmark (from the logo) hanging from the top edge of Soft widgets.
private struct RibbonBookmark: View {
    let color: Color
    var body: some View {
        Path { p in
            p.move(to: .zero); p.addLine(to: CGPoint(x: 12, y: 0)); p.addLine(to: CGPoint(x: 12, y: 30))
            p.addLine(to: CGPoint(x: 6, y: 24)); p.addLine(to: CGPoint(x: 0, y: 30)); p.closeSubpath()
        }
        .fill(color)
        .frame(width: 12, height: 30)
        .accessibilityHidden(true)
    }
}

private struct StyledProgress: View {
    let value: Double
    let palette: StylePalette
    var height: CGFloat = 3
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.track)
                Capsule().fill(palette.accent).frame(width: max(height, geo.size.width * value)).widgetAccentable()
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

private struct StyledPlus: View {
    let bookID: String
    let palette: StylePalette
    var body: some View {
        Button(intent: UpdateBookIntent(bookID: bookID)) {
            Image(systemName: "plus").font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.buttonInk)
                .frame(width: 32, height: 32)
                .background(palette.button, in: Circle())
                .overlay(Circle().strokeBorder(palette.family == "soft" ? palette.accent : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Update my page")
    }
}

/// Without Plus: one calm card that opens the Plus screen. No dark patterns.
private struct PlusLocked: View {
    let snapshot: WidgetSnapshot
    var body: some View {
        ThemedWidget(snapshot: snapshot) { PlusLockedContent() }.widgetURL(WidgetLink.plus)
    }
}

private struct PlusLockedContent: View {
    @Environment(\.theme) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            Image(systemName: "crown").foregroundStyle(theme.palette.accentInk).accessibilityHidden(true)
            Spacer(minLength: 0)
            Text("A Plus widget").font(theme.headline(16, relativeTo: .headline)).foregroundStyle(theme.palette.ink)
            Text("Tap to see Quiet Reading Plus.").font(.caption2).foregroundStyle(theme.palette.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private func detail(_ b: WidgetSnapshot.BookItem, pageFirst: Bool) -> String {
    let pct = WidgetText.percent(b.progress)
    let page = b.currentPage > 0 ? String(localized: "p. \(b.currentPage)") : nil
    let left = WidgetText.timeLeft(b.minutesLeft)
    return (pageFirst ? [page, left] : [pct, left ?? page]).compactMap { $0 }.joined(separator: " · ")
}

// MARK: - Reading now · Plus styles (small, medium, large Up next)

struct StyledReadingWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ReadingNowPlus", intent: ReadingStyleIntent.self, provider: StyledProvider<ReadingStyleIntent>()) { entry in
            StyledReadingView(entry: entry)
        }
        .configurationDisplayName("Reading now · Plus")
        .description("Soft and Colourful styles. Large shows what's up next.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct StyledReadingView: View {
    let entry: StyledEntry<ReadingStyleIntent>
    @Environment(\.widgetFamily) private var family

    private var palette: StylePalette {
        if let token = entry.configuration.style.token { return StylePalette(token) }
        return StylePalette(coverTone: entry.snapshot.current?.coverTone, fallback: entry.snapshot.theme)
    }

    var body: some View {
        if !entry.snapshot.isPlus {
            PlusLocked(snapshot: entry.snapshot)
        } else if let book = entry.snapshot.current {
            content(book)
                .containerBackground(for: .widget) { StyledBackground(palette: palette) }
                .widgetURL(WidgetLink.book(book.id))
        } else {
            ThemedWidget(snapshot: entry.snapshot) {
                Text("Nothing in progress").font(.headline)
            }
            .widgetURL(WidgetLink.add)
        }
    }

    @ViewBuilder private func content(_ book: WidgetSnapshot.BookItem) -> some View {
        let p = palette
        switch family {
        case .systemLarge: LargeUpNext(book: book, upNext: entry.snapshot.upNext, palette: p)
        case .systemMedium: MediumStyled(book: book, palette: p, tone: entry.configuration.style == .coverTone)
        default:
            if p.family == "soft" { SmallSoft(book: book, palette: p) } else { SmallColourful(book: book, palette: p) }
        }
    }
}

private struct SmallSoft: View {
    let book: WidgetSnapshot.BookItem
    let palette: StylePalette
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                WidgetCover(book: book, width: 34)
                Spacer()
                RibbonBookmark(color: palette.accent).offset(y: -16)
            }
            Spacer(minLength: 4)
            Text(book.title).font(.custom("Newsreader", size: 15, relativeTo: .headline).weight(.medium))
                .foregroundStyle(palette.ink).lineLimit(2)
            if let v = book.progress { StyledProgress(value: v, palette: palette).padding(.vertical, 5) }
            Text(detail(book, pageFirst: false)).font(.custom("Newsreader", size: 12, relativeTo: .caption).italic())
                .foregroundStyle(palette.ink2).lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetText.label(book))
    }
}

private struct SmallColourful: View {
    let book: WidgetSnapshot.BookItem
    let palette: StylePalette
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                WidgetCover(book: book, width: 40)
                Spacer()
                if let pct = WidgetText.percent(book.progress) {
                    Text(pct).font(.custom("Newsreader", size: 26, relativeTo: .title).weight(.medium)).foregroundStyle(palette.ink)
                }
            }
            Spacer(minLength: 4)
            Text(book.title).font(.custom("Newsreader", size: 15, relativeTo: .headline).weight(.medium))
                .foregroundStyle(palette.ink).lineLimit(2)
            if let v = book.progress { StyledProgress(value: v, palette: palette, height: 4).padding(.vertical, 5) }
            Text(detail(book, pageFirst: true)).font(.system(size: 11, weight: .medium)).foregroundStyle(palette.ink2).lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetText.label(book))
    }
}

private struct MediumStyled: View {
    let book: WidgetSnapshot.BookItem
    let palette: StylePalette
    let tone: Bool
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            WidgetCover(book: book, width: 84)
            VStack(alignment: .leading, spacing: 0) {
                Text(palette.family == "soft" ? "currently reading" : "Reading now")
                    .font(.custom("Newsreader", size: 13, relativeTo: .caption).italic()).foregroundStyle(palette.ink2)
                Text(book.title).font(.custom("Newsreader", size: 18, relativeTo: .headline).weight(.medium))
                    .foregroundStyle(palette.ink).lineLimit(2).padding(.top, 2)
                if !book.author.isEmpty {
                    Text(book.author).font(.caption).foregroundStyle(palette.ink2).lineLimit(1)
                }
                Spacer(minLength: 4)
                if let v = book.progress { StyledProgress(value: v, palette: palette).padding(.bottom, 8) }
                HStack(spacing: 8) {
                    Text(tone ? [WidgetText.percent(book.progress), book.pageCount.map { String(localized: "p. \(book.currentPage) of \($0)") }].compactMap { $0 }.joined(separator: " · ")
                              : detail(book, pageFirst: false))
                        .font(palette.family == "soft" ? .custom("Newsreader", size: 13, relativeTo: .caption).italic() : .caption)
                        .foregroundStyle(palette.ink2).lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    StyledPlus(bookID: book.id, palette: palette)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if palette.family == "soft" { RibbonBookmark(color: palette.accent).offset(x: 4, y: -16) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(WidgetText.label(book))
    }
}

private struct LargeUpNext: View {
    let book: WidgetSnapshot.BookItem
    let upNext: [WidgetSnapshot.BookItem]
    let palette: StylePalette
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MediumStyled(book: book, palette: palette, tone: false).frame(height: 126)
            Rectangle().fill(Color.white.opacity(0.8)).frame(height: 1).accessibilityHidden(true)
            if !upNext.isEmpty {
                Text("up next").font(.custom("Newsreader", size: 13, relativeTo: .caption).italic()).foregroundStyle(palette.ink2)
                HStack(alignment: .top, spacing: 12) {
                    ForEach(upNext.prefix(3)) { b in
                        Link(destination: WidgetLink.book(b.id)) {
                            VStack(alignment: .leading, spacing: 6) {
                                WidgetCover(book: b, width: 44)
                                Text(b.title).font(.system(size: 11)).foregroundStyle(palette.ink).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityLabel(Text("Up next: \(b.title)"))
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - This week (Large · Modern · Graphite)

struct ThisWeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ThisWeek", provider: SnapshotProvider()) { entry in
            ThisWeekView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("This week · Plus")
        .description("Pages you read each day this week, and your book.")
        .supportedFamilies([.systemLarge])
    }
}

private struct ThisWeekView: View {
    let snapshot: WidgetSnapshot
    private let p = StylePalette(.graphite)

    var body: some View {
        if !snapshot.isPlus {
            PlusLocked(snapshot: snapshot)
        } else {
            content
                .containerBackground(for: .widget) { StyledBackground(palette: p) }
                .widgetURL(WidgetLink.stats)
        }
    }

    private var content: some View {
        let pages = snapshot.weekPages.count == 7 ? snapshot.weekPages : Array(repeating: 0, count: 7)
        let total = pages.reduce(0, +)
        let maxValue = max(pages.max() ?? 1, 1)
        let todayIndex = (Calendar.current.component(.weekday, from: .now) - Calendar.current.firstWeekday + 7) % 7
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return VStack(alignment: .leading, spacing: 0) {
            Text("THIS WEEK").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(p.ink2)
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(total)").font(.system(size: 48, weight: .light)).tracking(-1.9).foregroundStyle(p.ink)
                Text("pages").font(.subheadline).foregroundStyle(p.ink2)
            }
            .padding(.top, 4)
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(0..<7, id: \.self) { i in
                    let day = Calendar.current.date(byAdding: .day, value: i, to: start) ?? .now
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(i == todayIndex ? p.ink : p.track)
                            .frame(height: max(3, 84 * Double(pages[i]) / Double(maxValue)))
                        Text(day.formatted(.dateTime.weekday(.narrow))).font(.system(size: 10)).foregroundStyle(p.ink2)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(day.formatted(.dateTime.weekday(.wide)))
                    .accessibilityValue(String(localized: "\(pages[i]) pages"))
                }
            }
            .frame(height: 110, alignment: .bottom)
            Rectangle().fill(p.hairline).frame(height: 1).padding(.top, 16).padding(.bottom, 14).accessibilityHidden(true)
            if let book = snapshot.current {
                HStack(spacing: 12) {
                    WidgetCover(book: book, width: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(p.ink).lineLimit(1)
                        Text(detail(book, pageFirst: false)).font(.system(size: 11)).foregroundStyle(p.ink2).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(WidgetText.label(book))
                    StyledPlus(bookID: book.id, palette: p)
                }
            }
        }
    }
}

// MARK: - Quote (Medium · Plus)

struct QuoteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Quote", provider: SnapshotProvider()) { entry in
            QuoteView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Quote · Plus")
        .description("A line you saved, a new one each day.")
        .supportedFamilies([.systemMedium])
    }
}

private struct QuoteView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if !snapshot.isPlus {
            PlusLocked(snapshot: snapshot)
        } else {
            ThemedWidget(snapshot: snapshot) { QuoteContent(snapshot: snapshot) }
        }
    }
}

private struct QuoteContent: View {
    let snapshot: WidgetSnapshot
    @Environment(\.theme) private var theme

    /// One quote a day, stepping through the saved ones.
    private var quote: WidgetSnapshot.QuoteItem? {
        guard !snapshot.quotes.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
        return snapshot.quotes[day % snapshot.quotes.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Image(systemName: "quote.opening").font(.system(size: 14)).foregroundStyle(theme.palette.accentInk).accessibilityHidden(true)
            if let quote {
                Text("“\(quote.text)”").font(theme.headline(18, relativeTo: .headline)).foregroundStyle(theme.palette.ink)
                    .lineLimit(4).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Text(quote.page.map { "\(quote.book) · p. \($0)" } ?? quote.book).font(.caption2).foregroundStyle(theme.palette.ink)
            } else {
                Text("Lines you save show up here").font(theme.headline(17, relativeTo: .headline)).foregroundStyle(theme.palette.ink)
                Spacer(minLength: 0)
                Text("Add a quote from any book in Quiet Reading.").font(.caption2).foregroundStyle(theme.palette.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { theme.palette.soft }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Goal in Soft tints

struct StyledGoalView: View {
    let snapshot: WidgetSnapshot
    let style: WidgetStyleID

    var body: some View {
        let p = StylePalette(style)
        let fraction = snapshot.goal > 0 ? min(1, Double(snapshot.finishedThisYear) / Double(snapshot.goal)) : 0
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(p.track, lineWidth: 5)
                Circle().trim(from: 0, to: fraction).stroke(p.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90)).widgetAccentable()
                Text("\(snapshot.finishedThisYear)").font(.custom("Newsreader", size: 30, relativeTo: .title).weight(.medium)).foregroundStyle(p.ink)
            }
            .frame(width: 84, height: 84)
            Text(snapshot.goal > 0 ? String(localized: "of \(snapshot.goal) books in \(String(snapshot.year))")
                                   : String(localized: "books in \(String(snapshot.year))"))
                .font(.custom("Newsreader", size: 12, relativeTo: .caption).italic()).foregroundStyle(p.ink2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) { RibbonBookmark(color: p.accent).offset(y: -16) }
        .containerBackground(for: .widget) { StyledBackground(palette: p) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(snapshot.goal > 0
            ? String(localized: "\(snapshot.finishedThisYear) of \(snapshot.goal) books in \(String(snapshot.year)). No rush.")
            : String(localized: "\(snapshot.finishedThisYear) books in \(String(snapshot.year))"))
    }
}

#Preview(as: .systemMedium) { StyledReadingWidget() } timeline: {
    StyledEntry(date: .now, snapshot: .preview, configuration: ReadingStyleIntent())
}
#Preview(as: .systemLarge) { ThisWeekWidget() } timeline: { SnapshotEntry(date: .now, snapshot: .preview) }
#Preview(as: .systemMedium) { QuoteWidget() } timeline: { SnapshotEntry(date: .now, snapshot: .preview) }
