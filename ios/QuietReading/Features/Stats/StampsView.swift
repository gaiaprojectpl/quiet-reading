import SwiftUI

/// One stamp: a soft circle with its icon. Earned = filled soft with accent ink; locked = dashed outline.
struct StampBadge: View {
    let stamp: Stamp
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .body) private var size = Space.s48

    var body: some View {
        VStack(spacing: Space.s4) {
            ZStack {
                if stamp.earned {
                    Circle().fill(theme.palette.soft)
                    Circle().strokeBorder(theme.palette.accentInk.opacity(0.6), style: StrokeStyle(lineWidth: Size.stroke, dash: [3, 3]))
                        .padding(Space.s2)
                } else {
                    Circle().strokeBorder(theme.palette.lineStrong.opacity(0.6), style: StrokeStyle(lineWidth: Size.stroke, dash: [3, 3]))
                }
                Image(stamp.icon).resizable().frame(width: Size.iconM, height: Size.iconM)
                    .foregroundStyle(stamp.earned ? theme.palette.accentInk : theme.palette.ink2)
            }
            .frame(width: size, height: size)
            Text(stamp.name).font(.caption2).foregroundStyle(stamp.earned ? theme.palette.ink : theme.palette.ink2)
                .multilineTextAlignment(.center).lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stamp.name)
        .accessibilityValue(stamp.earned ? String(localized: "Collected") : String(localized: "Not yet. \(stamp.how)"))
    }
}

/// Grid of stamps used on Stats (first row) and on Reading stamps (all).
struct StampGrid: View {
    let stamps: [Stamp]
    var onTap: (Stamp) -> Void = { _ in }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.s8), count: 4), spacing: Space.s16) {
            ForEach(stamps) { stamp in
                Button { onTap(stamp) } label: { StampBadge(stamp: stamp) }
                    .buttonStyle(QsPressStyle())
            }
        }
    }
}

/// Flow 8b › Reading stamps. "Collect, don't compete. Stamps never expire and nothing resets."
struct StampsView: View {
    let stats: ReadingStats
    @Environment(\.theme) private var theme
    @AppStorage(SeasonalChallenge.joinedKey) private var joined = false
    @State private var detail: Stamp?
    @State private var showJoin = false

    private var challenge: SeasonalChallenge? { SeasonalChallenge(stats: stats) }
    private var stamps: [Stamp] { Stamp.all(stats, autumnDone: joined && (challenge?.done ?? false)) }

    var body: some View {
        PinnedBackScroll(backTitle: "Stats") {
            VStack(alignment: .leading, spacing: Space.s16) {
                ScreenTitle(title: "Reading stamps")
                Text("Collect, don’t compete. Stamps never expire and nothing resets.")
                    .font(.subheadline).foregroundStyle(theme.palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                StatsCard(title: "Reading stamps", summary: String(localized: "Stamps are kept forever. Tap a locked one to see how to get it.")) {
                    Text("\(stamps.filter(\.earned).count) of \(stamps.count)").font(.caption).foregroundStyle(theme.palette.ink2)
                } content: {
                    StampGrid(stamps: stamps) { detail = $0 }
                }
                if let challenge { ChallengeCard(challenge: challenge, joined: joined) { showJoin = true } }
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s8)
            .padding(.bottom, Space.s24)
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $detail) { StampDetail(stamp: $0) }
        .sheet(isPresented: $showJoin) {
            if let challenge { JoinChallengeSheet(challenge: challenge, joined: $joined) }
        }
    }
}

/// "Cozy autumn · opt-in · ends 21 Dec – Read 3 books that felt cozy".
struct ChallengeCard: View {
    let challenge: SeasonalChallenge
    let joined: Bool
    let onTap: () -> Void
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .body) private var cover = Space.s40

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Space.s8) {
                HStack {
                    Image("qs.flash").resizable().frame(width: Size.iconS, height: Size.iconS).accessibilityHidden(true)
                    Text(joined ? "Cozy autumn · joined" : "Cozy autumn · opt-in").font(.caption.weight(.semibold))
                    Spacer()
                    Text("ends \(challenge.end.formatted(.dateTime.day().month(.abbreviated)))").font(.caption)
                }
                .foregroundStyle(theme.palette.ink2)
                Text("Read \(challenge.goal) books that felt cozy").font(theme.headline(20, relativeTo: .title3)).foregroundStyle(theme.palette.ink)
                HStack(spacing: Space.s8) {
                    ForEach(0..<challenge.goal, id: \.self) { i in
                        if i < challenge.books.count {
                            BookCover(source: .data(challenge.books[i].coverData), title: challenge.books[i].title, width: cover)
                        } else {
                            RoundedRectangle(cornerRadius: theme.radii.cover, style: .continuous)
                                .strokeBorder(theme.palette.lineStrong, style: StrokeStyle(lineWidth: Size.stroke, dash: [4, 3]))
                                .frame(width: cover, height: cover * 1.5)
                                .overlay(Text("?").font(.subheadline).foregroundStyle(theme.palette.ink2))
                        }
                    }
                }
                .accessibilityHidden(true)
                Text("\(min(challenge.books.count, challenge.goal)) of \(challenge.goal) · reward: “Autumn reads” stamp")
                    .font(.footnote).foregroundStyle(theme.palette.ink2)
            }
            .padding(Space.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.palette.soft, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(QsPressStyle())
        .accessibilityElement(children: .combine)
    }
}

