import SwiftUI
import CoreImage
import SwiftData

/// Flow 8 / 8b · Everything the Stats screens show, worked out from the books on this phone.
/// Pages read per day come from progress updates (`ReadingSession`); finished books count on their finish date.
struct ReadingStats {
    let books: [Book]
    let now: Date
    let calendar: Calendar

    init(books: [Book], now: Date = .now, calendar: Calendar = .current) {
        self.books = books
        self.now = now
        self.calendar = calendar
    }

    var currentYear: Int { calendar.component(.year, from: now) }
    var hasAnyData: Bool { !finished.isEmpty || !sessions.isEmpty }

    // MARK: Raw material

    var finished: [Book] { books.filter { $0.status == .read && $0.dateFinished != nil } }
    var sessions: [ReadingSession] { books.flatMap(\.sessions) }

    func finished(in year: Int) -> [Book] {
        finished.filter { calendar.component(.year, from: $0.dateFinished!) == year }
            .sorted { $0.dateFinished! < $1.dateFinished! }
    }

    /// Years that have something to show, newest first (always includes this year).
    var years: [Int] {
        Set(finished.map { calendar.component(.year, from: $0.dateFinished!) } + [currentYear]).sorted(by: >)
    }

    /// Pages read per day (start of day → pages).
    var pagesByDay: [Date: Int] {
        var result: [Date: Int] = [:]
        for s in sessions {
            result[calendar.startOfDay(for: s.date), default: 0] += max(0, s.toPage - s.fromPage)
        }
        for b in finished where b.sessions.isEmpty {
            // A finished book with no updates still marks the day it was finished.
            result[calendar.startOfDay(for: b.dateFinished!), default: 0] += 0
        }
        return result
    }

    /// What was read on one day: each book with its pages that day, and whether it was finished then.
    struct DayRead: Identifiable { let book: Book; let pages: Int; let finished: Bool; var id: PersistentIdentifier { book.persistentModelID } }

    func reading(on day: Date) -> [DayRead] {
        var result: [PersistentIdentifier: DayRead] = [:]
        for b in books {
            let pages = b.sessions.filter { calendar.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + max(0, $1.toPage - $1.fromPage) }
            let done = b.status == .read && b.dateFinished.map { calendar.isDate($0, inSameDayAs: day) } == true
            let touched = pages > 0 || done || b.sessions.contains { calendar.isDate($0.date, inSameDayAs: day) }
            if touched { result[b.persistentModelID] = DayRead(book: b, pages: pages, finished: done) }
        }
        return result.values.sorted { $0.pages > $1.pages }
    }

    // MARK: Goal

    struct Goal {
        let goal: Int, done: Int, perMonth: Double, onPaceFor: Int
        var percent: Int { goal > 0 ? Int((Double(done) / Double(goal) * 100).rounded()) : 0 }
        var left: Int { max(0, goal - done) }
    }

    func goal(_ target: Int, year: Int) -> Goal {
        let done = finished(in: year).count
        let isThisYear = year == currentYear
        let monthsElapsed = isThisYear ? Double(calendar.component(.month, from: now)) : 12
        let dayOfYear = isThisYear ? Double(calendar.ordinality(of: .day, in: .year, for: now) ?? 365) : 365
        let daysInYear = Double(calendar.range(of: .day, in: .year, for: now)?.count ?? 365)
        let pace = isThisYear ? Int((Double(done) / max(dayOfYear, 1) * daysInYear).rounded()) : done
        return Goal(goal: target, done: done, perMonth: Double(done) / monthsElapsed, onPaceFor: pace)
    }

    // MARK: Week

    struct Day: Identifiable { let date: Date; let pages: Int; let didRead: Bool; var id: Date { date } }

    /// The current week, first weekday first (Monday in most of Europe, Sunday in the US).
    var thisWeek: [Day] {
        let byDay = pagesByDay
        let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        return (0..<7).compactMap { offset in
            guard let d = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return Day(date: d, pages: byDay[d] ?? 0, didRead: byDay[d] != nil)
        }
    }

    // MARK: Month

    enum Level: Int, CaseIterable { case rest, little, more, lots }

    static func level(_ pages: Int?) -> Level {
        guard let pages else { return .rest }
        switch pages {
        case ..<20: return .little
        case ..<50: return .more
        default: return .lots
        }
    }

    /// Days of the month containing `month`, with how much was read.
    func days(inMonthOf month: Date) -> [Day] {
        let byDay = pagesByDay
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let count = calendar.range(of: .day, in: .month, for: month)?.count else { return [] }
        return (0..<count).compactMap { offset in
            guard let d = calendar.date(byAdding: .day, value: offset, to: interval.start) else { return nil }
            return Day(date: d, pages: byDay[d] ?? 0, didRead: byDay[d] != nil)
        }
    }

    func booksFinished(inMonthOf month: Date) -> [Book] {
        finished.filter { calendar.isDate($0.dateFinished!, equalTo: month, toGranularity: .month) }
    }

    // MARK: Year

