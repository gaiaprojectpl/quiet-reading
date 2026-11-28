import SwiftUI
import SwiftData
import os

/// Flow 12 · Reading companion. Settings keys (Companion & privacy).
nonisolated enum CompanionKeys {
    static let enabled = "companionEnabled"          // set by the consent screen
    static let includeNotes = "companionIncludeNotes"
    static let nudge = "companionNudge"              // one Home card near the end of a book
    static let historyDays = "companionHistoryDays"  // 30 (default), 7, 0 = don't keep
    static let notForMe = "companionNotForMe"        // titles the reader turned down
    static let nudgeDismissed = "companionNudgeDismissed"
    static let leftPane = "companionLeftPane"          // iPhone Duo: Astrid on the left page (swap sides)
}

/// One turn in the conversation.
struct CompanionMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable { case me, companion }
    enum Status: String, Codable { case done, streaming, failed }

    var id = UUID()
    var role: Role
    var text: String
    var picks: [CompanionPick] = []
    var followUps: [String] = []
    var showGoal = false
    var status: Status = .done
    var date = Date.now
    var feedback: Int = 0   // 1 helpful, -1 not helpful
}

/// A real book suggested inside an answer (Chat book card). Always from the catalogue.
struct CompanionPick: Identifiable, Codable, Equatable {
    enum State: String, Codable { case open, added, notForMe }
    var id: String
    var title: String
    var author: String
    var pageCount: Int?
    var isbn: String?
    var coverURL: URL?
    var reason: String
    var state: State = .open
}

/// The conversation, its state and the companion's settings. Lives for the app session;
/// the chat text is kept on this phone for the chosen number of days.
@Observable
final class CompanionStore {
    enum Phase: Equatable { case idle, thinking, answering }
    enum Availability: Equatable { case available, notEligible, appleIntelligenceOff, notReady, needsNewerIOS }

    var messages: [CompanionMessage] = []
    var phase: Phase = .idle
    var isOpen = false
    /// Screens with buttons pinned to the bottom (Explore › book preview) hide the floating button.
    var buttonHidden = false
    /// A question to ask as soon as the chat opens (Home nudge, starters from elsewhere).
    var pendingPrompt: String?
    private(set) var availability: Availability = .available
    private var task: Task<Void, Never>?
    private var engine: AnyObject?

    init() {
        load()
        availability = CompanionEngineFactory.availability()
    }

    /// Stored (observable) so the consent screen switches to the chat straight away.
    var isEnabled: Bool = UserDefaults.standard.bool(forKey: CompanionKeys.enabled) {
        didSet { UserDefaults.standard.set(isEnabled, forKey: CompanionKeys.enabled) }
    }

    func refreshAvailability() { availability = CompanionEngineFactory.availability() }

    // MARK: Asking

    func send(_ text: String, books: [Book], goal: Int) {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, phase == .idle else { return }
        messages.append(CompanionMessage(role: .me, text: question))
        run(question, books: books, goal: goal)
    }

    /// "Not sent · Tap to try again".
    func retry(_ message: CompanionMessage, books: [Book], goal: Int) {
        guard let i = messages.firstIndex(of: message) else { return }
        messages[i].status = .done
        if i + 1 < messages.count, messages[i + 1].status == .failed { messages.remove(at: i + 1) }
        run(message.text, books: books, goal: goal)
    }

    func stop() {
        task?.cancel()
        task = nil
        if let last = messages.indices.last, messages[last].status == .streaming { messages[last].status = .done }
        phase = .idle
    }

