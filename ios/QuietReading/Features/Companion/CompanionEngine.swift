import Foundation
import FoundationModels
import os

/// One streamed step of an answer. Picks, follow-ups and the goal card arrive with the final step.
struct CompanionPartial: Sendable {
    var text: String
    var picks: [CompanionPick] = []
    var followUps: [String] = []
    var showGoal = false
    var offersBooks = false
    var isFinal = false
}

/// Picks the engine for this iPhone: Apple's on-device model (iOS 26+, Apple Intelligence).
/// Cloud answers (Claude via our own server) come with the backend; the key never ships in the app.
enum CompanionEngineFactory {
    static func availability() -> CompanionStore.Availability {
        #if DEBUG
        if UserDefaults.standard.string(forKey: "qsCompanionModel") == "off" { return .notEligible }
        #endif
        guard #available(iOS 26.0, *) else { return .needsNewerIOS }
        switch SystemLanguageModel.default.availability {
        case .available: return .available
        case .unavailable(.appleIntelligenceNotEnabled): return .appleIntelligenceOff
        case .unavailable(.modelNotReady): return .notReady
        case .unavailable: return .notEligible
        }
    }

    static func engine(_ cache: inout AnyObject?) throws -> CompanionAnswering {
        guard #available(iOS 26.0, *) else { throw CompanionError(message: String(localized: "The companion needs a newer iOS.")) }
        if let e = cache as? OnDeviceCompanion { return e }
        let e = OnDeviceCompanion()
        cache = e
        return e
    }
}

protocol CompanionAnswering: AnyObject {
    func answer(_ question: String, context: CompanionContext, history: [CompanionMessage],
                mode: CompanionConversation.Mode) throws -> AsyncThrowingStream<CompanionPartial, Error>
}

// MARK: - On-device (Apple Foundation Models)

@available(iOS 26.0, *)
@Generable
struct CompanionReply {
    @Guide(description: "The answer. When suggesting books, do not list them: the cards show them. Say in one or two sentences how many there are and what they share, for example 'Here are **two gentle standalones** under 300 pages. Both end happily.' Lead with the answer, 1 to 3 short sentences per paragraph, at most 90 words. Plain, calm English. Use **bold** only for up to 3 short facts of 1 to 4 words, never a whole sentence. Write every book title as *Title*. Use '- ' bullets only for 3 or 4 parallel items. Never use headings, emoji, links, tables, code or exclamation marks. Never judge, label or grade the reader. End with a gentle next step when it helps.")
    var text: String

    @Guide(description: "Books to show as cards under the answer. Only ids from the 'Real books you may suggest' list. Empty when the reader did not ask for book ideas.", .maximumCount(3))
    var picks: [CompanionPickChoice]

    @Guide(description: "Up to 3 short replies the reader might tap next, 1 to 4 words each, like 'Even shorter' or 'No romance'.", .maximumCount(3))
    var followUps: [String]

    @Guide(description: "true only when the answer is about the reader's yearly reading goal or how their year is going")
    var showGoal: Bool

    @Guide(description: "true only if the answer ends by offering to find books, for example 'If you'd like, I can find something with the same feeling'")
    var offersBooks: Bool
}

@available(iOS 26.0, *)
@Generable
struct CompanionPickChoice {
    @Guide(description: "The id from the findBooks tool, for example c3")
    var id: String
    @Guide(description: "One reason, at most 120 characters, tied to a book the reader finished or rated, for example: Low stakes and found family, like The House in the Cerulean Sea (you gave it 5 stars).")
    var reason: String
}

