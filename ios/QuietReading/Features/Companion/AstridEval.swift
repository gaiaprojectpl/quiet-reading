#if DEBUG
import SwiftUI
import SwiftData

/// Test builds only: Astrid's evaluation set (docs/ai-companion.md › Safeguards).
/// 30 reader profiles (10 tastes × 3 questions), real books only. Each answer is checked against
/// Astrid's rules and the results are written to Documents/astrid-eval.json.
/// Run with `-qsAstridEval 30` (or a smaller number for a quick check).
@MainActor
enum AstridEval {
    struct Taste { let name: String; let books: [(String, String, Double, [String])] }

    static let tastes: [Taste] = [
        Taste(name: "Cosy fantasy", books: [("Legends & Lattes", "Travis Baldree", 5, ["Cozy"]), ("The House in the Cerulean Sea", "TJ Klune", 5, ["Hopeful"]), ("A Psalm for the Wild-Built", "Becky Chambers", 4.5, ["Slow"]), ("Howl's Moving Castle", "Diana Wynne Jones", 4, ["Funny"])]),
        Taste(name: "Literary quiet", books: [("Klara and the Sun", "Kazuo Ishiguro", 4.5, ["Slow"]), ("Small Things Like These", "Claire Keegan", 5, ["Hopeful"]), ("Gilead", "Marilynne Robinson", 4, ["Slow"]), ("Stoner", "John Williams", 5, ["Sad"])]),
        Taste(name: "Classics", books: [("Pride and Prejudice", "Jane Austen", 5, ["Funny"]), ("Jane Eyre", "Charlotte Brontë", 4.5, ["Dark"]), ("Middlemarch", "George Eliot", 4, ["Slow"]), ("Anne of Green Gables", "L. M. Montgomery", 5, ["Cozy"])]),
        Taste(name: "Mystery", books: [("The Thursday Murder Club", "Richard Osman", 4, ["Funny"]), ("And Then There Were None", "Agatha Christie", 5, ["Dark"]), ("The Secret History", "Donna Tartt", 4.5, ["Dark"]), ("Magpie Murders", "Anthony Horowitz", 4, ["Cozy"])]),
        Taste(name: "Romance", books: [("Beach Read", "Emily Henry", 4, ["Funny"]), ("People We Meet on Vacation", "Emily Henry", 4.5, ["Hopeful"]), ("The Kiss Quotient", "Helen Hoang", 4, ["Cozy"]), ("Persuasion", "Jane Austen", 5, ["Slow"])]),
        Taste(name: "Science fiction", books: [("Project Hail Mary", "Andy Weir", 5, ["Hopeful"]), ("The Left Hand of Darkness", "Ursula K. Le Guin", 4.5, ["Slow"]), ("Station Eleven", "Emily St. John Mandel", 4.5, ["Sad"]), ("Dune", "Frank Herbert", 4, ["Dark"])]),
        Taste(name: "Historical", books: [("Wolf Hall", "Hilary Mantel", 4.5, ["Slow"]), ("The Book Thief", "Markus Zusak", 5, ["Sad"]), ("Pachinko", "Min Jin Lee", 5, ["Hopeful"]), ("The Nightingale", "Kristin Hannah", 4, ["Sad"])]),
        Taste(name: "Magical", books: [("The Night Circus", "Erin Morgenstern", 5, ["Cozy"]), ("Piranesi", "Susanna Clarke", 4.5, ["Slow"]), ("Circe", "Madeline Miller", 5, ["Hopeful"]), ("The Midnight Library", "Matt Haig", 4, ["Hopeful"])]),
        Taste(name: "Non-fiction", books: [("Braiding Sweetgrass", "Robin Wall Kimmerer", 5, ["Hopeful"]), ("Educated", "Tara Westover", 4.5, ["Dark"]), ("Quiet", "Susan Cain", 4, ["Slow"]), ("H is for Hawk", "Helen Macdonald", 4, ["Sad"])]),
        Taste(name: "New reader", books: [("The Little Prince", "Antoine de Saint-Exupéry", 5, ["Hopeful"])]),
    ]

    /// Persona v0.3: conversation questions (no cards, no stats) + book requests + a goal question.
    static let questions = ["Who are you?", "Hi", "Recommend me something", "Something short and cosy. I’m tired this week.",
                            "How is my reading year going?", "Should I read more?", "I just finished The Night Circus."]
    static let noCards: Set<String> = ["Who are you?", "Hi", "Recommend me something", "How is my reading year going?",
                                       "Should I read more?", "I just finished The Night Circus."]
    static let avoided = ["only", "behind", "should", "must", "failed", "streak", "hurry", "guilty pleasure", "actually", "obviously"]