    /// Finished books per month (index 0 = January).
    func booksPerMonth(year: Int) -> [Int] {
        var counts = Array(repeating: 0, count: 12)
        for b in finished(in: year) { counts[calendar.component(.month, from: b.dateFinished!) - 1] += 1 }
        return counts
    }

    func pages(in year: Int) -> Int { finished(in: year).compactMap(\.pageCount).reduce(0, +) }

    /// Authors finished this year that weren't finished in any earlier year.
    func newAuthors(in year: Int) -> Int {
        let before = Set(finished.filter { calendar.component(.year, from: $0.dateFinished!) < year }.map { $0.author.lowercased() })
        return Set(finished(in: year).map { $0.author.lowercased() }).subtracting(before).count
    }

    func favourite(in year: Int) -> Book? {
        finished(in: year).filter { $0.stars != nil || $0.rating != nil }
            .max { ($0.stars ?? Double($0.rating ?? 0)) < ($1.stars ?? Double($1.rating ?? 0)) }
    }

    func topMood(in year: Int) -> String? {
        let counts = Dictionary(finished(in: year).flatMap(\.moods).map { ($0, 1) }, uniquingKeysWith: +)
        return counts.max { $0.value < $1.value }?.key
    }

    // MARK: Patterns (Plus)

    enum Range: String, CaseIterable { case month, year, all }

    func finished(in range: Range) -> [Book] {
        switch range {
        case .month: finished.filter { calendar.isDate($0.dateFinished!, equalTo: now, toGranularity: .month) }
        case .year: finished(in: currentYear)
        case .all: finished
        }
    }

    func sessions(in range: Range) -> [ReadingSession] {
        switch range {
        case .month: sessions.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
        case .year: sessions.filter { calendar.component(.year, from: $0.date) == currentYear }
        case .all: sessions
        }
    }

    struct Share: Identifiable { let name: String; let value: Int; var id: String { name } }

    /// Moods tagged on finished books, most common first.
    func moods(in range: Range) -> [Share] {
        let counts = Dictionary(finished(in: range).flatMap(\.moods).map { ($0, 1) }, uniquingKeysWith: +)
        return counts.map { Share(name: $0.key, value: $0.value) }.sorted { $0.value > $1.value }
    }

    /// Pages read by time of day.
    func timeOfDay(in range: Range) -> [Share] {
        var buckets = [0, 0, 0, 0]
        for s in sessions(in: range) {
            let hour = calendar.component(.hour, from: s.date)
            let i = (5..<12).contains(hour) ? 0 : (12..<17).contains(hour) ? 1 : (17..<22).contains(hour) ? 2 : 3
            buckets[i] += max(1, s.toPage - s.fromPage)
        }
        let names = [String(localized: "Morning"), String(localized: "Afternoon"), String(localized: "Evening"), String(localized: "Night")]
        return zip(names, buckets).map { Share(name: $0, value: $1) }
    }

    struct WeekPace: Identifiable { let start: Date; let perDay: Double; var id: Date { start } }

    /// Average pages a day for each of the last `weeks` weeks.
    func pace(weeks: Int = 12) -> [WeekPace] {
        let byDay = pagesByDay
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        return (0..<weeks).reversed().compactMap { back in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -back, to: thisWeek) else { return nil }
            let pages = (0..<7).reduce(0) { sum, d in
                sum + (calendar.date(byAdding: .day, value: d, to: start).flatMap { byDay[$0] } ?? 0)
            }
            return WeekPace(start: start, perDay: Double(pages) / 7)
        }
    }

    /// How many books got each star value (1, 1½ … 5).
    func ratings(in range: Range) -> [(stars: Double, count: Int)] {
        let values = finished(in: range).compactMap { $0.stars ?? $0.rating.map(Double.init) }
        return stride(from: 1.0, through: 5.0, by: 0.5).map { s in (s, values.filter { $0 == s }.count) }
    }

    /// Running total of finished books per month, this year and last year.
    func cumulative(year: Int) -> [Int] {
        var total = 0
        let lastMonth = year == currentYear ? calendar.component(.month, from: now) : 12
        return booksPerMonth(year: year).prefix(lastMonth).map { total += $0; return total }
    }
}

// MARK: - Stamps

/// "Collect, don't compete": stamps never expire and nothing resets.
struct Stamp: Identifiable {
    let id: String
    let icon: String
    let name: String
    /// How to get it (shown while it's still locked) or what it was for.
    let how: String
    let earned: Bool
    /// Progress towards a countable stamp (e.g. 7 of 10 books), nil when it isn't countable.
    var progress: (current: Int, target: Int)? = nil

    /// The next stamp to collect: the locked one closest to done.
    static func next(_ all: [Stamp]) -> Stamp? {
        all.filter { !$0.earned && $0.progress != nil }
            .max { a, b in
                Double(a.progress!.current) / Double(a.progress!.target) < Double(b.progress!.current) / Double(b.progress!.target)
            }
    }

