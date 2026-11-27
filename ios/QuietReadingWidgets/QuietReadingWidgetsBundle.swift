import WidgetKit
import SwiftUI

/// Quiet Reading widgets (Figma › 🧱 Components › Widgets Final, 177:16015).
/// Free: Reading now (small, medium, Lock Screen, StandBy) and the goal ring, in the app theme.
@main
struct QuietReadingWidgetsBundle: WidgetBundle {
    init() { QsFonts.register() }

    var body: some Widget {
        ReadingNowWidget()
        GoalWidget()
    }
}

// MARK: - Timeline

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// The app writes a fresh snapshot and reloads timelines after every change, so one entry is enough.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry { SnapshotEntry(date: .now, snapshot: .preview) }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? (WidgetSnapshot.load() ?? .preview) : (WidgetSnapshot.load() ?? .preview)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load() ?? WidgetSnapshot())
        // Refresh after midnight so "this week" and the year roll over on their own.
        let tomorrow = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }
}

// MARK: - Theme

/// Same resolution as the app: High contrast > Night (Dark Mode) > the chosen theme.
struct ThemedWidget<Content: View>: View {
    let snapshot: WidgetSnapshot
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    private var theme: ThemeID {
        if contrast == .increased || snapshot.forceHighContrast { return .highContrast }
        if scheme == .dark { return .night }
        return snapshot.theme
    }

    var body: some View {
        content
            .environment(\.theme, theme)
            .containerBackground(for: .widget) { theme.palette.surface }
    }
}

// MARK: - Shared pieces

/// Small cover from the App Group, or a soft placeholder with the title's initials.
struct WidgetCover: View {
    let book: WidgetSnapshot.BookItem
    let width: CGFloat
    @Environment(\.theme) private var theme

    private var initials: String {
        book.title.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: max(theme.radii.cover / 2, 2), style: .continuous)
        Group {
            if let url = WidgetSnapshot.coverURL(book.coverFile), let image = UIImage(contentsOfFile: url.path()) {
                Image(uiImage: image).resizable().widgetAccentedRenderingMode(.desaturated)
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    theme.palette.soft
                    Text(initials).font(theme.headline(width / 3.2, relativeTo: .caption)).foregroundStyle(theme.palette.ink2)
                }
            }
        }
        .frame(width: width, height: width * 1.5)
        .clipShape(shape)
        .accessibilityHidden(true)
    }
}

struct WidgetProgressBar: View {
    let value: Double
    var height: CGFloat = Space.s4
    @Environment(\.theme) private var theme

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.palette.chartTrack)
                Capsule().fill(theme.palette.accent).frame(width: max(height, geo.size.width * value))
                    .widgetAccentable()
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

enum WidgetText {
    static func timeLeft(_ minutes: Int?) -> String? {
        guard let minutes, minutes > 0 else { return nil }
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return String(localized: "\(m) min left") }
        if m == 0 { return String(localized: "\(h) h left") }
        return String(localized: "\(h) h \(m) min left")
    }

    static func percent(_ value: Double?) -> String? {
        value.map { $0.formatted(.percent.precision(.fractionLength(0))) }
    }

    /// "Reading: Anne of Green Gables by L. M. Montgomery, 46 percent, page 142 of 310".
    static func label(_ b: WidgetSnapshot.BookItem) -> String {
        var parts = [String(localized: "Reading: \(b.title)")]
        if !b.author.isEmpty { parts[0] += String(localized: " by \(b.author)") }
        if let p = percent(b.progress) { parts.append(p) }
        if b.currentPage > 0 {
            parts.append(b.pageCount.map { String(localized: "page \(b.currentPage) of \($0)") } ?? String(localized: "page \(b.currentPage)"))
        }
        if let t = timeLeft(b.minutesLeft) { parts.append(t) }
        return parts.joined(separator: ", ")
    }
}