/// Opt-in sheet: "Read 3 books that felt cozy. Books you already finished this autumn count. Leaving is one tap, nothing is lost."
struct JoinChallengeSheet: View {
    let challenge: SeasonalChallenge
    @Binding var joined: Bool
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            Text("Cozy autumn").font(theme.headline(24, relativeTo: .title2)).foregroundStyle(theme.palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Opt-in · ends \(challenge.end.formatted(.dateTime.day().month(.wide)))").font(.footnote).foregroundStyle(theme.palette.ink2)
            Text("Read \(challenge.goal) books that felt cozy. Books you already finished this autumn count. Leaving is one tap, nothing is lost.")
                .font(.body).foregroundStyle(theme.palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack(spacing: Space.s12) {
                if joined {
                    Button("Leave") { joined = false; dismiss() }.buttonStyle(QsButtonStyle(priority: .outline))
                    Button("Keep going") { dismiss() }.buttonStyle(QsButtonStyle(priority: .primary))
                } else {
                    Button("Join") { joined = true; dismiss() }.buttonStyle(QsButtonStyle(priority: .primary))
                    Button("Not now") { dismiss() }.buttonStyle(QsButtonStyle(priority: .outline))
                }
            }
            .padding(.bottom, QsLayout.actionsAboveBottomLine)
        }
        .padding(.horizontal, Space.s20)
        .padding(.top, Space.s24)
        .background(theme.palette.surface.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationCornerRadius(theme.radii.sheet)
        .sensoryFeedback(.success, trigger: joined) { _, new in new }
    }
}

private struct StampDetail: View {
    let stamp: Stamp
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Space.s12) {
            StampBadge(stamp: stamp).frame(width: Space.s80)
            Text(stamp.earned ? "Collected" : "Not yet").font(theme.headline(20, relativeTo: .title3)).foregroundStyle(theme.palette.ink)
            Text(stamp.how).font(.body).foregroundStyle(theme.palette.ink2).multilineTextAlignment(.center)
            if !stamp.earned, let p = stamp.progress {
                VStack(spacing: Space.s4) {
                    QsProgressBar(value: Double(p.current) / Double(p.target), size: .s)
                    Text("\(p.current.formatted()) of \(p.target.formatted())").font(.footnote).foregroundStyle(theme.palette.ink2)
                }
                .frame(maxWidth: 220)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(Space.s24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.surface.ignoresSafeArea())
        .presentationDetents([.height(300)])
        .presentationCornerRadius(theme.radii.sheet)
    }
}
