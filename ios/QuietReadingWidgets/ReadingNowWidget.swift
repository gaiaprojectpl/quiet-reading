import WidgetKit
import SwiftUI
import AppIntents

/// Free · Reading now. Follows the app theme. One tap target per action:
/// "+" / Update opens the page update (typed), the rest of the widget opens the book.
/// Bottom-aligned text so short and long titles both look intentional.
struct ReadingNowWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ReadingNow", provider: SnapshotProvider()) { entry in
            ReadingNowView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Reading now")
        .description("The book you're reading, with one tap to update your page.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct ReadingNowView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular: LockCircular(book: snapshot.current).containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular: LockRectangular(book: snapshot.current).containerBackground(for: .widget) { Color.clear }
        case .accessoryInline: LockInline(book: snapshot.current).containerBackground(for: .widget) { Color.clear }
        default:
            ThemedWidget(snapshot: snapshot) {
                if let book = snapshot.current {
                    Group {
                        if family == .systemMedium { MediumReading(book: book) } else { SmallReading(book: book) }
                    }
                    .widgetURL(WidgetLink.book(book.id))
                } else {
                    NothingInProgress(medium: family == .systemMedium).widgetURL(WidgetLink.add)
                }
            }
        }
    }
}

// MARK: Home Screen

private struct SmallReading: View {
    let book: WidgetSnapshot.BookItem
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            HStack(alignment: .top) {
                WidgetCover(book: book, width: Space.s32)
                Spacer(minLength: 0)
                PlusButton(bookID: book.id)
            }
            Spacer(minLength: 0)
            Text(book.title)
                .font(theme.headline(15, relativeTo: .headline))
                .foregroundStyle(theme.palette.ink)
                .lineLimit(2)
            if let progress = book.progress { WidgetProgressBar(value: progress) }
            Text(pageLine).font(.caption2).foregroundStyle(theme.palette.ink2).lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetText.label(book))
        .accessibilityAction(named: Text("Update my page")) {}
    }

    private var pageLine: String {
        guard book.currentPage > 0 else { return book.pageCount.map { String(localized: "\($0) pages") } ?? String(localized: "Not started") }
        return [String(localized: "p. \(book.currentPage)"), WidgetText.percent(book.progress)].compactMap { $0 }.joined(separator: " · ")
    }
}

private struct MediumReading: View {
    let book: WidgetSnapshot.BookItem
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: Space.s12) {
            WidgetCover(book: book, width: Size.coverM - Space.s4)
            VStack(alignment: .leading, spacing: Space.s2) {
                Text("READING NOW").font(.system(size: 9, weight: .semibold)).tracking(0.6).foregroundStyle(theme.palette.ink2)
                Text(book.title)
                    .font(theme.headline(17, relativeTo: .headline))
                    .foregroundStyle(theme.palette.ink)
                    .lineLimit(2)
                if !book.author.isEmpty {
                    Text(book.author).font(.caption2).foregroundStyle(theme.palette.ink2).lineLimit(1)
                }
                Spacer(minLength: Space.s4)
                if let progress = book.progress { WidgetProgressBar(value: progress).padding(.bottom, Space.s4) }
                HStack(alignment: .center, spacing: Space.s8) {
                    Text(detailLine).font(.caption2).foregroundStyle(theme.palette.ink2).lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(intent: UpdateBookIntent(bookID: book.id)) {
                        Text("Update").font(.caption.weight(.semibold))
                            .foregroundStyle(theme.palette.onAccent)
                            .padding(.horizontal, Space.s12)
                            .padding(.vertical, Space.s6)
                            .background(theme.palette.accent, in: Capsule())
                            .widgetAccentable()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Update my page in \(book.title)"))
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    private var detailLine: String {
        var parts: [String] = []
        if book.currentPage > 0 {
            parts.append(book.pageCount.map { String(localized: "p. \(book.currentPage) of \($0)") } ?? String(localized: "p. \(book.currentPage)"))
        } else if let pages = book.pageCount {
            parts.append(String(localized: "\(pages) pages"))
        }
        if let t = WidgetText.timeLeft(book.minutesLeft) { parts.append(t) }
        return parts.joined(separator: " · ")
    }
}

/// Accent "+" circle: opens the page update.
private struct PlusButton: View {
    let bookID: String
    @Environment(\.theme) private var theme

    var body: some View {
        Button(intent: UpdateBookIntent(bookID: bookID)) {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.palette.onAccent)
                .frame(width: Space.s32 - Space.s4, height: Space.s32 - Space.s4)
                .background(theme.palette.accent, in: Circle())
                .widgetAccentable()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Update my page")
    }
}

private struct NothingInProgress: View {
    let medium: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            Image(systemName: "book.closed").font(.system(size: 18)).foregroundStyle(theme.palette.accentInk)
                .accessibilityHidden(true)
            Spacer(minLength: 0)
            Text("Nothing in progress").font(theme.headline(medium ? 18 : 15, relativeTo: .headline)).foregroundStyle(theme.palette.ink)
            Text("Tap to add the book you're reading.").font(.caption2).foregroundStyle(theme.palette.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: Lock Screen (rendered by iOS in its own style)

private struct LockCircular: View {
    let book: WidgetSnapshot.BookItem?

    var body: some View {
        if let book, let progress = book.progress {
            Gauge(value: progress) {
                Image(systemName: "book")
            } currentValueLabel: {
                Text(WidgetText.percent(progress) ?? "")
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetURL(WidgetLink.book(book.id))
            .accessibilityLabel(WidgetText.label(book))
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "book").font(.title3)
            }
            .widgetURL(book.map { WidgetLink.book($0.id) } ?? WidgetLink.add)
            .accessibilityLabel(book.map(WidgetText.label) ?? String(localized: "Quiet Reading"))
        }
    }
}

private struct LockRectangular: View {
    let book: WidgetSnapshot.BookItem?

    var body: some View {
        if let book {
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title).font(.headline).lineLimit(1).widgetAccentable()
                if let progress = book.progress {
                    ProgressView(value: progress).tint(.primary)
                }
                Text([book.currentPage > 0 ? String(localized: "p. \(book.currentPage)") : nil,
                      WidgetText.timeLeft(book.minutesLeft)].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(WidgetLink.book(book.id))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(WidgetText.label(book))
        } else {
            Text("Nothing in progress").font(.headline).widgetURL(WidgetLink.add)
        }
    }
}

private struct LockInline: View {
    let book: WidgetSnapshot.BookItem?

    var body: some View {
        if let book {
            Text([book.title, WidgetText.percent(book.progress)].compactMap { $0 }.joined(separator: " · "))
                .accessibilityLabel(WidgetText.label(book))
        } else {
            Text("Quiet Reading")
        }
    }
}

#Preview(as: .systemSmall) { ReadingNowWidget() } timeline: { SnapshotEntry(date: .now, snapshot: .preview) }
#Preview(as: .systemMedium) { ReadingNowWidget() } timeline: { SnapshotEntry(date: .now, snapshot: .preview) }
#Preview(as: .accessoryRectangular) { ReadingNowWidget() } timeline: { SnapshotEntry(date: .now, snapshot: .preview) }