    private func run(_ question: String, books: [Book], goal: Int) {
        phase = .thinking
        // 👍 / 👎 shape the next answers: picks from helpful answers are "liked", from unhelpful ones "not for me".
        let liked = messages.filter { $0.feedback == 1 }.flatMap { $0.picks.map(\.title) }
        let disliked = messages.filter { $0.feedback == -1 }.flatMap { $0.picks.map(\.title) }
        let context = CompanionContext(books: books, goal: goal,
                                       includeNotes: UserDefaults.standard.bool(forKey: CompanionKeys.includeNotes),
                                       notForMe: notForMe + disliked, liked: liked)
        task = Task { [weak self] in
            guard let self else { return }
            do {
                // Numbers about the goal and the year always come from the app, never the model
                // (Flow 12: "numbers come from a stat card built from app data"). Works without AI too.
                if let local = CompanionFallback.answer(question, context: context) {
                    try await Task.sleep(for: .milliseconds(600))
                    append(local)
                    phase = .idle
                    save()
                    return
                }
                if availability != .available {
                    if let local = CompanionFallback.answer(question, context: context) {
                        try await Task.sleep(for: .milliseconds(700))
                        append(local)
                    } else {
                        append(CompanionFallback.unavailable(availability))
                    }
                    phase = .idle
                    save()
                    return
                }
                var reply = CompanionMessage(role: .companion, text: "", status: .streaming)
                let stream = try CompanionEngineFactory.engine(&engine).answer(question, context: context, history: Array(messages.suffix(6)))
                for try await partial in stream {
                    if Task.isCancelled { break }
                    reply.text = CompanionText.sanitize(partial.text)
                    // Reduce Motion: the whole answer appears at once (no streaming).
                    if UIAccessibility.isReduceMotionEnabled && !partial.isFinal { continue }
                    if phase == .thinking, !reply.text.isEmpty {
                        phase = .answering
                        messages.append(reply)
                    } else if let i = messages.firstIndex(where: { $0.id == reply.id }) {
                        messages[i].text = reply.text
                    }
                    if partial.isFinal, let i = messages.firstIndex(where: { $0.id == reply.id }) {
                        messages[i].picks = partial.picks
                        messages[i].text = CompanionText.matchCount(messages[i].text, picks: partial.picks.count)
                        messages[i].followUps = partial.followUps
                        messages[i].showGoal = partial.showGoal
                        messages[i].status = .done
                        if messages[i].text.isEmpty { messages[i].text = String(localized: "Here’s what I found. I hope you enjoy them.") }
                    }
                }
                if !messages.contains(where: { $0.id == reply.id }) {
                    append(CompanionMessage(role: .companion, text: String(localized: "I couldn’t find a good answer to that. Would you ask me another way?")))
                }
            } catch is CancellationError {
            } catch let error as CompanionError {
                append(CompanionMessage(role: .companion, text: error.message))
            } catch {
                Logger(subsystem: "app.quietreading", category: "companion").error("Companion failed: \(String(describing: error), privacy: .public)")
                // Flow 12 › Something went wrong: the question stays, marked "Not sent".
                if let last = messages.lastIndex(where: { $0.role == .me }) {
                    messages.append(CompanionMessage(role: .companion, text: String(localized: "Something went wrong on my side. Your message is saved; shall I try again?"), status: .failed))
                    messages[last].status = .failed
                }
                engine = nil   // start a fresh session next time
            }
            phase = .idle
            save()
        }
    }

    private func append(_ m: CompanionMessage) {
        messages.append(m)
    }

    // MARK: Picks & feedback

    var notForMe: [String] {
        get { UserDefaults.standard.stringArray(forKey: CompanionKeys.notForMe) ?? [] }
        set { UserDefaults.standard.set(Array(newValue.suffix(50)), forKey: CompanionKeys.notForMe) }
    }

    func setPick(_ pick: CompanionPick, in message: CompanionMessage, state: CompanionPick.State) {
        guard let m = messages.firstIndex(where: { $0.id == message.id }),
              let p = messages[m].picks.firstIndex(where: { $0.id == pick.id }) else { return }
        messages[m].picks[p].state = state
        if state == .notForMe {
            notForMe.append(pick.title)
            // Astrid · key line "Not for me" (only once per answer).
            if !messages[m].picks.contains(where: { $0.state == .notForMe && $0.id != pick.id }) {
                messages.insert(CompanionMessage(role: .companion, text: String(localized: "Thank you for telling me. I’ll remember that and find something different.")), at: m + 1)
            }
        }
        save()
    }

    func rate(_ message: CompanionMessage, _ value: Int) {
        guard let i = messages.firstIndex(where: { $0.id == message.id }) else { return }
        messages[i].feedback = messages[i].feedback == value ? 0 : value
        save()
    }

    // MARK: History (kept on this phone only)

    private static var url: URL { URL.applicationSupportDirectory.appending(path: "companion-chat.json") }

    private var keepDays: Int {
        let d = UserDefaults.standard.object(forKey: CompanionKeys.historyDays) as? Int
        return d ?? 30
    }

