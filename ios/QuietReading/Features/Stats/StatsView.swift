import SwiftUI
import SwiftData

/// Flow 8 / 8b · Stats. Gentle and free: goal ring, weekly rhythm, pages, reading days,
/// books per month, the shelf of spines and stamps. Patterns (moods, pace…) are Plus.
/// Goals are optional and never shame; rest days are part of reading.
struct StatsView: View {
    var onAddBook: () -> Void = {}

    @Environment(\.theme) private var theme
    @Environment(NotificationCenterModel.self) private var notifications
    @Environment(PlusAccess.self) private var plus
    @Query private var books: [Book]
    @AppStorage(ProfileKeys.goal) private var goal = 0
    @AppStorage("weeklyDaysGoal") private var weeklyDays = 4
    @AppStorage("stampsSeen") private var stampsSeen = ""
    @AppStorage(SeasonalChallenge.joinedKey) private var joined = false

    @State private var period: Period = .year
    @State private var year = Calendar.current.component(.year, from: .now)
    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)!.start
    @State private var path: [Page] = []
    @State private var editingGoal = false
    @State private var showJoin = false
    @State private var updating: Book?
    @State private var finishAfterSheet: Book?
    @State private var finishing: Book?
    @State private var shareImage: SharedImage?
    @AppStorage(ProfileKeys.name) private var name = ""
    @Environment(\.displayScale) private var displayScale

    enum Period: Hashable { case week, month, year }
    enum Page: Hashable { case stamps, year(Int), patterns, book(Book) }

    private var stats: ReadingStats { ReadingStats(books: books) }
    private var stamps: [Stamp] {
        let challenge = SeasonalChallenge(stats: stats)
        return Stamp.all(stats, autumnDone: joined && (challenge?.done ?? false))
    }
    private var currentBook: Book? { books.filter { $0.status == .reading }.max { $0.lastUpdated < $1.lastUpdated } }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s16) {
                    ScreenHeader(title: "Stats") {
                        if stats.hasAnyData { ShareImageButton(image: shareImage, caption: shareTitle) }
                    }
                    if stats.hasAnyData { content } else { empty }
                }
                .padding(.horizontal, Space.s20)
                .padding(.top, Space.s16)
                .padding(.bottom, Space.s40)
                .gentleAnimation(period)
            }
            .background(theme.palette.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Page.self) { page in
                switch page {
                case .stamps: StampsView(stats: stats)
                case .year(let y): YearInBooksView(stats: stats, year: y, onOpen: { path.append(.book($0)) })
                case .patterns: PatternsView(stats: stats)
                case .book(let b): BookDetailView(book: b)
                }
            }
            .sheet(isPresented: $editingGoal) { GoalSheet(goal: $goal, finishedThisYear: stats.finished(in: stats.currentYear).count) }
            .sheet(isPresented: $showJoin) {
                if let c = SeasonalChallenge(stats: stats) { JoinChallengeSheet(challenge: c, joined: $joined) }
            }
            .sheet(item: $updating, onDismiss: {
                if let book = finishAfterSheet { finishAfterSheet = nil; finishing = book }
            }) { book in
                UpdatePageSheet(book: book, onFinish: { finishAfterSheet = book })
            }
            .fullScreenCover(item: $finishing) { FinishFlow(book: $0) }
            .task(id: stamps.filter(\.earned).map(\.id)) { announceNewStamps() }
            // The share icon shares what's on screen (week, month or year) as a ready-made image.
            .task(id: "\(period)-\(year)-\(month)-\(books.count)-\(theme.rawValue)") { renderShare() }
            #if DEBUG
            // Test builds only: `-qsStats stamps | year | patterns | month | week`.
            .task {
                if UserDefaults.standard.bool(forKey: "qsSeedStats") { StatsSeed.run(books: books) }
                switch UserDefaults.standard.string(forKey: "qsStats") {
                case "stamps": path = [.stamps]
                case "year": path = [.year(year)]
                case "patterns": path = [.patterns]
                case "month": period = .month
                case "week": period = .week
                default: break
                }
            }
            #endif
        }
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        QsSegmented(options: [(Period.week, String(localized: "Week")),
                              (.month, String(localized: "Month")),
                              (.year, String(localized: "Year"))], selection: $period)
        let s = stats
        switch period {
        case .week:
            RhythmCard(week: s.thisWeek, goalDays: $weeklyDays)
            PagesWeekCard(week: s.thisWeek)
        case .month:
            monthTiles(s)
            ReadingDaysCard(stats: s, month: $month)
        case .year:
            GoalCard(goal: s.goal(goal, year: year), year: year, selectedYear: $year, years: s.years) { editingGoal = true }
            RhythmCard(week: s.thisWeek, goalDays: $weeklyDays)
            PagesWeekCard(week: s.thisWeek)
            ReadingDaysCard(stats: s, month: $month)
            BooksPerMonthCard(counts: s.booksPerMonth(year: year), year: year, selectedYear: $year, years: s.years)
            ShelfCard(books: s.finished(in: year), year: year) { path.append(.book($0)) }
        }
        stampsCard
        if let c = SeasonalChallenge(stats: s) { ChallengeCard(challenge: c, joined: joined) { showJoin = true } }
        QsListCard {
            QsListRow(icon: "qs.calendar", title: "Your \(String(year)) in books",
                      subtitle: "Covers, numbers and a card to share") { path.append(.year(year)) }
            QsListRow(icon: "qs.crown", title: "Patterns",
                      subtitle: plus.isUnlocked ? "Moods, pace, when you read" : "Moods, pace, when you read · Plus") { path.append(.patterns) }
        }
    }

    private func monthTiles(_ s: ReadingStats) -> some View {
        let finished = s.booksFinished(inMonthOf: month).count
        let pages = s.days(inMonthOf: month).map(\.pages).reduce(0, +)
        return HStack(spacing: Space.s12) {
            tile(value: "\(finished)", label: String(localized: "books finished"))
            tile(value: pages.formatted(), label: String(localized: "pages read"))
        }
    }

    private func tile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text(value).font(theme.headline(28, relativeTo: .title)).foregroundStyle(theme.palette.ink)
                .contentTransition(.numericText())
            Text(label).font(.footnote).foregroundStyle(theme.palette.ink2)
        }
        .padding(Space.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous).strokeBorder(theme.palette.line))
        .accessibilityElement(children: .combine)
    }

    private var stampsCard: some View {
        let all = stamps
        let firstRow = Array((all.filter(\.earned) + all.filter { !$0.earned }).prefix(4))
        return Button { path.append(.stamps) } label: {
            StatsCard(title: "Reading stamps") {
                Text("\(all.filter(\.earned).count) of \(all.count)").font(.caption).foregroundStyle(theme.palette.ink2)
            } content: {
                HStack(spacing: Space.s8) { ForEach(firstRow) { StampBadge(stamp: $0) } }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(QsPressStyle())
        .accessibilityHint("See all stamps")
    }

    // MARK: Share

    private var who: String { name.isEmpty ? String(localized: "I") : name }

    private var shareTitle: String {
        let s = stats
        switch period {
        case .week:
            let pages = s.thisWeek.map(\.pages).reduce(0, +)
            return String(localized: "\(who) read \(pages) pages this week")
        case .month:
            let n = s.booksFinished(inMonthOf: month).count
            return String(localized: "\(who) finished \(n) books in \(month.formatted(.dateTime.month(.wide)))")
        case .year:
            return String(localized: "\(who) read \(s.finished(in: year).count) books in \(String(year))")
        }
    }

    private func renderShare() {
        let s = stats
        let books: [Book]
        let detail: String
        switch period {
        case .week:
            books = currentBook.map { [$0] } ?? []
            detail = String(localized: "Read on \(s.thisWeek.filter(\.didRead).count) of 7 days")
        case .month:
            let finished = s.booksFinished(inMonthOf: month)
            books = finished.isEmpty ? (currentBook.map { [$0] } ?? []) : Array(finished.suffix(3))
            detail = String(localized: "\(s.days(inMonthOf: month).map(\.pages).reduce(0, +).formatted()) pages · \(s.days(inMonthOf: month).filter(\.didRead).count) reading days")
        case .year:
            books = Array(s.finished(in: year).suffix(3))
            detail = String(localized: "\(s.pages(in: year).formatted()) pages · \(s.newAuthors(in: year)) new authors")
        }
        shareImage = StatsShareCard.file(books: books, title: shareTitle, detail: detail, theme: theme, scale: displayScale)
    }

    // MARK: Empty (Flow 8 › No data yet)

    private var empty: some View {
        VStack(spacing: Space.s16) {
            EmptyStateView(icon: "qs.stats", title: "Your stats will grow with you",
                           message: "Update a page or finish a book and this space fills in. Nothing to catch up on.")
            // iPhone tab screens keep empty-state buttons inline (Kaja's exception).
            if let currentBook {
                Button("Update my book") { updating = currentBook }
                    .buttonStyle(QsButtonStyle(priority: .primary, size: .small)).fixedSize()
            } else {
                Button("Add a book", action: onAddBook)
                    .buttonStyle(QsButtonStyle(priority: .primary, size: .small)).fixedSize()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.s48)
    }

    // MARK: Stamp earned (quiet notification)

    private func announceNewStamps() {
        let earned = stamps.filter(\.earned)
        let seen = Set(stampsSeen.split(separator: ",").map(String.init))
        let isFirstVisit = stampsSeen.isEmpty
        stampsSeen = earned.isEmpty ? "-" : earned.map(\.id).joined(separator: ",")
        // First visit: remember what's already collected without a flurry of notifications.
        guard !isFirstVisit, let new = earned.first(where: { !seen.contains($0.id) }) else { return }
        notifications.show(String(localized: "New stamp: \(new.name)"), message: String(localized: "It’s in your stamps, kept for good."),
                           actionTitle: String(localized: "See")) { path = [.stamps] }
    }
}

#if DEBUG
/// Test builds only (`-qsSeedStats YES`): spreads reading activity over the real test books
/// so every chart has something to show. Never runs in release builds.
@MainActor
enum StatsSeed {
    static func run(books: [Book]) {
        let cal = Calendar.current
        let now = Date.now
        guard !books.contains(where: { $0.sessions.contains { cal.isDate($0.date, equalTo: now, toGranularity: .year) } }) else { return }
        let moods = ["Cozy", "Hopeful", "Slow", "Funny", "Dark"]
        let finished = books.filter { $0.status == .read }
        for (i, book) in finished.enumerated() {
            let yearBack = i % 3 == 2 ? 1 : 0
            let month = (i * 5) % (yearBack == 0 ? cal.component(.month, from: now) : 12) + 1
            book.dateFinished = cal.date(from: DateComponents(year: cal.component(.year, from: now) - yearBack, month: month, day: 3 + (i * 7) % 24, hour: 21))
            if book.moods.isEmpty { book.moods = [moods[i % moods.count], moods[(i * 3 + 1) % moods.count]] }
            if book.stars == nil { book.stars = [4, 4.5, 3.5, 5, 4, 3][i % 6] }
        }
        guard let reading = books.first(where: { $0.status == .reading }) ?? books.first else { return }
        var page = 1
        for back in stride(from: 80, through: 0, by: -1) where (back * 7) % 10 < 6 {
            guard let day = cal.date(byAdding: .day, value: -back, to: cal.startOfDay(for: now)) else { continue }
            let hour = [21, 22, 8, 13, 20, 23][back % 6]
            let pages = 8 + (back * 13) % 40
            let s = ReadingSession(date: cal.date(byAdding: .hour, value: hour, to: day)!, fromPage: page, toPage: page + pages)
            s.book = reading
            page += pages
        }
    }
}
#endif