    static func all(_ stats: ReadingStats, autumnDone: Bool) -> [Stamp] {
        let cal = stats.calendar
        let pagesRead = stats.pagesByDay.values.reduce(0, +) + stats.finished.filter { $0.sessions.isEmpty }.compactMap(\.pageCount).reduce(0, +)
        func nights(_ hours: ClosedRange<Int>) -> Int {
            Set(stats.sessions.filter { hours.contains(cal.component(.hour, from: $0.date)) }.map { cal.startOfDay(for: $0.date) }).count
        }
        let lateNights = Set(stats.sessions.filter { let h = cal.component(.hour, from: $0.date); return h >= 23 || h < 4 }
            .map { cal.startOfDay(for: $0.date) }).count
        let moods = Set(stats.books.flatMap(\.moods)).count
        let rated = stats.books.filter { $0.stars != nil || $0.rating != nil }.count
        let authors = Set(stats.finished.map { $0.author.lowercased() }).count
        let fullWeek = stats.thisWeek.allSatisfy(\.didRead)
        return [
            Stamp(id: "first", icon: "qs.book", name: String(localized: "First book"),
                  how: String(localized: "Finish your first book."), earned: !stats.finished.isEmpty),
            Stamp(id: "pages1000", icon: "qs.file", name: String(localized: "1,000 pages"),
                  how: String(localized: "Read 1,000 pages in all."), earned: pagesRead >= 1000, progress: (min(pagesRead, 1000), 1000)),
            Stamp(id: "nightowl", icon: "qs.moon", name: String(localized: "Night owl"),
                  how: String(localized: "Read after 11 pm on 5 nights."), earned: lateNights >= 5, progress: (min(lateNights, 5), 5)),
            Stamp(id: "quote", icon: "qs.quote", name: String(localized: "First quote"),
                  how: String(localized: "Save a line you loved."), earned: stats.books.contains { !$0.quotes.isEmpty }),
            Stamp(id: "long", icon: "qs.flash", name: String(localized: "500+ pages"),
                  how: String(localized: "Finish a book with 500 pages or more."), earned: stats.finished.contains { ($0.pageCount ?? 0) >= 500 }),
            Stamp(id: "moods", icon: "qs.heart", name: String(localized: "5 moods"),
                  how: String(localized: "Tag 5 different moods on your books."), earned: moods >= 5, progress: (min(moods, 5), 5)),
            Stamp(id: "autumn", icon: "qs.calendar", name: String(localized: "Autumn reads"),
                  how: String(localized: "Finish the Cozy autumn challenge."), earned: autumnDone),
            Stamp(id: "reviews", icon: "qs.star-empty", name: String(localized: "10 reviews"),
                  how: String(localized: "Rate 10 books."), earned: rated >= 10, progress: (min(rated, 10), 10)),
            Stamp(id: "earlybird", icon: "qs.bell", name: String(localized: "Early bird"),
                  how: String(localized: "Read before 8 am on 5 mornings."), earned: nights(4...7) >= 5, progress: (min(nights(4...7), 5), 5)),
            Stamp(id: "ten", icon: "qs.library", name: String(localized: "Ten books"),
                  how: String(localized: "Finish 10 books."), earned: stats.finished.count >= 10, progress: (min(stats.finished.count, 10), 10)),
            Stamp(id: "week", icon: "qs.check", name: String(localized: "Seven days"),
                  how: String(localized: "Read on every day of one week."), earned: fullWeek, progress: (stats.thisWeek.filter(\.didRead).count, 7)),
            Stamp(id: "authors", icon: "qs.bookmark", name: String(localized: "Five authors"),
                  how: String(localized: "Finish books by 5 different authors."), earned: authors >= 5, progress: (min(authors, 5), 5)),
        ]
    }
}

/// Seasonal, opt-in challenge: "Cozy autumn · Read 3 books that felt cozy". Leaving loses nothing.
struct SeasonalChallenge {
    static let joinedKey = "challengeCozyAutumnJoined"
    let start: Date
    let end: Date
    let goal = 3
    let books: [Book]

    /// Autumn this year (22 Sep – 21 Dec), or nil outside autumn.
    init?(stats: ReadingStats) {
        let cal = stats.calendar
        let y = stats.currentYear
        guard let start = cal.date(from: DateComponents(year: y, month: 9, day: 22)),
              let end = cal.date(from: DateComponents(year: y, month: 12, day: 21, hour: 23, minute: 59)),
              (start...end).contains(stats.now) else { return nil }
        self.start = start
        self.end = end
        books = stats.finished.filter { (start...end).contains($0.dateFinished!) && $0.moods.contains("Cozy") }
    }

    var done: Bool { books.count >= goal }
}

/// Average colour of a cover, for its spine on the shelf. Cached per cover.
enum SpineColor {
    private static var cache: [Int: Color] = [:]
    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    static func of(_ data: Data?, fallback: Color) -> Color {
        guard let data else { return fallback }
        let key = data.hashValue
        if let hit = cache[key] { return hit }
        guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]),
              let filter = CIFilter(name: "CIAreaAverage",
                                    parameters: [kCIInputImageKey: image, kCIInputExtentKey: CIVector(cgRect: image.extent)]),
              let output = filter.outputImage else { return fallback }
        var rgba = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &rgba, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        let color = Color(red: Double(rgba[0]) / 255, green: Double(rgba[1]) / 255, blue: Double(rgba[2]) / 255)
        cache[key] = color
        return color
    }
}
