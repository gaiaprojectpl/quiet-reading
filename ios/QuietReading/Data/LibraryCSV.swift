import Foundation

/// A book read from an export file, before it is saved.
nonisolated struct ImportedBook: Sendable, Equatable {
    var title: String
    var author: String
    var isbn: String?
    var pageCount: Int?
    var status: ReadingStatus
    var dateFinished: Date?
    var rating: Int?
    var source: BookSource
}

nonisolated enum LibraryCSVError: Error, Equatable {
    case unreadable, notRecognised, empty
}

/// Reads Goodreads ("My Books › Import and export") and StoryGraph ("Manage account › Export") CSV files.
/// The format is detected from the header, so either file works whichever row the reader tapped.
nonisolated enum LibraryCSV {
    static func parse(_ data: Data) throws -> [ImportedBook] {
        guard var text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw LibraryCSVError.unreadable
        }
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        let rows = CSV.rows(text)
        guard let header = rows.first else { throw LibraryCSVError.empty }
        let columns = Dictionary(header.enumerated().map { ($1.trimmingCharacters(in: .whitespaces), $0) },
                                 uniquingKeysWith: { first, _ in first })

        let books: [ImportedBook]
        if columns["Exclusive Shelf"] != nil, columns["Title"] != nil {
            books = rows.dropFirst().compactMap { goodreads($0, columns) }
        } else if columns["Read Status"] != nil, columns["Title"] != nil {
            books = rows.dropFirst().compactMap { storyGraph($0, columns) }
        } else {
            throw LibraryCSVError.notRecognised
        }
        guard !books.isEmpty else { throw LibraryCSVError.empty }
        return books
    }

    // MARK: Formats

    private static func goodreads(_ row: [String], _ c: [String: Int]) -> ImportedBook? {
        func v(_ key: String) -> String { value(row, c[key]) }
        let title = v("Title")
        guard !title.isEmpty else { return nil }
        let isbn = cleanISBN(v("ISBN13")) ?? cleanISBN(v("ISBN"))
        return ImportedBook(
            title: title,
            author: v("Author"),
            isbn: isbn,
            pageCount: Int(v("Number of Pages")).flatMap { $0 > 0 ? $0 : nil },
            status: status(v("Exclusive Shelf")),
            dateFinished: date(v("Date Read")),
            rating: Int(v("My Rating")).flatMap { $0 > 0 ? $0 : nil },
            source: .goodreads
        )
    }

    private static func storyGraph(_ row: [String], _ c: [String: Int]) -> ImportedBook? {
        func v(_ key: String) -> String { value(row, c[key]) }
        let title = v("Title")
        guard !title.isEmpty else { return nil }
        return ImportedBook(
            title: title,
            author: v("Authors"),
            isbn: cleanISBN(v("ISBN/UID")),
            pageCount: nil,
            status: status(v("Read Status")),
            dateFinished: date(v("Last Date Read")),
            rating: Double(v("Star Rating")).map { Int($0.rounded()) }.flatMap { $0 > 0 ? $0 : nil },
            source: .storyGraph
        )
    }

    // MARK: Helpers

    private static func value(_ row: [String], _ index: Int?) -> String {
        guard let index, index < row.count else { return "" }
        return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func status(_ raw: String) -> ReadingStatus {
        switch raw.lowercased() {
        case "currently-reading": .reading
        case "read": .read
        case "did-not-finish": .stopped
        default: .toRead
        }
    }

    /// Goodreads writes ISBNs as ="9780…". Keep digits (and a final X) only.
    private static func cleanISBN(_ raw: String) -> String? {
        let digits = raw.uppercased().filter { $0.isNumber || $0 == "X" }
        return (digits.count == 10 || digits.count == 13) ? digits : nil
    }

    private static func date(_ raw: String) -> Date? {
        guard !raw.isEmpty else { return nil }
        for format in ["yyyy/MM/dd", "yyyy-MM-dd", "yyyy/MM", "yyyy"] {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = format
            if let d = f.date(from: raw) { return d }
        }
        return nil
    }
}

/// Minimal RFC 4180 CSV reader (quoted fields, escaped quotes, CRLF or LF).
nonisolated enum CSV {
    static func rows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var scalars = text.unicodeScalars.makeIterator()
        var pending: Unicode.Scalar? = scalars.next()

        while let ch = pending {
            pending = scalars.next()
            if inQuotes {
                if ch == "\"" {
                    if pending == "\"" { field.unicodeScalars.append("\""); pending = scalars.next() }
                    else { inQuotes = false }
                } else {
                    field.unicodeScalars.append(ch)
                }
                continue
            }
            switch ch {
            case "\"": inQuotes = true
            case ",": row.append(field); field = ""
            case "\r": break
            case "\n":
                row.append(field); field = ""
                if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
                row = []
            default: field.unicodeScalars.append(ch)
            }
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }
}