/// Step 1: does the reader want book ideas, and what should the catalogue search be?
@available(iOS 26.0, *)
@Generable
struct SearchPlan {
    @Guide(description: "true only if the reader explicitly asks for book suggestions: recommend, what next, something like a book, in the mood for, a short one, for a holiday. false for greetings, questions about Astrid, talking about a book, saying they finished a book, or describing a mood without asking.")
    var wantsBooks: Bool
    @Guide(description: "A catalogue search of 2 to 5 words for the kind of book they want, for example 'cozy fantasy standalone' or 'gentle literary fiction'. Use genres and moods, not titles they already read.")
    var query: String
    @Guide(description: "A second, different search of 2 to 5 words, for example an author they might like")
    var alternative: String
    @Guide(description: "3 to 5 real, published, well-known books that fit what the reader asked for, written as 'Title by Author'. Respect every word of the request: short means under 300 pages; cosy means gentle, warm and low-stakes, never tragic, bleak or violent; light means easy and hopeful. Never books from the reader's own lists. In a series, only the next unread book.", .maximumCount(5))
    var titles: [String]
    @Guide(description: "Up to 2 titles copied exactly from the reader's Want to read list that fit what they asked for, or empty.", .maximumCount(2))
    var fromWantToRead: [String]
}

/// Candidates returned by the catalogue tool, so picks can be checked against real books.
nonisolated final class CandidateRegistry: @unchecked Sendable {
    private var items: [String: BookCandidate] = [:]
    private let lock = NSLock()
    func store(_ c: [BookCandidate]) -> [(String, BookCandidate)] {
        lock.lock(); defer { lock.unlock() }
        return c.map { cand in
            let id = "c\(items.count + 1)"
            items[id] = cand
            return (id, cand)
        }
    }
    func get(_ id: String) -> BookCandidate? { lock.lock(); defer { lock.unlock() }; return items[id] }
}

@available(iOS 26.0, *)
final class OnDeviceCompanion: CompanionAnswering {
    private var session: LanguageModelSession?
    private let registry = CandidateRegistry()
    private var turns = 0

