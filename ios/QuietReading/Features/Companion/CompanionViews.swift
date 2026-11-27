import SwiftUI
import SwiftData

// MARK: - AI button

/// 🧱 Components › AI button. Floating (iPhone, 56 pt, bottom-trailing above the tab bar, Elevation/2)
/// or Side bar (iPhone Duo, 48 pt, docked above the rail). Hidden while the chat is open.
struct CompanionButton: View {
    var size: CGFloat = 56
    @Environment(\.theme) private var theme
    @Environment(CompanionStore.self) private var companion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glow = false

    var body: some View {
        Button { companion.isOpen = true } label: {
            Image("qs.sparkles").resizable()
                .frame(width: Size.iconL, height: Size.iconL)
                .foregroundStyle(theme.palette.onAi)
                .scaleEffect(glow ? 1.06 : 1)
                .frame(width: size, height: size)
                .background(theme.palette.ai, in: Circle())
                .shadow(color: theme.palette.scrim.opacity(0.10), radius: 8, x: 0, y: 4) // Elevation/2
                .contentShape(Circle())
        }
        .buttonStyle(QsPressStyle())
        .accessibilityLabel("Astrid, your reading companion")
        .accessibilityHint("Chat about your books")
        .onAppear {
            // One soft "breath" when it appears, so it's noticed without nagging.
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: Motion.slow).repeatCount(2, autoreverses: true)) { glow = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + Motion.slow * 2) { glow = false }
        }
    }
}

// MARK: - Root (consent first, then chat)

struct CompanionScreen: View {
    var showsClose = true
    @Environment(CompanionStore.self) private var companion

    var body: some View {
        if companion.isEnabled {
            CompanionChatView(showsClose: showsClose)
        } else {
            CompanionConsentView()
        }
    }
}

// MARK: - Consent (Flow 12 › Step 2)

/// Shown once before the first chat (App Store 5.1.2, GDPR). Says plainly what the companion sees,
/// what it never sees and where it runs. "Not now" keeps the whole app usable.
struct CompanionConsentView: View {
    @Environment(\.theme) private var theme
    @Environment(CompanionStore.self) private var companion
    @AppStorage(CompanionKeys.includeNotes) private var includeNotes = false
    @ScaledMetric(relativeTo: .title) private var hero = Space.s64 + Space.s8

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s20) {
                Image("qs.sparkles").resizable().frame(width: Space.s32, height: Space.s32)
                    .foregroundStyle(theme.palette.aiInk)
                    .frame(width: hero, height: hero)
                    .background(theme.palette.aiSoft, in: Circle())
                    .accessibilityHidden(true)
                    .gentleAppear()
                VStack(alignment: .leading, spacing: Space.s8) {
                    Text("Meet Astrid, your reading companion").font(theme.headline(26, relativeTo: .title)).foregroundStyle(theme.palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("Astrid is an AI. Chat about your books, get ideas for what to read next and see how your reading is going.")
                        .font(.subheadline).foregroundStyle(theme.palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                box("What it can see", items: ["Your shelves, ratings and finish tags", "Reading progress and goals"], fill: theme.palette.surface)
                box("What it never sees", items: ["Your name, email, photo or location", "Your notes, unless you turn them on"], fill: theme.palette.soft2)
                Text("Runs on your iPhone with Apple Intelligence. Your questions and books don’t leave your phone. Book ideas are looked up in public catalogues by title only.")
                    .font(.footnote).foregroundStyle(theme.palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle("Include my notes", isOn: $includeNotes)
                    .font(.body).foregroundStyle(theme.palette.ink).tint(theme.palette.accent)
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s24)
            .padding(.bottom, Space.s16)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: Space.s8) {
                Button("Turn on Astrid") {
                    withAnimation(.easeOut(duration: Motion.base)) { companion.isEnabled = true }
                }
                .buttonStyle(QsButtonStyle(priority: .primary))
                Button("Not now") { companion.isOpen = false }
                    .buttonStyle(QsButtonStyle(priority: .text))
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s12)
            .padding(.bottom, QsLayout.actionsAboveBottomLine)
            .background(theme.palette.bg)
        }
        .background(theme.palette.bg.ignoresSafeArea())
    }

    private func box(_ title: LocalizedStringKey, items: [LocalizedStringKey], fill: Color) -> some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(theme.palette.ink)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: Space.s8) {
                    Text("•").accessibilityHidden(true)
                    Text(item)
                }
                .font(.subheadline).foregroundStyle(theme.palette.ink)
            }
        }
        .padding(Space.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous).strokeBorder(theme.palette.line, lineWidth: Size.stroke))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Chat (Flow 12 › Steps 3–7)

