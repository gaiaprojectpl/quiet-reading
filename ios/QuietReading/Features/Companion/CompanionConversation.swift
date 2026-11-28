import Foundation

/// Persona v0.3 · Conversation design (Kaja, 28 Nov): answer what was asked, the way a kind person would.
/// Greetings, "who are you", thanks, goodbye and goal questions get short, natural answers here (no model,
/// no book cards, no stats unless asked). Book suggestions only when the reader asks or says yes to an offer.
enum CompanionConversation {
    enum Intent: Equatable {
        case greeting, whoAreYou, whatCanYouDo, areYouReal, howDoYouKnow, thanks, goodbye
        case goal, changeGoal, readMore
        case vagueRequest, yes, no
        /// "I just finished The Night Circus" / "I gave up on Ulysses": book talk opens with the key line.
        case finished(String), putDown(String?)
        case other
    }

    /// What the reader wants next from the model.
    enum Mode: Equatable {
        /// Book talk, check-ins, planning, off-topic: no cards. Astrid may offer once (unless declined).
        case converse(mayOffer: Bool)
        /// Suggest up to 3 real books. `rereads`: the reader asked for a reread.
        case suggest(rereads: Bool)
    }

    static func classify(_ question: String) -> Intent {
        let q = " " + question.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "' ")).inverted).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces) + " "
        func has(_ words: String...) -> Bool { words.contains { q.contains(" \($0) ") } }
        let short = q.split(separator: " ").count <= 4

        if has("change my goal", "change the goal", "lower my goal", "raise my goal", "set a goal", "set my goal", "new goal", "edit my goal") { return .changeGoal }
        if has("should i read more", "am i reading enough", "do i read enough", "read more books") { return .readMore }
        if has("goal", "my year", "this year", "how is my reading", "how's my reading", "how many books") && !has("plan", "next book") { return .goal }
        if has("who are you", "what are you", "what's your name", "what is your name", "tell me about yourself", "introduce yourself") { return .whoAreYou }
        if has("what can you do", "how can you help", "what do you do", "what are you for") { return .whatCanYouDo }
        if has("are you real", "are you a real", "are you human", "are you a person", "are you an ai", "are you a bot", "are you a robot") { return .areYouReal }
        if has("how do you know what i like", "what can you see", "what do you see", "how do you know me", "what do you know about me") { return .howDoYouKnow }
        if short && has("thanks", "thank you", "thank u", "ta", "cheers", "much appreciated") { return .thanks }
        if short && has("bye", "goodbye", "good bye", "good night", "goodnight", "see you", "see ya") { return .goodbye }
        if short && has("hi", "hello", "hey", "hiya", "good morning", "good afternoon", "good evening", "morning") { return .greeting }
        if short && has("yes", "yes please", "sure", "ok", "okay", "please", "go on", "yeah", "yep", "why not", "i'd like that", "sounds good") { return .yes }
        if short && has("no", "no thanks", "no thank you", "not now", "maybe later", "nope", "i'm fine", "im fine") { return .no }
        if isVagueRequest(q) { return .vagueRequest }
        if let t = bookAfter(question, ["i just finished ", "i've just finished ", "i finished ", "just finished "]) { return .finished(t) }
        if has("gave up on", "didn't finish", "did not finish", "put down", "stopped reading", "couldn't finish", "dnf") {
            return .putDown(bookAfter(question, ["i gave up on ", "gave up on ", "i didn't finish ", "i stopped reading ", "i put down "]))
        }
        return .other
    }

    /// The book named after a phrase ("I just finished *The Night Circus*."), trimmed; nil when it isn't a title.
    private static func bookAfter(_ question: String, _ phrases: [String]) -> String? {
        let lower = question.lowercased().replacingOccurrences(of: "’", with: "'")
        guard let phrase = phrases.first(where: { lower.hasPrefix($0) || lower.contains(". " + $0) }),
              let range = lower.range(of: phrase) else { return nil }
        let start = question.index(question.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.upperBound))
        var t = String(question[start...]).trimmingCharacters(in: .whitespaces)
        if let end = t.firstIndex(where: { ".!?,;".contains($0) }) { t = String(t[..<end]) }
        t = t.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespaces)
        let words = t.split(separator: " ")
        guard (1...12).contains(words.count), !["it", "the book", "my book", "reading", "a book"].contains(t.lowercased()) else { return nil }
        return t
    }

    /// "Recommend something" with no mood, pace, length, genre or "like X" to go on.
    private static func isVagueRequest(_ q: String) -> Bool {
        let asks = ["recommend", "suggest", "what should i read", "what to read", "find my next book", "my next book",
                    "next read", "what next", "what's next", "any ideas", "something to read", "a book for me"]
        guard asks.contains(where: { q.contains($0) }) else { return false }
        let specifics = ["like", "cosy", "cozy", "short", "long", "quick", "slow", "funny", "sad", "dark", "light", "romance",
                         "fantasy", "mystery", "crime", "thriller", "classic", "poetry", "history", "historical", "non fiction",
                         "nonfiction", "memoir", "holiday", "beach", "winter", "autumn", "summer", "under", "pages", "series",
                         "author", "by ", "about", "set in", "tired", "comfort", "gentle", "adventure", "horror", "science", "sci fi"]
        return !specifics.contains { q.contains($0) }
    }

    /// Short, natural answers that need no model. nil = let the model answer.
    @MainActor
    static func reply(to intent: Intent, context c: CompanionContext, includeNotes: Bool, includeProfile: Bool) -> CompanionMessage? {
        func say(_ text: String, follow: [String] = [], goal: Bool = false) -> CompanionMessage {
            CompanionMessage(role: .companion, text: text, followUps: follow, showGoal: goal)
        }
        switch intent {
        case .greeting:
            if let t = c.currentTitle { return say(String(localized: "Hello. How is *\(t)* going?")) }
            return say(String(localized: "Hello. Are you in the mood for something new, or would you like to talk about a book?"),
                       follow: [String(localized: "Something new"), String(localized: "Talk about a book")])
        case .whoAreYou:
            return say(String(localized: "I’m Astrid, your reading companion. I’m here to help you discover books from around the world, and to chat about the ones you’re reading. I’m an AI, so I only know what’s on your shelves."))
        case .whatCanYouDo:
            return say(String(localized: "I can help you find your next book, chat about what you’re reading, and tell you a little about your reading when you’re curious. What would you like to start with?"),
                       follow: [String(localized: "Find my next book"), String(localized: "Talk about a book")])
        case .areYouReal:
            return say(String(localized: "No, I’m an AI, a reading companion inside Quiet Reading. But I do love talking about books."))
        case .howDoYouKnow:
            var text = String(localized: "I look at your shelves, your ratings and the tags you add when you finish a book.")
            switch (includeNotes, includeProfile) {
            case (false, false): text += " " + String(localized: "I can’t see anything else, and your notes only if you turn them on in Settings.")
            case (true, false): text += " " + String(localized: "You’ve also let me read your notes. I can’t see anything else.")
            case (false, true): text += " " + String(localized: "You’ve also let me see your first name and About me. Your notes only if you turn them on in Settings.")
            case (true, true): text += " " + String(localized: "You’ve also let me read your notes, your first name and About me. I can’t see anything else.")
            }
            return say(text)
        case .thanks:
            return say(String(localized: "You’re very welcome. Happy reading."))
        case .goodbye:
            return say(String(localized: "Happy reading. I hope it’s a good one."))
        case .goal:
            return say(goalText(c), goal: c.goal > 0 || c.finishedThisYear > 0)
        case .changeGoal:
            return say(String(localized: "I can’t change goals for you yet, but you can do it in Stats › Goal whenever you like."),
                       follow: [String(localized: "Open my stats")])
        case .readMore:
            var m = say(String(localized: "There’s no right amount. Whatever you read, it’s yours. Would you like a short book for a quiet evening?"))
            m.offersBooks = true
            return m
        case .vagueRequest:
            var m = say(String(localized: "Gladly. Are you in the mood for something cosy, or something with a bit more adventure?"),
                        follow: [String(localized: "Something cosy"), String(localized: "More adventure"), String(localized: "Something short")])
            m.askedPreference = true
            return m
        case .no:
            return say(String(localized: "Of course. I’m here whenever you’d like."))
        case .finished(let title):
            // Key line "Finished a book": invite book talk; she may offer ideas later, once.
            return say(String(localized: "You finished *\(title)*. How did it leave you feeling?"))
        case .putDown:
            var m = say(String(localized: "Not every book is for every reader, and that’s perfectly fine. Would you like something quite different?"))
            m.offersBooks = true
            return m
        case .yes, .other:
            return nil
        }
    }

    /// "How's my goal going?": facts from the app with kind framing, no advice, no pace pressure.
    static func goalText(_ c: CompanionContext) -> String {
        if c.goal > 0 {
            if c.finishedThisYear >= c.goal {
                return String(localized: "You’ve finished **\(c.finishedThisYear) of \(c.goal) books** this year. Your goal is reached. What a lovely year of stories.")
            }
            return String(localized: "You’ve finished **\(c.finishedThisYear) of \(c.goal) books** this year. What a lovely year of stories.")
        }
        if c.finishedThisYear == 0 {
            return String(localized: "Some months are for living, not reading. Your books will wait for you.")
        }
        return String(localized: "You’ve finished **\(c.finishedThisYear) books** so far this year. What a lovely year of stories.")
    }

    /// The reader asked for a reread ("something comforting to reread", "a book I loved").
    static func asksReread(_ question: String) -> Bool {
        let q = question.lowercased()
        return ["reread", "re-read", "read again", "a book i loved", "one of my favourites", "one of my favorites"].contains { q.contains($0) }
    }
}