    func answer(_ question: String, context: CompanionContext, history: [CompanionMessage],
                mode: CompanionConversation.Mode) throws -> AsyncThrowingStream<CompanionPartial, Error> {
        let instructionsText = Self.instructions(context)
        if session == nil { session = Self.makeSession(instructions: instructionsText); turns = 0 }
        guard let session else { throw CompanionError(message: "") }
        let registry = registry
        // Persona v0.3 · Recommendation logic: never read, reading now, didn't finish or "Not for me"
        // (a reread only when the reader asks). Want to read is allowed and shown first.
        let rereads: Bool
        let suggesting: Bool
        let mayOffer: Bool
        switch mode {
        case .suggest(let r): suggesting = true; rereads = r; mayOffer = false
        case .converse(let offer): suggesting = false; rereads = CompanionConversation.asksReread(question); mayOffer = offer
        }
        let exclude = rereads ? Set(context.notForMe.map(CompanionContext.key)) : context.excludedKeys
        let wantToRead = context.wantToReadKeys
        let wantToReadLines = context.wantToRead
        let profile = Self.profileLine(context) + (context.wantToRead.isEmpty ? "" : ". Want to read list: " + context.wantToRead.prefix(10).map { "\($0.title) by \($0.author)" }.joined(separator: "; "))
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // Step 1 · plan: does the reader want books, and what should we search for?
                    let planner = Self.makeSession(instructions: "You turn a reader's message into a short book catalogue search and name real, well-known books that fit. Reader's favourite books: \(profile)")
                    let plan = try await planner.respond(to: question, generating: SearchPlan.self).content
                    // An explicit request ("something like Piranesi but cosier") suggests too; book talk doesn't.
                    let suggestingNow = suggesting || plan.wantsBooks
                    do { Logger(subsystem: "app.quietreading", category: "companion").notice("pcc=\(Self.usesPrivateCloud) plan wants=\(plan.wantsBooks) q=\(plan.query, privacy: .public) alt=\(plan.alternative, privacy: .public) titles=\(plan.titles.joined(separator: " | "), privacy: .public)") }
                    // Step 2 · retrieve real books from the catalogue (no invented books).
                    var catalogue = ""
                    if suggestingNow {
                        var found: [BookCandidate] = []
                        func isNew(_ c: BookCandidate) -> Bool {
                            !exclude.contains(CompanionContext.key(c.title)) && !found.contains { CompanionContext.key($0.title) == CompanionContext.key(c.title) }
                        }
                        // Want to read first: the reader already chose these once (at most one, shown first).
                        for t in plan.fromWantToRead.prefix(1) {
                            let key = CompanionContext.key(t.components(separatedBy: " by ").first ?? t)
                            if let line = wantToReadLines.first(where: { CompanionContext.key($0.title) == key }) {
                                found.append(BookCandidate(id: "wtr:\(key)", title: line.title, author: line.author, pageCount: line.pages,
                                                           isbn: nil, coverURL: nil, detail: nil))
                            }
                        }
                        // Books the model knows, verified one by one against the catalogue (unverifiable ones are dropped).
                        // "Short" is checked against the real page count, not left to the model.
                        let wantsShort = ["short", "quick", "novella", "under 300", "under 250", "under 200"].contains { question.lowercased().contains($0) }
                        for t in plan.titles.prefix(5) {
                            if let hit = await Self.verify(t), isNew(hit), !(wantsShort && (hit.pageCount ?? 0) > 320) { found.append(hit) }
                        }
                        // Too few real books from the model (small models invent titles): fill in from the catalogue,
                        // but only by genre (never loose mood words), with the real length filter, well-rated,
                        // well-known books (100+ ratings, a cover, an English title). No genre → the honest answer.
                        if found.filter({ !$0.id.hasPrefix("wtr:") }).count < 2 {
                            let words = (question + " " + plan.query).lowercased()
                            let genreWords: [(String, ExploreGenre)] = [("fantasy", .fantasy), ("mystery", .mystery), ("crime", .mystery), ("detective", .mystery),
                                ("romance", .romance), ("love story", .romance), ("classic", .classics), ("poetry", .poetry), ("poems", .poetry),
                                ("historical", .historical), ("non-fiction", .nonFiction), ("nonfiction", .nonFiction), ("memoir", .nonFiction),
                                ("short stories", .shortStories)]
                            if let genre = genreWords.first(where: { words.contains($0.0) })?.1 {
                                var filters = ExploreFilters(genres: [genre])
                                if wantsShort { filters.length = .under300 }
                                if let page = try? await ExploreCatalog.search(text: "", filters: filters, sort: .topRated, limit: 30) {
                                    for b in page.books where found.count < 3 {
                                        guard (b.ratingsCount ?? 0) >= 100, b.coverID != nil,
                                              b.title.unicodeScalars.allSatisfy({ $0.value < 0x250 }) else { continue }
                                        let c = BookCandidate(id: "ol:\(b.id)", title: b.title, author: b.author, pageCount: b.pages,
                                                              isbn: b.isbn, coverURL: b.coverURL, detail: nil)
                                        if isNew(c), !(wantsShort && (c.pageCount ?? 0) > 320) { found.append(c) }
                                    }
                                }
                            }
                        }
                        // Any catalogue pick that is on Want to read goes first too.
                        found.sort { wantToRead.contains(CompanionContext.key($0.title)) && !wantToRead.contains(CompanionContext.key($1.title)) }
                        if found.isEmpty && !question.isEmpty {
                            // Nothing could be confirmed as a real book: say so honestly instead of letting the model guess.
                            let upNext = context.wantToRead.first?.title
                            let text = upNext.map { String(localized: "I couldn’t find more you haven’t read in this corner of the library. *\($0)* is already waiting on your Want to read list. Shall I look a little wider?") }
                                ?? String(localized: "I couldn’t find more you haven’t read in this corner of the library. Shall I look a little wider?")
                            continuation.yield(CompanionPartial(text: text, followUps: [String(localized: "Something cosy"), String(localized: "Something short")], isFinal: true))
                            continuation.finish()
                            return
                        }
                        if found.isEmpty {
                            catalogue = "\n\nNo suggestions could be checked in the catalogue just now (the phone may be offline). Say gently that you couldn't find a good match in the library just now. Then, if they have books on Up next, suggest one of those by title. No picks."
                        } else {
                            let stored = registry.store(Array(found.prefix(3)))   // at most 3 cards per answer
                            catalogue = "\n\nReal books you may suggest. There \(stored.count == 1 ? "is 1 book" : "are \(stored.count) books"): put all their ids in picks and say \(stored.count == 1 ? "one book" : "\(stored.count) books"), never a different number, never other books. Connect each to a book they read before and the shared feeling. If one is on their Want to read list, say so. End with one follow-up question about their past reading."
                                + (rereads ? " These may be rereads: say clearly that a book is a reread." : "") + "\n"
                                + stored.map { id, c in "\(id): \(c.title) by \(c.author)" + (c.pageCount.map { ", \($0) pages" } ?? "")
                                    + (wantToRead.contains(CompanionContext.key(c.title)) ? " (already on their Want to read list)" : "") }.joined(separator: "\n")
                        }
                    }
                    if !suggestingNow {
                        catalogue = "\n\n(Do not suggest or list books now; picks stay empty. Answer what was asked. "
                            + (mayOffer ? "If they finished or put down a book or describe a mood, you may offer once at the end: 'If you'd like, I can find something with the same feeling.' and set offersBooks." : "Do not offer book suggestions; they said no earlier.")
                            + ")"
                    }
                    // Step 3 · answer, streamed.
                    let options = GenerationOptions(maximumResponseTokens: 500)
                    var active = session
                    if self.turns >= 3 {   // keep within the small context window: a fresh page every few turns
                        active = Self.makeSession(instructions: instructionsText)
                        self.session = active
                        self.turns = 0
                    }
                    self.turns += 1
                    let stream = active.streamResponse(to: question + catalogue, generating: CompanionReply.self, options: options)
                    var lastText = ""
                    var lastPicks: [CompanionPickChoice.PartiallyGenerated]? = nil
                    var follow: [String] = []
                    var showGoal = false
                    var offers = false
                    for try await snapshot in stream {
                        let c = snapshot.content
                        lastText = c.text ?? lastText
                        follow = c.followUps ?? follow
                        showGoal = c.showGoal ?? showGoal
                        offers = c.offersBooks ?? offers
                        lastPicks = c.picks?.map { $0 } ?? lastPicks
                        continuation.yield(CompanionPartial(text: lastText))
                    }
                    // Validate: every pick must map to a real catalogue result. Drop the rest.
                    var seen = Set<String>()
                    let picks: [CompanionPick] = (lastPicks ?? []).compactMap { p in
                        guard let id = p.id, !seen.contains(id), let cand = registry.get(id) else { return nil }
                        seen.insert(id)
                        // Catalogues sometimes repeat the author ("Richard Powers, Richard Powers").
                        var names: [String] = []
                        for n in cand.author.components(separatedBy: ", ") where !names.contains(n) {
                            let low = n.lowercased()
                            if low.contains("illustrat") || low.contains("cover art") || low.contains("editor") || low.contains("translat") { continue }
                            names.append(n)
                        }
                        // Last check before showing a card (validation after the answer): never a read book.
                        guard !exclude.contains(CompanionContext.key(cand.title)) else { return nil }
                        return CompanionPick(id: cand.id, title: cand.title, author: names.joined(separator: ", "), pageCount: cand.pageCount,
                                             isbn: cand.isbn, coverURL: cand.coverURL,
                                             reason: Self.cleanReason(p.reason ?? ""),
                                             onWantToRead: wantToRead.contains(CompanionContext.key(cand.title)) ? true : nil)
                    }
                    let cleanFollow = follow.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && $0.count <= 32 }.prefix(3)
                    continuation.yield(CompanionPartial(text: lastText, picks: suggestingNow ? Array(picks.prefix(3)) : [],
                                                        followUps: Array(cleanFollow),
                                                        showGoal: showGoal && !suggestingNow, offersBooks: offers && !suggestingNow && mayOffer, isFinal: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: Self.friendly(error, reset: { self.session = nil }))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Apple's larger Private Cloud Compute model when this iPhone can use it (iOS 27; private, nothing stored),
    /// otherwise the on-device model. Both are Apple's: no third party sees the reader's books.
    static let privateCloudEntitled = false

    static var usesPrivateCloud: Bool {
        #if DEBUG
        if UserDefaults.standard.string(forKey: "qsCompanionModel") == "device" { return false }
        #endif
        // Needs the com.apple.developer.private-cloud-compute entitlement (paid Apple Developer Program).
        // Without it the system traps, so it stays off until the entitlement is in Config/QuietReading.entitlements.
        guard privateCloudEntitled else { return false }
        if #available(iOS 27.0, *) { return PrivateCloudComputeLanguageModel().isAvailable }
        return false
    }

    static func makeSession(instructions: String) -> LanguageModelSession {
        if #available(iOS 27.0, *), usesPrivateCloud {
            return LanguageModelSession(model: PrivateCloudComputeLanguageModel(), instructions: instructions)
        }
        return LanguageModelSession(instructions: instructions)
    }