struct CompanionChatView: View {
    var showsClose = true
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(CompanionStore.self) private var companion
    @Environment(Connectivity.self) private var connectivity
    @Environment(NotificationCenterModel.self) private var notifications
    @Environment(WidgetRouter.self) private var router
    @Environment(\.duoLayout) private var duo
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var books: [Book]
    @AppStorage(ProfileKeys.goal) private var goal = 0
    @AppStorage(ProfileKeys.name) private var name = ""
    @State private var dictation = Dictation()
    @State private var draft = ""
    @State private var openBook: Book?
    @State private var openPick: PickPreview?
    @State private var showSettings = false
    @State private var confirmDelete = false
    @FocusState private var focused: Bool
    /// Decided once when the chat opens: an earlier conversation exists → "Welcome back".
    @State private var returning = false

    struct PickPreview: Identifiable { let pick: CompanionPick; let message: CompanionMessage; var id: String { pick.id } }

    var body: some View {
        Group {
            if duo.mode == .tabletop {
                // Duo tabletop: the latest answer on top, big reply chips and Hold to ask below the fold.
                VStack(spacing: duo.fold.height) {
                    VStack(spacing: 0) {
                        topBar
                        theme.palette.line.frame(height: Size.stroke)
                        conversation
                    }
                    .frame(height: duo.fold.minY)
                    tabletopControls
                }
                .ignoresSafeArea(edges: .top)
            } else {
                VStack(spacing: 0) {
                    topBar
                    theme.palette.line.frame(height: Size.stroke)
                    conversation
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { composer }
            }
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .modifier(QsNotificationHost())
        .sheet(item: $openBook) { book in NavigationStack { BookDetailView(book: book) } }
        .sheet(item: $openPick) { p in
            PickDetailSheet(pick: p.pick) { add(p.pick, from: p.message) }
        }
        .sheet(isPresented: $showSettings) { NavigationStack { CompanionSettingsView() } }
        .alert("Delete chat history?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { withAnimation { companion.deleteHistory() } }
        } message: {
            Text("Your chats with Astrid are removed from this phone. Your books stay as they are.")
        }
        .onAppear {
            returning = !companion.messages.isEmpty
            companion.refreshAvailability()
            if let prompt = companion.pendingPrompt {
                companion.pendingPrompt = nil
                ask(prompt)
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "qschat", let title = url.host(percentEncoded: false) ?? url.pathComponents.last else { return .discarded }
            let key = CompanionContext.key(title.removingPercentEncoding ?? title)
            if let book = books.first(where: { CompanionContext.key($0.title) == key }) { show(book) }
            return .handled
        })
        #if DEBUG
        // Test builds: `-qsCompanion demo | thinking`, `-qsCompanionAsk "question"`.
        .task {
            switch UserDefaults.standard.string(forKey: "qsCompanion") {
            case "demo": if companion.messages.isEmpty { CompanionDemo.fill(companion, books: books) }
            case "thinking":
                companion.messages = [CompanionMessage(role: .me, text: "Something cosy and short. I’m tired this week.")]
                companion.phase = .thinking
            default: break
            }
            if let q = UserDefaults.standard.string(forKey: "qsCompanionAsk"), companion.messages.isEmpty { ask(q) }
        }
        #endif
    }

    // MARK: Parts

    private var topBar: some View {
        HStack(spacing: Space.s12) {
            if showsClose {
                iconButton("qs.close", label: "Close") { companion.isOpen = false }
            } else {
                Color.clear.frame(width: Size.touchIos, height: Size.touchIos)
            }
            HStack(spacing: Space.s8) {
                Image("qs.sparkles").resizable().frame(width: 18, height: 18).foregroundStyle(theme.palette.aiInk)
                    .accessibilityHidden(true)
                Text("Astrid").font(.headline).foregroundStyle(theme.palette.ink)
                Text("AI").font(.caption2.weight(.semibold)).foregroundStyle(theme.palette.aiInk)
                    .padding(.horizontal, Space.s6).padding(.vertical, Space.s2)
                    .background(theme.palette.aiSoft, in: Capsule())
                    .accessibilityLabel("A I")
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Menu {
                Button { showSettings = true } label: { Label("Astrid & privacy", image: "qs.settings") }
                Button(role: .destructive) { confirmDelete = true } label: { Label("Delete chat history", image: "qs.trash") }
            } label: {
                Image("qs.more").resizable().frame(width: Size.iconL, height: Size.iconL).foregroundStyle(theme.palette.ink)
                    .frame(width: Size.touchIos, height: Size.touchIos).contentShape(Rectangle())
            }
            .accessibilityLabel("More")
        }
        .padding(.horizontal, Space.s8)
        .padding(.vertical, Space.s4)
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Space.s16) {
                    if !connectivity.isOnline {
                        InfoBanner(message: "I can’t reach the library just now, so new book ideas will wait. I can still chat about your reading.")
                    }
                    intro
                    if companion.messages.isEmpty { starters }
                    ForEach(companion.messages) { m in
                        messageView(m).id(m.id)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    if companion.phase == .thinking {
                        ThinkingIndicator(onStop: { companion.stop() }).id("thinking")
                            .transition(.opacity)
                    }
                    Color.clear.frame(height: 1).id("end")
                }
                .padding(Space.s20)
                .animation(.easeOut(duration: Motion.base), value: companion.messages)
                .animation(.easeOut(duration: Motion.base), value: companion.phase)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: companion.messages) { scrollToEnd(proxy) }
            .onChange(of: companion.phase) { scrollToEnd(proxy) }
            .onAppear { proxy.scrollTo("end", anchor: .bottom) }
        }
    }

    /// Duo open like a book: the book opens on the left page and the chat stays on the right.
    /// Elsewhere it opens as a sheet over the chat.
    private func show(_ book: Book) {
        if duo.mode == .book { router.openBookInPlace = book } else { openBook = book }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: Motion.base)) { proxy.scrollTo("end", anchor: .bottom) }
    }

    /// Astrid · first hello, or "Welcome back" with the book in progress.
    private var intro: some View {
        let current = books.filter { $0.status == .reading }.max { $0.lastUpdated < $1.lastUpdated }
        let text: String
        if returning, let current {
            text = String(localized: "Welcome back. How is *\(current.title)* treating you?")
        } else {
            text = String(localized: "Hello, I’m Astrid, your reading companion. I’m an AI, and I can only see your **shelves, ratings and finish tags**. I’d love to help you find your next good story. Where shall we start?")
        }
        return CompanionMessageRow(text: text, linkable: { t in books.contains { CompanionContext.key($0.title) == CompanionContext.key(t) } })
    }

    private var starters: some View {
        let favourite = books.filter { $0.status == .read }.max { ($0.stars ?? 0) < ($1.stars ?? 0) }?.title ?? "Piranesi"
        let items = [String(localized: "Find my next book"),
                     String(localized: "Something like \(favourite), but cosier"),
                     String(localized: "How is my reading goal going?"),
                     String(localized: "Plan reads for my holiday")]
        return VStack(spacing: Space.s8) {
            ForEach(items, id: \.self) { s in
                Button { ask(s) } label: {
                    HStack(spacing: Space.s12) {
                        Text(s).font(.subheadline).foregroundStyle(theme.palette.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        Image("qs.send").resizable().frame(width: Size.iconS, height: Size.iconS)
                            .rotationEffect(.degrees(45)).foregroundStyle(theme.palette.ink2)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, Space.s16)
                    .padding(.vertical, Space.s12)
                    .frame(minHeight: Size.touchIos)
                    .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous).strokeBorder(theme.palette.line, lineWidth: Size.stroke))
                    .contentShape(Rectangle())
                }
                .buttonStyle(QsPressStyle())
            }
        }
        .padding(.leading, Space.s40)
        .gentleAppear(delay: Motion.fast)
    }

    @ViewBuilder private func messageView(_ m: CompanionMessage) -> some View {
        switch m.role {
        case .me:
            VStack(alignment: .trailing, spacing: Space.s4) {
                Text(m.text).font(.subheadline).foregroundStyle(theme.palette.ink)
                    .lineSpacing(2)
                    .padding(.horizontal, Space.s16).padding(.vertical, Space.s12)
                    .background(theme.palette.soft2, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
                    .frame(maxWidth: 282, alignment: .trailing)
                if m.status == .failed {
                    Button("Not sent · Tap to try again") { companion.retry(m, books: books, goal: goal) }
                        .font(.caption.weight(.medium)).foregroundStyle(theme.palette.error)
                        .frame(minHeight: Size.touchIos)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("You: \(m.text)"))
        case .companion:
            if m.status == .failed {
                InfoBanner(message: LocalizedStringKey(m.text), kind: .error)
            } else {
                answer(m)
            }
        }
    }

    private func answer(_ m: CompanionMessage) -> some View {
        let isLatest = companion.messages.last(where: { $0.role == .companion })?.id == m.id
        return VStack(alignment: .leading, spacing: Space.s12) {
            CompanionMessageRow(text: m.text, linkable: { title in
                books.contains { CompanionContext.key($0.title) == CompanionContext.key(title) }
            })
            if m.status == .done {
                if m.showGoal { goalCard }
                ForEach(m.picks.filter { $0.state != .notForMe }) { pick in
                    ChatBookCard(pick: pick,
                                 onOpen: { openPick = PickPreview(pick: pick, message: m) },
                                 onAdd: { add(pick, from: m) },
                                 onUndo: { undo(pick, from: m) },
                                 onNotForMe: { withAnimation(.easeOut(duration: Motion.base)) { companion.setPick(pick, in: m, state: .notForMe) } })
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
                if isLatest && companion.phase == .idle {
                    if !m.followUps.isEmpty {
                        FlowLayout(spacing: Space.s8) {
                            ForEach(m.followUps, id: \.self) { f in
                                QsChip(title: f) { followUp(f) }
                            }
                        }
                        .padding(.leading, Space.s40)
                    }
                    answerActions(m)
                }
            }
        }
        .gentleAppear()
    }

    private var goalCard: some View {
        let s = ReadingStats(books: books)
        return GoalCard(goal: s.goal(goal, year: s.currentYear), year: s.currentYear,
                        selectedYear: .constant(s.currentYear), years: [s.currentYear],
                        onEdit: { companion.isOpen = false; router.openStats = true })
    }

    private func answerActions(_ m: CompanionMessage) -> some View {
        HStack(spacing: Space.s4) {
            actionIcon(m.feedback == 1 ? "qs.thumbup" : "qs.thumbup", label: "Helpful", active: m.feedback == 1) { companion.rate(m, 1) }
            actionIcon("qs.thumbdown", label: "Not helpful", active: m.feedback == -1) { companion.rate(m, -1) }
            actionIcon("qs.copy", label: "Copy") {
                UIPasteboard.general.string = m.text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "*", with: "")
                notifications.show(String(localized: "Copied"), message: String(localized: "The answer is on your clipboard."))
            }
        }
        .padding(.leading, Space.s32)
    }

    private func actionIcon(_ icon: String, label: LocalizedStringKey, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(icon).resizable().frame(width: 18, height: 18)
                .foregroundStyle(active ? theme.palette.accentInk : theme.palette.ink2)
                .frame(width: Size.touchIos, height: Size.touchIos)
                .background(active ? theme.palette.soft2 : .clear, in: Circle().inset(by: Space.s6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? [.isSelected] : [])
        .sensoryFeedback(.selection, trigger: active)
    }

    private var composer: some View {
        let canSend = !draft.trimmingCharacters(in: .whitespaces).isEmpty && companion.phase == .idle
        return VStack(spacing: Space.s8) {
            HStack(spacing: Space.s8) {
                TextField("Ask about your reading…", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.subheadline)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit { send() }
                    .padding(.leading, Space.s16)
                    .padding(.vertical, Space.s12)
                    .overlay(alignment: .trailing) { micButton.padding(.trailing, Space.s4) }
                    .padding(.trailing, Size.touchIos)
                    .frame(minHeight: Size.touchIos)
                    .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: Size.touchIos / 2, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Size.touchIos / 2, style: .continuous)
                        .strokeBorder(focused ? theme.palette.focus : theme.palette.lineStrong, lineWidth: focused ? Size.focusRing : Size.stroke))
                Button(action: send) {
                    Image("qs.send").resizable().frame(width: Size.iconM, height: Size.iconM)
                        .foregroundStyle(canSend ? theme.palette.onAccent : theme.palette.disabledInk)
                        .frame(width: Size.touchIos, height: Size.touchIos)
                        .background(canSend ? theme.palette.accent : theme.palette.disabledBg, in: Circle())
                }
                .buttonStyle(QsPressStyle())
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
            if dictation.state == .denied {
                Text("To speak to Astrid, allow the microphone and speech recognition in iPhone Settings.")
                    .font(.caption2).foregroundStyle(theme.palette.ink2).multilineTextAlignment(.center)
            }
            Text("AI · can be wrong · stays on your iPhone")
                .font(.caption2.weight(.medium)).foregroundStyle(theme.palette.ink2)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Space.s16)
        .padding(.top, Space.s8)
        .padding(.bottom, Space.s8)
        .background(theme.palette.bg)
        .animation(.easeOut(duration: Motion.fast), value: canSend)
    }

    /// Mic = dictation into the field. Tap again (or send) to stop.
    private var micButton: some View {
        Button {
            if dictation.isListening { dictation.stop() } else { Task { await dictation.start() } }
        } label: {
            TimelineView(.animation(paused: !dictation.isListening || reduceMotion)) { tl in
                let pulse = dictation.isListening && !reduceMotion ? (sin(tl.date.timeIntervalSinceReferenceDate * 5) + 1) / 2 : 0
                Image("qs.mic").resizable().frame(width: Size.iconM, height: Size.iconM)
                    .foregroundStyle(dictation.isListening ? theme.palette.onAccent : theme.palette.ink2)
                    .frame(width: Space.s32 + Space.s4, height: Space.s32 + Space.s4)
                    .background(dictation.isListening ? theme.palette.accent : .clear, in: Circle())
                    .scaleEffect(1 + 0.06 * pulse)
            }
            .frame(width: Size.touchIos, height: Size.touchIos)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dictation.isListening ? "Stop dictation" : "Dictate")
        .onChange(of: dictation.text) { _, t in if !t.isEmpty { draft = t } }
        .sensoryFeedback(.start, trigger: dictation.isListening) { _, new in new }
    }

    /// Duo tabletop, below the fold: big reply chips and push-to-talk ("Hold to ask").
    private var tabletopControls: some View {
        let latest = companion.messages.last(where: { $0.role == .companion })
        let chips = (latest?.followUps ?? []).isEmpty
            ? [String(localized: "Find my next book"), String(localized: "How is my reading goal going?")]
            : latest!.followUps
        return VStack(spacing: Space.s16) {
            Text(dictation.isListening ? (dictation.text.isEmpty ? String(localized: "Listening…") : dictation.text) : String(localized: "Reply hands-free or tap"))
                .font(.footnote).foregroundStyle(theme.palette.ink2).lineLimit(2).multilineTextAlignment(.center)
            FlowLayout(spacing: Space.s8) {
                ForEach(chips, id: \.self) { c in QsChip(title: c) { followUp(c) } }
            }
            .frame(maxWidth: .infinity)
            VStack(spacing: Space.s8) {
                Image("qs.mic").resizable().frame(width: Size.iconL, height: Size.iconL)
                    .foregroundStyle(theme.palette.onAccent)
                    .frame(width: Space.s64, height: Space.s64)
                    .background(dictation.isListening ? theme.palette.accentPressed : theme.palette.accent, in: Circle())
                    .scaleEffect(dictation.isListening ? 1.08 : 1)
                    .animation(.easeOut(duration: Motion.fast), value: dictation.isListening)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { _ in if !dictation.isListening { Task { await dictation.start() } } }
                        .onEnded { _ in
                            dictation.stop()
                            let said = dictation.text
                            if !said.isEmpty { ask(said) }
                        })
                    .accessibilityLabel("Hold to ask")
                    .accessibilityAddTraits(.isButton)
                Text("Hold to ask").font(.footnote.weight(.medium)).foregroundStyle(theme.palette.ink)
            }
            Text("AI · can be wrong · stays on your iPhone").font(.caption2.weight(.medium)).foregroundStyle(theme.palette.ink2)
        }
        .padding(.horizontal, Space.s20)
        .padding(.top, Space.s16)
        .padding(.bottom, duo.actionsBottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.bg)
    }

    private func iconButton(_ icon: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(icon).resizable().frame(width: Size.iconL, height: Size.iconL).foregroundStyle(theme.palette.ink)
                .frame(width: Size.touchIos, height: Size.touchIos).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Actions

    private func send() {
        dictation.stop()
        let text = draft
        draft = ""
        ask(text)
    }

    private func ask(_ text: String) {
        companion.send(text, books: books, goal: goal)
    }

    private func followUp(_ f: String) {
        if f == String(localized: "Open my stats") { companion.isOpen = false; router.openStats = true; return }
        ask(f)
    }

    /// "Add to Up next": saved silently to Want to read, with a toast and Undo.
    private func add(_ pick: CompanionPick, from m: CompanionMessage) {
        let book = Book(title: pick.title, author: pick.author, isbn: pick.isbn, pageCount: pick.pageCount, status: .toRead, source: .manual)
        let existing = (try? context.fetch(FetchDescriptor<Book>())) ?? []
        guard !existing.contains(where: { $0.matchKey == book.matchKey }) else {
            companion.setPick(pick, in: m, state: .added)
            return
        }
        context.insert(book)
        try? context.save()
        withAnimation(.easeOut(duration: Motion.base)) { companion.setPick(pick, in: m, state: .added) }
        notifications.show(String(localized: "Added to Up next"),
                           message: String(localized: "Lovely choice. It’s waiting in Up next whenever you’re ready."),
                           actionTitle: String(localized: "Undo")) {
            undo(pick, from: m)
        }
        Task {
            if let data = await BookSearch.coverData(isbn: pick.isbn, fallbackURL: pick.coverURL) {
                book.coverData = data
                try? context.save()
            }
        }
    }

    private func undo(_ pick: CompanionPick, from m: CompanionMessage) {
        let key = Book(title: pick.title, author: pick.author, isbn: nil, pageCount: nil, status: .toRead, source: .manual).matchKey
        if let book = ((try? context.fetch(FetchDescriptor<Book>())) ?? []).first(where: { $0.matchKey == key && $0.status == .toRead }) {
            context.delete(book)
            try? context.save()
        }
        withAnimation(.easeOut(duration: Motion.base)) { companion.setPick(pick, in: m, state: .open) }
    }
}

// MARK: - Message text (AI text formatting)

/// A companion turn: 32 pt sparkle avatar and text on the page background (no bubble).
/// Renders the allowed Markdown subset natively: **bold**, *Book title*, - bullets, 1. steps, paragraphs.
struct CompanionMessageRow: View {
    let text: String
    let linkable: (String) -> Bool
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: Space.s8) {
            CompanionAvatar()
            VStack(alignment: .leading, spacing: Space.s8) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    switch block {
                    case .paragraph(let s):
                        Text(inline(s))
                    case .list(let items, let numbered):
                        VStack(alignment: .leading, spacing: Space.s4) {
                            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                                HStack(alignment: .firstTextBaseline, spacing: Space.s8) {
                                    Text(numbered ? "\(i + 1)." : "•").accessibilityHidden(true)
                                    Text(inline(item))
                                }
                            }
                        }
                    }
                }
            }
            .font(.subheadline)
            .lineSpacing(3)
            .foregroundStyle(theme.palette.ink)
            .tint(theme.palette.accentInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Astrid: ") + Text(inline(text.replacingOccurrences(of: "\n- ", with: "\n"))))
    }

    private enum Block { case paragraph(String), list([String], numbered: Bool) }

    private var blocks: [Block] {
        var out: [Block] = []
        var para: [String] = []
        var list: [String] = []
        var numbered = false
        func flushPara() { if !para.isEmpty { out.append(.paragraph(para.joined(separator: " "))); para = [] } }
        func flushList() { if !list.isEmpty { out.append(.list(list, numbered: numbered)); list = [] } }
        for raw in text.components(separatedBy: "\n") {
            let l = raw.trimmingCharacters(in: .whitespaces)
            if l.isEmpty { flushPara(); flushList(); continue }
            if l.hasPrefix("- ") || l.hasPrefix("• ") {
                flushPara(); if numbered { flushList() }; numbered = false; list.append(String(l.dropFirst(2)))
            } else if let r = l.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                flushPara(); if !numbered { flushList() }; numbered = true; list.append(String(l[r.upperBound...]))
            } else {
                flushList(); para.append(l)
            }
        }
        flushPara(); flushList()
        return out
    }

    /// **bold** → Semi Bold; *Title* → Newsreader Italic in accentInk, underlined + tappable when it's a real book.
    private func inline(_ s: String) -> AttributedString {
        var a = (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s)
        for run in a.runs {
            guard let intent = run.inlinePresentationIntent else { continue }
            if intent.contains(.stronglyEmphasized) {
                a[run.range].font = .subheadline.weight(.semibold)
            } else if intent.contains(.emphasized) {
                let title = String(a[run.range].characters)
                a[run.range].font = .custom("Newsreader", size: 17, relativeTo: .body).italic()
                a[run.range].foregroundColor = theme.palette.accentInk
                if linkable(title) {
                    a[run.range].underlineStyle = .single
                    a[run.range].link = URL(string: "qschat://\(title.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "")")
                }
            }
            if run.link != nil, run.link?.scheme != "qschat" { a[run.range].link = nil }   // no raw links
        }
        return a
    }
}

