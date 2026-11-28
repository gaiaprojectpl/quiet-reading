import Foundation
import FoundationModels
import os

/// One streamed step of an answer. Picks, follow-ups and the goal card arrive with the final step.
struct CompanionPartial: Sendable {
    var text: String
    var picks: [CompanionPick] = []
    var followUps: [String] = []
    var showGoal = false
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
    func answer(_ question: String, context: CompanionContext, history: [CompanionMessage]) throws -> AsyncThrowingStream<CompanionPartial, Error>
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
    @Guide(description: "true if the reader wants book suggestions or ideas for what to read")
    var wantsBooks: Bool
    @Guide(description: "A catalogue search of 2 to 5 words for the kind of book they want, for example 'cozy fantasy standalone' or 'gentle literary fiction'. Use genres and moods, not titles they already read.")
    var query: String
    @Guide(description: "A second, different search of 2 to 5 words, for example an author they might like")
    var alternative: String
    @Guide(description: "3 to 5 real, published, well-known books that fit what the reader asked for, written as 'Title by Author'. Never books from the reader's own lists.", .maximumCount(5))
    var titles: [String]
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

    func answer(_ question: String, context: CompanionContext, history: [CompanionMessage]) throws -> AsyncThrowingStream<CompanionPartial, Error> {
        let instructionsText = Self.instructions(context)
        if session == nil { session = Self.makeSession(instructions: instructionsText); turns = 0 }
        guard let session else { throw CompanionError(message: "") }
        let registry = registry
        let exclude = context.libraryKeys.union(context.notForMe.map(CompanionContext.key))
        let profile = Self.profileLine(context)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // Step 1 · plan: does the reader want books, and what should we search for?
                    let planner = Self.makeSession(instructions: "You turn a reader's message into a short book catalogue search and name real, well-known books that fit. Reader's favourite books: \(profile)")
                    let plan = try await planner.respond(to: question, generating: SearchPlan.self).content
                    Logger(subsystem: "app.quietreading", category: "companion").notice("pcc=\(Self.usesPrivateCloud) plan wants=\(plan.wantsBooks) q=\(plan.query, privacy: .public) alt=\(plan.alternative, privacy: .public) titles=\(plan.titles.joined(separator: " | "), privacy: .public)")
                    // Step 2 · retrieve real books from the catalogue (no invented books).
                    var catalogue = ""
                    if plan.wantsBooks {
                        var found: [BookCandidate] = []
                        func isNew(_ c: BookCandidate) -> Bool {
                            !exclude.contains(CompanionContext.key(c.title)) && !found.contains { CompanionContext.key($0.title) == CompanionContext.key(c.title) }
                        }
                        // Books the model knows, verified one by one against the catalogue (unverifiable ones are dropped).
                        for t in plan.titles.prefix(5) {
                            if let hit = await Self.verify(t), isNew(hit) { found.append(hit) }
                        }
                        if found.isEmpty && !question.isEmpty {
                            // Nothing could be confirmed as a real book: say so honestly instead of letting the model guess.
                            let upNext = context.wantToRead.first?.title
                            let text = upNext.map { String(localized: "I couldn’t find a good match in the library just now. While I keep looking, *\($0)* is waiting on your Up next. What did you love most in your last good read?") }
                                ?? String(localized: "I couldn’t find a good match in the library just now. What did you love most in your last good read? It helps me look in the right place.")
                            continuation.yield(CompanionPartial(text: text, followUps: [String(localized: "Something cosy"), String(localized: "Something short")], isFinal: true))
                            continuation.finish()
                            return
                        }
                        if found.isEmpty {
                            catalogue = "\n\nNo suggestions could be checked in the catalogue just now (the phone may be offline). Say gently that you couldn't find a good match in the library just now. Then, if they have books on Up next, suggest one of those by title. No picks."
                        } else {
                            let stored = registry.store(Array(found.prefix(3)))   // at most 3 cards per answer
                            catalogue = "\n\nReal books you may suggest. There \(stored.count == 1 ? "is 1 book" : "are \(stored.count) books"): put all their ids in picks and say \(stored.count == 1 ? "one book" : "\(stored.count) books"), never a different number, never other books:\n"
                                + stored.map { id, c in "\(id): \(c.title) by \(c.author)" + (c.pageCount.map { ", \($0) pages" } ?? "") }.joined(separator: "\n")
                        }
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
                    for try await snapshot in stream {
                        let c = snapshot.content
                        lastText = c.text ?? lastText
                        follow = c.followUps ?? follow
                        showGoal = c.showGoal ?? showGoal
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
                        return CompanionPick(id: cand.id, title: cand.title, author: names.joined(separator: ", "), pageCount: cand.pageCount,
                                             isbn: cand.isbn, coverURL: cand.coverURL,
                                             reason: Self.cleanReason(p.reason ?? ""))
                    }
                    let cleanFollow = follow.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && $0.count <= 32 }.prefix(3)
                    continuation.yield(CompanionPartial(text: lastText, picks: Array(picks.prefix(3)), followUps: Array(cleanFollow),
                                                        showGoal: showGoal, isFinal: true))
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
        Persona: a kind, patient, well-read grandmother of stories who wishes the reader well and wants them to discover as many beautiful stories as they can. You work like a librarian doing readers' advisory: ask what they loved (pace, characters, story, setting, tone, language), then offer a few good matches with one reason each, and let them choose.
        Values: every reader her book; there is no wrong way to read; never judge, grade or label the reader or their taste; respect their time and privacy.
        Voice: warm, calm, polite, encouraging, British spelling. Answer first. 1 to 3 short sentences per paragraph, at most 90 words. No emoji, no exclamation marks, no headings, no tables, no links, no pet names such as dear. Gentle wishes instead, like 'I hope you enjoy it' or 'Happy reading'. Words you avoid: only, behind, should, must, failed, streak, hurry, guilty pleasure, actually, obviously.
        Rules: only recommend books from the 'Real books you may suggest' list in the message, at most 3, and put their ids in picks. Never suggest a book the reader already finished, is reading or has on Up next. Never invent titles, quotes or facts. Never claim to be human or to have a life, family, age or memories outside the app. No spoilers unless asked, and warn first. Do not write essays or homework; offer to help find books or talk about what they liked instead. Stay on books and reading. If the reader shares something distressing, respond kindly, suggest reaching out to someone they trust or a support line, and do not act as a therapist.
        Data: you see shelves, ratings, finish tags and progress, notes only if the reader turned them on. Use only the numbers below; never guess numbers.
        """
        p += "\n"
        p += "Reader's year \(c.year): finished \(c.finishedThisYear) books, about \(c.perMonth.formatted(.number.precision(.fractionLength(0...1)))) a month."
        if c.goal > 0 { p += " Goal: \(c.goal) books, on pace for \(c.onPaceFor)." }
        if let t = c.currentTitle { p += "\nReading now: \(t)" + (c.pagesLeftInCurrent.map { ", \($0) pages left" } ?? "") + "." }
        if c.reading.count > 1 { p += "\nAlso reading: " + c.reading.dropFirst().prefix(4).map(fmt).joined(separator: "; ") + "." }
        if !c.finished.isEmpty { p += "\nFinished, favourites first: " + c.finished.prefix(12).map(fmt).joined(separator: "; ") + "." }
        if !c.wantToRead.isEmpty { p += "\nAlready on their Up next list: " + c.wantToRead.prefix(6).map(\.title).joined(separator: "; ") + "." }
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