    func save() {
        guard keepDays > 0 else { return }
        try? FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
        let kept = messages.filter { $0.status != .streaming }
        if let data = try? JSONEncoder().encode(kept) { try? data.write(to: Self.url, options: .atomic) }
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.url),
              let saved = try? JSONDecoder().decode([CompanionMessage].self, from: data) else { return }
        let cutoff = Date.now.addingTimeInterval(-Double(keepDays) * 86_400)
        messages = keepDays > 0 ? saved.filter { $0.date >= cutoff } : []
    }

    func deleteHistory() {
        stop()
        messages = []
        engine = nil
        try? FileManager.default.removeItem(at: Self.url)
    }

    /// Ends the chat when the companion is turned off.
    func turnOff() {
        deleteHistory()
        isEnabled = false
        isOpen = false
    }
}

/// What the companion knows about the reader. Titles, authors, ratings, moods and progress only:
/// never the name, email, photo or location. Notes only when the reader turns them on.
nonisolated struct CompanionContext: Sendable {
    struct Line: Sendable { let title: String; let author: String; let stars: Double?; let moods: [String]; let pages: Int? }
    let finished: [Line]
    let reading: [Line]
    let wantToRead: [Line]
    let notes: [String]
    let notForMe: [String]
    let finishedThisYear: Int
    let goal: Int
    let year: Int
    let perMonth: Double
    let onPaceFor: Int
    let pagesLeftInCurrent: Int?
    let currentTitle: String?
    let libraryKeys: Set<String>
    let liked: [String]

    @MainActor init(books: [Book], goal: Int, includeNotes: Bool, notForMe: [String], liked: [String] = []) {
        self.liked = liked
        let stats = ReadingStats(books: books)
        func line(_ b: Book) -> Line {
            Line(title: b.title, author: b.author, stars: b.stars ?? b.rating.map(Double.init), moods: b.moods, pages: b.pageCount)
        }
        finished = stats.finished.sorted { ($0.stars ?? 0, $0.dateFinished ?? .distantPast) > ($1.stars ?? 0, $1.dateFinished ?? .distantPast) }
            .prefix(25).map(line)
        let readingBooks = books.filter { $0.status == .reading }.sorted { $0.lastUpdated > $1.lastUpdated }
        reading = readingBooks.map(line)
        wantToRead = books.filter { $0.status == .toRead }.prefix(10).map(line)
        notes = includeNotes ? books.flatMap { $0.sessions.compactMap(\.note) }.suffix(10).map { String($0.prefix(160)) } : []
        self.notForMe = notForMe
        let g = stats.goal(goal, year: stats.currentYear)
        finishedThisYear = g.done
        self.goal = goal
        year = stats.currentYear
        perMonth = g.perMonth
        onPaceFor = g.onPaceFor
        currentTitle = readingBooks.first?.title
        pagesLeftInCurrent = readingBooks.first.flatMap { b in b.pageCount.map { max(0, $0 - b.currentPage) } }
        libraryKeys = Set(books.map { CompanionContext.key($0.title) })
    }

    nonisolated static func key(_ title: String) -> String {
        title.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

/// The model returns a small Markdown subset; anything outside it is removed before display
/// (headings, emoji, links, code, tables, exclamation marks).
enum CompanionText {
    /// Books can be dropped when the catalogue can't confirm them, so make "two/three books" match the cards shown.
    static func matchCount(_ text: String, picks: Int) -> String {
        guard picks > 0 else { return text }
        let words = [1: "one", 2: "two", 3: "three", 4: "four", 5: "five"]
        guard let right = words[picks] else { return text }
        var out = text
        for (n, w) in words where n != picks {
            for form in [w, w.capitalized] {
                let replacement = form == w ? right : right.capitalized
                out = out.replacingOccurrences(of: "**\(form) ", with: "**\(replacement) ")
                out = out.replacingOccurrences(of: "\(form) ", with: "\(replacement) ", options: [], range: out.range(of: "\(form) "))
            }
        }
        if picks == 1 {
            for (a, b) in [("books", "book"), ("tales", "tale"), ("stories", "story"), ("standalones", "standalone"), ("reads", "read"), ("Both", "It"), ("both", "it")] {
                out = out.replacingOccurrences(of: " \(a) ", with: " \(b) ").replacingOccurrences(of: " \(a)**", with: " \(b)**")
                    .replacingOccurrences(of: "\(a) ", with: "\(b) ", options: .anchored)
            }
        }
        return out
    }

    static func unboldLong(_ line: String) -> String {
        var out = line
        let regex = try? NSRegularExpression(pattern: #"\*\*([^*]+)\*\*"#)
        let ns = line as NSString
        for m in (regex?.matches(in: line, range: NSRange(location: 0, length: ns.length)) ?? []).reversed() {
            let inner = ns.substring(with: m.range(at: 1))
            if inner.split(separator: " ").count > 5 {
                out = (out as NSString).replacingCharacters(in: m.range, with: inner)
            }
        }
        return out
    }

    static func sanitize(_ s: String) -> String {
        var lines: [String] = []
        for raw in s.components(separatedBy: "\n") {
            var l = raw
            if l.trimmingCharacters(in: .whitespaces).hasPrefix("#") { l = l.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces) }
            if l.contains("|") && l.filter({ $0 == "|" }).count >= 2 { continue }      // tables
            if l.hasPrefix("```") { continue }
            // Internal fields must never show (ids, field names).
            let low = l.lowercased().trimmingCharacters(in: .whitespaces)
            if low.hasPrefix("picks") || low.hasPrefix("followups") || low.hasPrefix("follow-ups") || low.hasPrefix("showgoal") { break }
            l = l.replacingOccurrences(of: #"\s*\[?\bc\d+\b\]?"#, with: "", options: .regularExpression)
            l = l.replacingOccurrences(of: #"https?://\S+"#, with: "", options: .regularExpression)
            l = l.replacingOccurrences(of: "!", with: ".")
            l = String(l.unicodeScalars.filter { !($0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x2000)) }.map(Character.init))
            // Bold is for short key facts only: unbold anything longer than 5 words.
            l = unboldLong(l)
            l = l.replacingOccurrences(of: "  ", with: " ")
            lines.append(l)
        }
        return lines.joined(separator: "\n").replacingOccurrences(of: "\n\n\n", with: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Answers that don't need the model (numbers always come from the app), and calm
/// explanations when the on-device model isn't available.
enum CompanionFallback {
    static func answer(_ q: String, context c: CompanionContext) -> CompanionMessage? {
        let lower = q.lowercased()
        let asksNumbers = lower.contains("goal") || lower.contains("my year") || lower.contains("this year")
            || lower.contains("how is my reading") || lower.contains("how’s my reading") || lower.contains("how many books")
        guard asksNumbers, !lower.contains("plan"), !lower.contains("next book") else { return nil }
        return CompanionMessage(role: .companion, text: goalText(c),
                                followUps: [String(localized: "Open my stats"), String(localized: "Find my next book")], showGoal: true)
    }

    static func goalText(_ c: CompanionContext) -> String {
        let perMonth = c.perMonth.formatted(.number.precision(.fractionLength(0...1)))
        if c.goal > 0 {
            if c.finishedThisYear >= c.goal {
                return String(localized: "You’ve finished **\(c.finishedThisYear) of your \(c.goal) books** this year. Your goal is reached. What a lovely year of stories.")
            }
            return String(localized: "You’ve finished **\(c.finishedThisYear) of your \(c.goal) books** so far this year, about **\(perMonth) a month**. At this gentle pace you’d finish around \(c.onPaceFor) this year. Take your time.")
        }
        if c.finishedThisYear == 0 {
            return String(localized: "Some months are for living, not reading. Your books will wait for you, and I’ll be here whenever you’re ready.")
        }
        return String(localized: "You’ve finished **\(c.finishedThisYear) books** so far this year, about **\(perMonth) a month**. What a lovely year of stories.")
    }

    static func unavailable(_ a: CompanionStore.Availability) -> CompanionMessage {
        let text: String
        switch a {
        case .appleIntelligenceOff:
            text = String(localized: "I run on Apple Intelligence. Whenever you’re ready, turn it on in iPhone Settings › Apple Intelligence & Siri and come back. Everything else in Quiet Reading works as usual.")
        case .notReady:
            text = String(localized: "I’m still getting ready on your iPhone. This can take a few minutes after Apple Intelligence is turned on. Take your time.")
        case .needsNewerIOS, .notEligible:
            text = String(localized: "On this iPhone I can tell you how your reading year is going. Talking about books needs an Apple Intelligence iPhone, I’m sorry to say.")
        case .available:
            text = ""
        }
        return CompanionMessage(role: .companion, text: text, followUps: [String(localized: "How is my reading goal going?")])
    }
}

struct CompanionError: Error { let message: String }