struct CompanionAvatar: View {
    @Environment(\.theme) private var theme
    var body: some View {
        Image("qs.sparkles").resizable().frame(width: Size.iconS, height: Size.iconS)
            .foregroundStyle(theme.palette.aiInk)
            .frame(width: Space.s32, height: Space.s32)
            .background(theme.palette.aiSoft, in: Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - Thinking animation (Typing indicator)

/// The companion "breathes" while it thinks: the sparkle avatar glows and turns a little,
/// three dots rise and fall in a soft wave. After 8 s: "Still thinking…" with Stop.
/// Reduce Motion: still dots and the words "Thinking…".
struct ThinkingIndicator: View {
    let onStop: () -> Void
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    @State private var slow = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            HStack(spacing: Space.s8) {
                TimelineView(.animation(paused: reduceMotion)) { tl in
                    let t = tl.date.timeIntervalSince(start)
                    let breath = reduceMotion ? 0 : (sin(t * 2.2) + 1) / 2   // 0…1
                    ZStack {
                        Circle().fill(theme.palette.aiSoft)
                        Circle().fill(theme.palette.ai.opacity(0.25 * breath)).scaleEffect(1 + 0.25 * breath).blur(radius: 4)
                        Image("qs.sparkles").resizable().frame(width: Size.iconS, height: Size.iconS)
                            .foregroundStyle(theme.palette.aiInk)
                            .rotationEffect(.degrees(reduceMotion ? 0 : sin(t * 1.4) * 12))
                            .scaleEffect(1 + 0.08 * breath)
                    }
                    .frame(width: Space.s32, height: Space.s32)
                }
                .accessibilityHidden(true)
                if reduceMotion {
                    Text("Thinking…").font(.subheadline).foregroundStyle(theme.palette.ink2)
                } else {
                    TimelineView(.animation) { tl in
                        let t = tl.date.timeIntervalSince(start)
                        HStack(spacing: Space.s6) {
                            ForEach(0..<3, id: \.self) { i in
                                let wave = (sin(t * 5 - Double(i) * 0.9) + 1) / 2
                                Circle().fill(theme.palette.ai)
                                    .frame(width: Space.s8, height: Space.s8)
                                    .opacity(0.35 + 0.65 * wave)
                                    .offset(y: -4 * wave)
                            }
                        }
                        .padding(.horizontal, Space.s12)
                        .frame(height: Space.s32)
                        .background(theme.palette.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(theme.palette.line, lineWidth: Size.stroke))
                    }
                    .accessibilityHidden(true)
                }
            }
            if slow {
                HStack(spacing: Space.s12) {
                    Text("Still thinking…").font(.footnote).foregroundStyle(theme.palette.ink2)
                    Button("Stop", action: onStop)
                        .font(.footnote.weight(.semibold)).foregroundStyle(theme.palette.accentInk)
                        .frame(minHeight: Size.touchIos)
                }
                .padding(.leading, Space.s40)
                .transition(.opacity)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Astrid is thinking")
        .task {
            try? await Task.sleep(for: .seconds(8))
            withAnimation(.easeOut(duration: Motion.base)) { slow = true }
        }
    }
}

// MARK: - Chat book card

/// 🧱 Components › Chat book card: a real book inside an answer (max 3). Tap = open the pick.
struct ChatBookCard: View {
    let pick: CompanionPick
    let onOpen: () -> Void
    let onAdd: () -> Void
    let onUndo: () -> Void
    let onNotForMe: () -> Void
    @Environment(\.theme) private var theme

    private var meta: String {
        [pick.author, pick.pageCount.map { String(localized: "\($0) pages") }].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: Space.s12) {
            Button(action: onOpen) {
                RemoteCover(url: pick.coverURL, title: pick.title, width: 40)
            }
            .buttonStyle(QsPressStyle())
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.s4) {
                Button(action: onOpen) {
                    VStack(alignment: .leading, spacing: Space.s4) {
                        Text(pick.title).font(.custom("Newsreader", size: 17, relativeTo: .headline).weight(.medium))
                            .foregroundStyle(theme.palette.ink).multilineTextAlignment(.leading)
                        Text(meta).font(.footnote).foregroundStyle(theme.palette.ink2)
                        if !pick.reason.isEmpty {
                            Text(pick.reason).font(.footnote).foregroundStyle(theme.palette.ink).multilineTextAlignment(.leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Shows why this pick")
                HStack(spacing: Space.s8) {
                    if pick.state == .added {
                        Button("In Up next", action: {}).buttonStyle(QsButtonStyle(priority: .secondary, size: .small)).fixedSize().disabled(true)
                        Button("Undo", action: onUndo).buttonStyle(QsButtonStyle(priority: .text, size: .small)).fixedSize()
                    } else {
                        Button("Add to Up next", action: onAdd).buttonStyle(QsButtonStyle(priority: .secondary, size: .small)).fixedSize()
                        Button("Not for me", action: onNotForMe).buttonStyle(QsButtonStyle(priority: .text, size: .small)).fixedSize()
                    }
                }
                .padding(.top, Space.s4)
            }
        }
        .padding(Space.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
            .strokeBorder(pick.state == .added ? theme.palette.accent : theme.palette.line, lineWidth: Size.stroke))
        .gentleAnimation(pick.state)
    }
}

/// Cover loaded from the catalogue (picks aren't in the library yet).
struct RemoteCover: View {
    let url: URL?
    let title: String
    let width: CGFloat
    @Environment(\.theme) private var theme

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    theme.palette.disabledBg
                    Text(title.prefix(1)).font(theme.headline(width / 2.5, relativeTo: .caption)).foregroundStyle(theme.palette.ink2)
                }
            }
        }
        .frame(width: width, height: width * 1.5)
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.cover, style: .continuous))
        .shadow(color: theme.palette.scrim.opacity(0.16), radius: 4, x: 0, y: 3)
    }
}