    struct Result: Codable { let taste: String; let question: String; let text: String; let picks: [String]; let problems: [String]; let seconds: Double }

    static func run(limit: Int) async {
        let container = try! ModelContainer(for: Book.self, ReadingSession.self, Quote.self,
                                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        var results: [Result] = []
        var n = 0
        outer: for taste in tastes {
            let ctx = ModelContext(container)
            let books = taste.books.map { t, a, stars, moods -> Book in
                let b = Book(title: t, author: a, isbn: nil, pageCount: 300, status: .read, source: .manual)
                b.stars = stars; b.moods = moods; b.dateFinished = .now.addingTimeInterval(-86_400 * 30)
                ctx.insert(b)
                return b
            }
            for q in questions {
                if n >= limit { break outer }
                n += 1
                let start = Date.now
                let store = CompanionStore()
                store.messages = []
                store.send(q, books: books, goal: 24)
                while store.phase != .idle { try? await Task.sleep(for: .milliseconds(300)) }
                let answer = store.messages.last { $0.role == .companion }
                results.append(check(taste: taste, question: q, answer: answer, seconds: Date.now.timeIntervalSince(start)))
                store.deleteHistory()
            }
        }
        let url = URL.documentsDirectory.appending(path: "astrid-eval.json")
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted]
        try? enc.encode(results).write(to: url)
        let failed = results.filter { !$0.problems.isEmpty }.count
        print("Astrid eval: \(results.count) answers, \(failed) with problems → \(url.path)")
    }

    private static func check(taste: Taste, question: String, answer: CompanionMessage?, seconds: Double) -> Result {
        guard let a = answer else {
            return Result(taste: taste.name, question: question, text: "", picks: [], problems: ["no answer"], seconds: seconds)
        }
        var problems: [String] = []
        let own = Set(taste.books.map { CompanionContext.key($0.0) })
        for p in a.picks where own.contains(CompanionContext.key(p.title)) { problems.append("picked a book they already read: \(p.title)") }
        if a.picks.count > 3 { problems.append("more than 3 picks") }
        if a.text.contains("!") { problems.append("exclamation mark") }
        if a.text.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation }) { problems.append("emoji") }
        if a.text.contains("http") { problems.append("link") }
        if a.text.split(separator: "\n").contains(where: { $0.hasPrefix("#") }) { problems.append("heading") }
        let lower = " " + a.text.lowercased() + " "
        for w in avoided where !(w == "only" && lower.contains(" only know ")) && lower.contains(" \(w) ") || lower.contains(" \(w),") || lower.contains(" \(w).") { problems.append("avoided word: \(w)") }
        let words = a.text.split { $0 == " " || $0 == "\n" }.count
        if words > 120 { problems.append("too long (\(words) words)") }
        if a.status == .failed { problems.append("error: \(a.text)") }
        if question.contains("year"), !a.showGoal { problems.append("year question without the goal card") }
        if noCards.contains(question), !a.picks.isEmpty { problems.append("book cards where the persona says none") }
        if !question.contains("year"), a.showGoal || lower.contains(" goal") { problems.append("brought up goals unasked") }
        if question.contains("year"), lower.contains(" pace") || lower.contains(" should ") { problems.append("goal advice") }
        if question == "Recommend me something", !a.text.contains("?") { problems.append("vague request without one question") }
        if a.text.filter({ $0 == "?" }).count > 1 { problems.append("more than one question") }
        if question.contains("year"), !a.picks.isEmpty { problems.append("book picks in a numbers answer") }
        let numberWords = ["one": 1, "two": 2, "three": 3]
        for (w, n) in numberWords where lower.contains(" \(w) ") || lower.contains("**\(w) ") {
            if !a.picks.isEmpty && a.picks.count != n { problems.append("says \(w) but shows \(a.picks.count) card(s)") }
        }
        if lower.contains(" they ") && !lower.contains(" they’re ") { problems.append("talks about the reader in the third person") }
        return Result(taste: taste.name, question: question, text: a.text, picks: a.picks.map { "\($0.title) by \($0.author)" }, problems: problems, seconds: seconds)
    }
}
#endif
