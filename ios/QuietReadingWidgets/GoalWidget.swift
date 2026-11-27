import WidgetKit
import SwiftUI

/// Free · Small · Goal: the yearly goal ring with a number (never colour alone). "No rush."
struct GoalWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Goal", provider: SnapshotProvider()) { entry in
            ThemedWidget(snapshot: entry.snapshot) { GoalView(snapshot: entry.snapshot) }
                .widgetURL(WidgetLink.stats)
        }
        .configurationDisplayName("Reading goal")
        .description("Books finished this year. Goals are optional and never shame.")
        .supportedFamilies([.systemSmall])
    }
}

private struct GoalView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.theme) private var theme

    private var fraction: Double {
        snapshot.goal > 0 ? min(1, Double(snapshot.finishedThisYear) / Double(snapshot.goal)) : 0
    }

    private var caption: String {
        snapshot.goal > 0
            ? String(localized: "of \(snapshot.goal) books in \(String(snapshot.year))")
            : String(localized: "books in \(String(snapshot.year))")
    }

    var body: some View {
        VStack(spacing: Space.s6) {
            ZStack {
                Circle().stroke(theme.palette.chartTrack, lineWidth: Space.s6)
                Circle().trim(from: 0, to: fraction)
                    .stroke(theme.palette.accent, style: StrokeStyle(lineWidth: Space.s6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .widgetAccentable()
                Text("\(snapshot.finishedThisYear)")
                    .font(theme.headline(30, relativeTo: .title))
                    .foregroundStyle(theme.palette.ink)
            }
            .frame(width: Size.coverM + Space.s8, height: Size.coverM + Space.s8)
            VStack(spacing: 0) {
                Text(caption).font(.caption2).foregroundStyle(theme.palette.ink2)
                if snapshot.goal > 0, snapshot.finishedThisYear < snapshot.goal {
                    Text("No rush").font(.caption2.weight(.semibold)).foregroundStyle(theme.palette.ink2)
                }
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(snapshot.goal > 0
            ? String(localized: "\(snapshot.finishedThisYear) of \(snapshot.goal) books in \(String(snapshot.year)). No rush.")
            : String(localized: "\(snapshot.finishedThisYear) books in \(String(snapshot.year))"))
    }
}

#Preview(as: .systemSmall) { GoalWidget() } timeline: { SnapshotEntry(date: .now, snapshot: .preview) }