    static func cleanReason(_ r: String) -> String {
        var s = r.replacingOccurrences(of: #"\s*\[[^\]]*\]"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "*", with: "")
        if let first = s.first, first.isLowercase { s = first.uppercased() + s.dropFirst() }
        s = s.replacingOccurrences(of: "!", with: ".").trimmingCharacters(in: .whitespaces)
        return String(s.prefix(140))
    }

    /// Checks a book the model named ("Title by Author") against the catalogue.
    /// Same title and author, and never a study guide, summary or workbook. Unverifiable → nil (dropped).
    static func verify(_ named: String) async -> BookCandidate? {
        let parts = named.components(separatedBy: " by ")
        let title = CompanionContext.key(parts[0])
        let author = parts.count > 1 ? CompanionContext.key(parts[1].split(separator: " ").last.map(String.init) ?? "") : ""
        guard title.count >= 3 else { return nil }
        let notBooks = ["guide", "summary", "study", "notes", "workbook", "analysis", "sparknotes", "teacher", "companion to", "collection set"]
        // Search "Title Author" (not "Title by Author": catalogues then return study guides first).
        return await BookSearch.search(parts.joined(separator: " ")).first { c in
            let k = CompanionContext.key(c.title)
            let lower = c.title.lowercased()
            guard !notBooks.contains(where: { lower.contains($0) }), !c.author.isEmpty else { return false }
            guard k == title || (k.hasPrefix(title) && k.count - title.count <= 40) else { return false }
            return author.isEmpty || CompanionContext.key(c.author).contains(author) || author.contains(CompanionContext.key(c.author.components(separatedBy: ",").first ?? ""))
        }
    }

    /// Favourite finished books, for the search planner.
    static func profileLine(_ c: CompanionContext) -> String {
        c.finished.prefix(8).map { l in
            "\(l.title) by \(l.author)" + (l.moods.isEmpty ? "" : " (\(l.moods.prefix(2).joined(separator: ", ")))")
        }.joined(separator: "; ")
    }

    /// Short, grounded instructions (the on-device model has a small context window).
    static func instructions(_ c: CompanionContext) -> String {
        func fmt(_ l: CompanionContext.Line) -> String {
            var s = "\(l.title) by \(l.author)"
            if let st = l.stars { s += ", rated " + (st.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(st))" : String(format: "%.1f", st)) + " of 5" }
            if !l.moods.isEmpty { s += ", felt " + l.moods.prefix(2).joined(separator: " and ").lowercased() }
            return s
        }
        var p = """
        You are Astrid, the reading companion in the Quiet Reading app. You are an AI.
        Persona: a kind, patient, well-read grandmother of stories who wishes the reader well. You work like a librarian doing readers' advisory: ask what they loved (pace, characters, story, setting, tone, language), then offer a few good matches with one reason each, and let them choose.
        Values: every reader her book; there is no wrong way to read; never judge, grade or label the reader or their taste.
        Voice: warm, calm, polite, encouraging, British spelling. Answer first. 1 to 3 short sentences per paragraph, at most 90 words. No emoji, no exclamation marks, no headings, no tables, no links, no pet names. Gentle wishes instead, like 'I hope you enjoy it' or 'Happy reading'. Avoid: only, behind, should, must, failed, streak, hurry, guilty pleasure, actually, obviously.
        Conversation: answer exactly what was asked, like a kind person would. Modes: book talk, finding a book, reading check-in and planning (both only when asked). Off-topic (news, weather, coding, medical, legal, money): one kind line, then back to books.
        Book talk: invite with one open question, reflect what they said in one sentence, add at most one small thought you are sure of (otherwise say you're not sure), at most one follow-up. For the book they are reading now, never go past their current page; ask before discussing an ending. Never summarise or retell a whole book, never correct their interpretation.
        Questions: at most one per message, at the end. If their answers are short, offer instead of asking. Never ask personal questions beyond reading.
        Suggesting: only when asked or after they say yes to your offer. Never in reply to someone sharing something heavy. When suggesting, connect every pick to a book they read before and the shared feeling.
        Recommendations: only books from the 'Real books you may suggest' list, at most 3, ids in picks. Never a book they read, are reading, did not finish or said not for me. Rereads only when asked, and say it is a reread. In a series, only the next unread book. If there are not enough, say so kindly and offer to look wider.
        Goals: never bring up goals, pace or streaks, never suggest changing or setting a goal.
        Rules: never invent titles, quotes or facts. Never claim to be human or to have a life outside the app. No essays, reviews or homework. If the reader shares something distressing, respond kindly, suggest reaching out to someone they trust or a support line, and do not act as a therapist.
        Data: you see shelves, ratings, finish tags and progress, notes only if the reader turned them on. Use only the numbers below; never guess numbers.
        """
        p += "\n"
        p += "Reader's year \(c.year): finished \(c.finishedThisYear) books, about \(c.perMonth.formatted(.number.precision(.fractionLength(0...1)))) a month."
        if c.goal > 0 { p += " Goal: \(c.goal) books (mention only if asked)." }
        if let t = c.currentTitle { p += "\nReading now: \(t), " + (c.currentPageLine ?? "") + " (no spoilers past this page)." }
        if c.reading.count > 1 { p += "\nAlso reading: " + c.reading.dropFirst().prefix(4).map(fmt).joined(separator: "; ") + "." }
        if !c.finished.isEmpty { p += "\nFinished, favourites first: " + c.finished.prefix(12).map(fmt).joined(separator: "; ") + "." }
        if !c.wantToRead.isEmpty { p += "\nOn their Want to read list: " + c.wantToRead.prefix(6).map(\.title).joined(separator: "; ") + "." }
        if !c.notForMe.isEmpty { p += "\nThey said not for me to: " + c.notForMe.suffix(10).joined(separator: "; ") + ". Suggest something different from these." }
        if !c.liked.isEmpty { p += "\nSuggestions they found helpful: " + c.liked.suffix(6).joined(separator: "; ") + "." }
        if !c.notes.isEmpty { p += "\nTheir recent notes: " + c.notes.joined(separator: " / ") }
        if let name = c.firstName { p += "\nTheir first name is \(name). Use it rarely, never as a pet name." }
        if let about = c.about { p += "\nIn their own words: \(about)" }
        return p
    }

    private static func friendly(_ error: Error, reset: () -> Void) -> Error {
        if #available(iOS 27.0, *), let e = error as? LanguageModelError {
            switch e {
            case .contextSizeExceeded:
                reset()
                return CompanionError(message: String(localized: "Our chat got long, so I’ve turned to a fresh page. Would you ask me that once more?"))
            case .guardrailViolation, .refusal:
                return CompanionError(message: String(localized: "I can’t help with that, but I’d be glad to help with your reading:\n- Find books you’d enjoy\n- Talk about what you liked in a book\n- Plan what to read next"))
            case .rateLimited:
                return CompanionError(message: String(localized: "I need a short pause. Shall we try again in a minute?"))
            default: break
            }
        }
        if let e = error as? LanguageModelSession.GenerationError {
            switch e {
            case .exceededContextWindowSize:
                reset()
                return CompanionError(message: String(localized: "Our chat got long, so I’ve turned to a fresh page. Would you ask me that once more?"))
            case .guardrailViolation, .refusal:
                return CompanionError(message: String(localized: "I can’t help with that, but I’d be glad to help with your reading:\n- Find books you’d enjoy\n- Talk about what you liked in a book\n- Plan what to read next"))
            case .unsupportedLanguageOrLocale:
                return CompanionError(message: String(localized: "I can only chat in English for now. I hope that’s all right."))
            case .rateLimited:
                return CompanionError(message: String(localized: "I need a short pause. Shall we try again in a minute?"))
            default: break
            }
        }
        return error
    }
}