/// Tap a pick: the book with "Why this pick" and Add to Up next.
struct PickDetailSheet: View {
    let pick: CompanionPick
    let onAdd: () -> Void
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s16) {
                HStack(alignment: .top, spacing: Space.s16) {
                    RemoteCover(url: pick.coverURL, title: pick.title, width: 96)
                    VStack(alignment: .leading, spacing: Space.s8) {
                        Text(pick.title).font(theme.headline(24, relativeTo: .title2)).foregroundStyle(theme.palette.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text([pick.author, pick.pageCount.map { String(localized: "\($0) pages") }].compactMap { $0 }.joined(separator: " · "))
                            .font(.subheadline).foregroundStyle(theme.palette.ink2)
                        HStack(spacing: Space.s4) {
                            Image("qs.sparkles").resizable().frame(width: 12, height: 12)
                            Text("Suggested by Astrid · AI")
                        }
                        .font(.caption.weight(.medium)).foregroundStyle(theme.palette.aiInk)
                        .padding(.horizontal, Space.s8).padding(.vertical, Space.s4)
                        .background(theme.palette.aiSoft, in: Capsule())
                    }
                }
                if !pick.reason.isEmpty {
                    VStack(alignment: .leading, spacing: Space.s4) {
                        Text("WHY THIS PICK").font(.caption2.weight(.semibold)).tracking(0.6).foregroundStyle(theme.palette.ink2)
                        Text(pick.reason).font(.subheadline).foregroundStyle(theme.palette.ink)
                    }
                    .padding(Space.s16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.palette.soft2, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
                }
            }
            .padding(Space.s20)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Group {
                if pick.state == .added {
                    Button("In Up next") {}.buttonStyle(QsButtonStyle(priority: .secondary)).disabled(true)
                } else {
                    Button("Add to Up next") { onAdd(); dismiss() }.buttonStyle(QsButtonStyle(priority: .primary))
                }
            }
            .padding(.horizontal, Space.s20)
            .padding(.bottom, QsLayout.actionsAboveBottomLine)
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(theme.radii.sheet)
    }
}

