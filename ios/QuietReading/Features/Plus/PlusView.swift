import SwiftUI

/// Flow 5 › Paywall: "Make it yours". One payment, no subscription.
/// The price comes from the App Store; the buy button only shows once the store has answered.
/// Edge states: payment failed, nothing to restore, Ask to Buy, offline, store not answering.
struct PlusView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(PlusAccess.self) private var plus
    @Environment(NotificationCenterModel.self) private var notifications
    @Environment(Connectivity.self) private var connectivity
    @AppStorage(ThemeStorage.key) private var chosenTheme: ThemeID = .peachSage

    @State private var pick: ThemeID = .clayCream
    @State private var nothingToRestore = false
    @State private var showPrivacy = false

    private let themes: [(ThemeID, String)] = [
        (.clayCream, String(localized: "Clay")),
        (.blushIvory, String(localized: "Blush")),
        (.lavenderMist, String(localized: "Lavender")),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s20) {
                header
                if plus.store == .unavailable {
                    storeNotAnswering
                } else {
                    themeTiles
                    benefits
                    priceCard
                }
            }
            .padding(.horizontal, Space.s20)
            .padding(.bottom, Space.s16)
            .gentleAppear()
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image("qs.close").resizable().frame(width: Size.iconM, height: Size.iconM)
                        .foregroundStyle(theme.palette.ink2)
                        .frame(width: Size.touchIos, height: Size.touchIos)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, Space.s8)
            .background(theme.palette.bg)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { actions }
        .background(theme.palette.bg.ignoresSafeArea())
        .modifier(QsNotificationHost())
        // Flow 5 › Nothing to restore
        .alert("Nothing to restore", isPresented: $nothingToRestore) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We couldn’t find Plus on this account. Make sure you’re signed in with the account you used to buy it.")
        }
        .sheet(isPresented: $showPrivacy) { PrivacyNote() }
        .task {
            if let previewing = plus.previewTheme, previewing.requiresPlus { pick = previewing }
            if !connectivity.isOnline { showOffline() }
            await plus.loadProduct()
        }
        .onChange(of: connectivity.isOnline) { _, online in
            if online, plus.store == .unavailable { Task { await plus.loadProduct() } }
        }
    }

    // MARK: Parts

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            HStack(spacing: Space.s8) {
                Image("qs.logo").resizable()
                    .foregroundStyle(theme.palette.bg)
                    .frame(width: Space.s24, height: Space.s24)
                    .background(theme.palette.accent, in: RoundedRectangle(cornerRadius: Space.s6, style: .continuous))
                Text("Quiet Reading").font(theme.headline(18, relativeTo: .headline)).foregroundStyle(theme.palette.ink)
                Image("qs.crown").resizable().frame(width: Size.iconS, height: Size.iconS)
                    .foregroundStyle(theme.palette.accentInk)
                Text("PLUS").font(.caption.weight(.semibold)).tracking(1).foregroundStyle(theme.palette.accentInk)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Quiet Reading Plus")
            Text("Make it yours")
                .font(theme.headline(30, relativeTo: .largeTitle))
                .foregroundStyle(theme.palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("One small payment. No subscription, no ads, ever.")
                .font(.body).foregroundStyle(theme.palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var themeTiles: some View {
        HStack(alignment: .top, spacing: Space.s8) {
            ForEach(themes, id: \.0) { id, name in
                Button { pick = id } label: {
                    ThemePreviewCard(id: id, title: name, isSelected: pick == id, compact: true)
                }
                .buttonStyle(QsPressStyle())
                .accessibilityHint("Turns on after you unlock Plus")
            }
        }
        .gentleAnimation(pick, duration: Motion.fast)
        .sensoryFeedback(.selection, trigger: pick)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            benefit("qs.palette", "3 extra app themes")
            benefit("qs.widgets", "20+ widget styles: Soft, Modern, Colourful", soon: true)
            benefit("qs.stats", "Patterns: moods, pace, time of day", soon: true)
            benefit("qs.pencil", "Pencil margin notes on iPhone Duo", soon: true)
        }
    }

    private func benefit(_ icon: String, _ text: LocalizedStringKey, soon: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s12) {
            Image(icon).resizable().frame(width: Size.iconS, height: Size.iconS)
                .foregroundStyle(theme.palette.accentInk)
                .frame(width: Space.s24, height: Space.s24)
                .background(theme.palette.soft2, in: Circle())
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.s2) {
                Text(text).font(.subheadline).foregroundStyle(theme.palette.ink)
                if soon {
                    Text("Coming soon, included").font(.caption).foregroundStyle(theme.palette.ink2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var priceCard: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            if case .ready(let price) = plus.store {
                Text("\(price) · once").font(theme.headline(22, relativeTo: .title2)).foregroundStyle(theme.palette.ink)
                    .transition(.opacity)
            } else {
                // Skeleton while the App Store answers (no shimmer).
                RoundedRectangle(cornerRadius: theme.radii.inner, style: .continuous)
                    .fill(theme.palette.disabledBg)
                    .frame(width: Space.s80 + Space.s20, height: Space.s24)
                    .accessibilityLabel("Loading the price")
            }
            Text("Price shown in your currency at checkout. One-time purchase for your account, not shared with family.")
                .font(.footnote).foregroundStyle(theme.palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.palette.soft, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
        .animation(.easeOut(duration: Motion.base), value: plus.store)
    }

    /// Store didn't answer within 8 seconds (or isn't reachable).
    private var storeNotAnswering: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text("The store isn’t answering").font(theme.headline(22, relativeTo: .title2)).foregroundStyle(theme.palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Plus can wait. Everything free still works, and you weren’t charged.")
                .font(.body).foregroundStyle(theme.palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.palette.infoSoft, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
        .padding(.top, Space.s8)
    }

    private var actions: some View {
        VStack(spacing: Space.s4) {
            switch plus.store {
            case .ready(let price):
                Button {
                    Task { await buy() }
                } label: {
                    if plus.isBusy {
                        ProgressView().tint(theme.palette.onAccent)
                            .accessibilityLabel("Waiting for the App Store")
                    } else {
                        Text("Unlock Plus for \(price)")
                    }
                }
                .buttonStyle(QsButtonStyle(priority: .primary))
                .disabled(plus.isBusy)
                links
            case .loading:
                RoundedRectangle(cornerRadius: theme.radii.btn, style: .continuous)
                    .fill(theme.palette.disabledBg)
                    .frame(height: Size.button)
                    .accessibilityHidden(true)
                links
            case .unavailable:
                Button("Try again") { Task { await plus.loadProduct() } }
                    .buttonStyle(QsButtonStyle(priority: .primary))
                Button("Not now") { dismiss() }
                    .buttonStyle(QsButtonStyle(priority: .text))
            }
        }
        .padding(.horizontal, Space.s20)
        .padding(.top, Space.s12)
        .padding(.bottom, QsLayout.actionsAboveBottomLine)
        .background(theme.palette.bg)
        .animation(.easeOut(duration: Motion.base), value: plus.store)
    }

    private var links: some View {
        HStack(spacing: Space.s4) {
            linkButton("Restore purchase") { Task { await restore() } }
            linkButton("Terms") { openURL(PlusLinks.terms) }
            linkButton("Privacy") { showPrivacy = true }
            linkButton("Refunds") { openURL(PlusLinks.refunds) }
        }
        .frame(maxWidth: .infinity)
    }

    private func linkButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.footnote)
            .foregroundStyle(theme.palette.ink2)
            .padding(.horizontal, Space.s4)
            .frame(minHeight: Size.touchIos)
            .disabled(plus.isBusy)
    }

    // MARK: Actions

    private func showOffline() {
        notifications.show(String(localized: "You’re offline"),
                           message: String(localized: "Connect to buy or restore Plus."), kind: .info)
    }

    private func buy() async {
        guard connectivity.isOnline else { showOffline(); return }
        switch await plus.purchase() {
        case .unlocked:
            chosenTheme = pick
            plus.previewTheme = nil
            dismiss()
            notifications.show(String(localized: "Plus unlocked"),
                               message: String(localized: "\(pick.displayName) is on. Thank you for supporting a small app."))
        case .pending:
            notifications.show(String(localized: "Waiting for approval"),
                               message: String(localized: "Ask to Buy sent. Plus unlocks when it’s approved."), kind: .info)
        case .failed:
            notifications.show(String(localized: "Payment didn’t go through"),
                               message: String(localized: "You weren’t charged. Check your payment method and try again."), kind: .error)
        case .cancelled:
            break   // the reader changed their mind; nothing to say
        }
    }

    private func restore() async {
        guard connectivity.isOnline else { showOffline(); return }
        switch await plus.restore() {
        case .restored:
            plus.previewTheme = nil
            dismiss()
            notifications.show(String(localized: "Plus is back"),
                               message: String(localized: "Your themes and icons are ready in Settings."))
        case .nothing:
            nothingToRestore = true
        case .failed:
            notifications.show(String(localized: "Couldn’t reach the App Store"),
                               message: String(localized: "Nothing changed. Try again in a moment."), kind: .error)
        }
    }
}

enum PlusLinks {
    /// Apple's standard licence agreement (until Quiet Reading has its own terms).
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// Apple handles refunds for App Store purchases.
    static let refunds = URL(string: "https://support.apple.com/118223")!
}

/// Short, true privacy note until the full policy page exists.
private struct PrivacyNote: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            Text("Your privacy").font(theme.headline(22, relativeTo: .title2)).foregroundStyle(theme.palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Your books, notes and quotes stay on this phone. Quiet Reading has no ads and no tracking. The App Store handles payment, so we never see your card.")
                .font(.body).foregroundStyle(theme.palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Done") { dismiss() }.buttonStyle(QsButtonStyle(priority: .secondary))
                .padding(.bottom, QsLayout.actionsAboveBottomLine)
        }
        .padding(.horizontal, Space.s20)
        .padding(.top, Space.s24)
        .background(theme.palette.surface.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationCornerRadius(theme.radii.sheet)
    }
}