// MARK: - Home nudge (optional · near the end of a book)

/// One card near the end of a book, never a notification. Off unless the reader turns it on.
struct CompanionNudgeCard: View {
    let book: Book
    @Environment(\.theme) private var theme
    @Environment(CompanionStore.self) private var companion
    @AppStorage(CompanionKeys.nudgeDismissed) private var dismissed = ""

    var body: some View {
        let left = max(0, (book.pageCount ?? 0) - book.currentPage)
        VStack(alignment: .leading, spacing: Space.s12) {
            HStack(spacing: Space.s4) {
                Image("qs.sparkles").resizable().frame(width: 14, height: 14).accessibilityHidden(true)
                Text("Astrid · AI")
            }
            .font(.caption.weight(.medium)).foregroundStyle(theme.palette.aiInk)
            Text("You’re \(left) pages from the end of \(book.title). Want to talk with Astrid about what’s next?")
                .font(.subheadline).foregroundStyle(theme.palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Space.s8) {
                Button("Chat with Astrid") {
                    companion.pendingPrompt = String(localized: "I’m almost done with \(book.title). What could I read next?")
                    companion.isOpen = true
                }
                .buttonStyle(QsButtonStyle(priority: .primary, size: .small)).fixedSize()
                Button("Not now") { withAnimation(.easeOut(duration: Motion.base)) { dismissed = book.title } }
                    .buttonStyle(QsButtonStyle(priority: .text, size: .small)).fixedSize()
            }
        }
        .padding(Space.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.palette.aiSoft, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    /// Shown only when the reader turned nudges on, 40 pages or fewer are left, and it wasn't dismissed for this book.
    static func shouldShow(_ book: Book?) -> Bool {
        guard let book, let pages = book.pageCount, book.currentPage > 0,
              UserDefaults.standard.bool(forKey: CompanionKeys.nudge),
              UserDefaults.standard.bool(forKey: CompanionKeys.enabled),
              UserDefaults.standard.string(forKey: CompanionKeys.nudgeDismissed) != book.title else { return false }
        let left = pages - book.currentPage
        return left > 0 && left <= 40
    }
}

#if DEBUG
/// Test builds only (`-qsCompanion demo`): a sample conversation to check layouts without the model.
enum CompanionDemo {
    static func fill(_ c: CompanionStore, books: [Book]) {
        c.messages = [
            CompanionMessage(role: .me, text: "Something cosy and short. I’m tired this week."),
            CompanionMessage(role: .companion,
                             text: "Here are **two gentle standalones** under 300 pages. Both end happily, no cliffhangers.",
                             picks: [
                                CompanionPick(id: "d1", title: "Legends & Lattes", author: "Travis Baldree", pageCount: 296, isbn: "9781250886088", coverURL: URL(string: "https://covers.openlibrary.org/b/isbn/9781250886088-M.jpg"), reason: "Low stakes and found family, like the cosy books you rated highly."),
                                CompanionPick(id: "d2", title: "A Psalm for the Wild-Built", author: "Becky Chambers", pageCount: 160, isbn: "9781250236210", coverURL: URL(string: "https://covers.openlibrary.org/b/isbn/9781250236210-M.jpg"), reason: "Quiet and hopeful, a short read for a tired week."),
                             ],
                             followUps: ["Even shorter", "No romance", "Something darker"]),
        ]
    }
}
#endif
