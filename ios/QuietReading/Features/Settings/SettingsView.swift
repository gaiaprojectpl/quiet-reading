import SwiftUI
import SwiftData
import PhotosUI

/// Flow 4 · Settings & profile.
struct SettingsView: View {
    var onImport: () -> Void = {}
    /// Set when Settings is opened from the profile photo on Home: shows "‹ Home" and closes.
    var onClose: (() -> Void)? = nil
    /// The tab Profile & Settings was opened from ("Home", "Library"…).
    var backTitle: LocalizedStringKey = "Home"

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(PlusAccess.self) private var plus
    @Query private var books: [Book]

    @AppStorage(ThemeStorage.key) private var chosenTheme: ThemeID = .peachSage
    @AppStorage(ProfileKeys.name) private var name = ""
    @AppStorage(ProfileKeys.handle) private var handle = ""
    @AppStorage(ProfileKeys.goal) private var goal = 0
    @AppStorage(ProfileKeys.reminderOn) private var reminderOn = false
    @AppStorage(ProfileKeys.reminderMinutes) private var reminderMinutes = 20 * 60 + 30
    @AppStorage(ProfileKeys.appIcon) private var appIcon = "green"
    @AppStorage(ProfileKeys.lastImport) private var lastImport = 0.0
    @AppStorage(ProfileKeys.lastImportSource) private var lastImportSource = ""
    @AppStorage(OnboardingStorage.key) private var onboardingDone = true

    @State private var path: [Page] = []
    @State private var editingGoal = false
    @State private var editingReminder = false
    @State private var confirmDelete = false
    @State private var notificationsOff = false
    @AppStorage(ProfileKeys.monthlyRecap) private var monthlyRecap = false
    @State private var avatar: UIImage?
    @State private var exportFiles: ExportFiles?
    struct ExportFiles: Identifiable { let id = UUID(); let urls: [URL] }

    enum Page: Hashable { case profile, theme, icon, sources, companion }

    private var finishedThisYear: Int {
        let year = Calendar.current.component(.year, from: .now)
        return books.filter { $0.status == .read && $0.dateFinished.map { Calendar.current.component(.year, from: $0) == year } == true }.count
    }

    private var currentBook: Book? { books.filter { $0.status == .reading }.max { $0.lastUpdated < $1.lastUpdated } }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s16) {
                    ScreenTitle(title: "Profile & Settings")
                    profileCard
                    section("Appearance") {
                        QsListRow(icon: "qs.palette", title: "App theme", value: chosenTheme.displayName) { path.append(.theme) }
                        QsListRow(icon: "qs.logo", title: "App icon", value: AppIconChoice(rawValue: appIcon)?.name ?? "") { path.append(.icon) }
                        QsListRow(icon: "qs.target", title: "Reading goal",
                                  value: goal > 0 ? String(localized: "\(goal) books") : String(localized: "Not set")) { editingGoal = true }
                    }
                    section("Reading") {
                        reminderRow
                        recapRow
                        QsListRow(icon: "qs.link", title: "Sources", subtitle: LocalizedStringKey(sourcesLine)) { path.append(.sources) }
                        QsListRow(icon: "qs.sparkles", title: "Astrid · reading companion",
                                  subtitle: UserDefaults.standard.bool(forKey: CompanionKeys.enabled) ? "On · stays on your iPhone" : "Off") { path.append(.companion) }
                    }
                    section("Quiet Reading Plus") {
                        QsListRow(icon: "qs.crown", title: "Quiet Reading Plus",
                                  subtitle: plus.isUnlocked ? "Thank you. Everything is unlocked." : "Three more themes and icons, one payment") {
                            plus.showPaywall = true
                        }
                    }
                    section("Your data") {
                        // Files are written once, on tap (rebuilding them on every redraw made the share sheet jump).
                        Button { exportFiles = ExportFiles(urls: DataExport.files(books: books)) } label: {
                            QsListRowLabel(icon: "qs.file", title: "Export my data", subtitle: "Books and quotes as CSV files")
                        }
                        .buttonStyle(.plain)
                        Button { confirmDelete = true } label: {
                            QsListRowLabel(icon: "qs.trash", title: "Delete everything on this phone", destructive: true)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("Your books stay on this phone. Accounts and sync come later, and they’ll always be optional.")
                        .font(.footnote)
                        .foregroundStyle(theme.palette.ink2)
                }
                .padding(.horizontal, Space.s20)
                .padding(.top, Space.s16)
                .padding(.bottom, Space.s40)
            }
            // The way back stays put while the page scrolls (like iOS Settings).
            .safeAreaInset(edge: .top, spacing: 0) {
                if let onClose {
                    HStack { QsBackButton(title: backTitle, action: onClose); Spacer() }
                        .padding(.horizontal, Space.s12)
                        .background(theme.palette.bg)
                }
            }
            .background(theme.palette.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Page.self) { page in
                switch page {
                case .profile: ProfileEditView()
                case .theme: ThemePickerView()
                case .icon: AppIconView()
                case .sources: SourcesView(onImport: onImport)
                case .companion: CompanionSettingsView()
                }
            }
            .sheet(item: $exportFiles) { files in
                ActivityView(items: files.urls).presentationDetents([.medium, .large]).ignoresSafeArea()
            }
            .sheet(isPresented: $editingGoal) { GoalSheet(goal: $goal, finishedThisYear: finishedThisYear) }
            .sheet(isPresented: $editingReminder) {
                ReminderSheet(minutes: $reminderMinutes) {
                    if reminderOn { ReminderScheduler.schedule(minutes: reminderMinutes, book: currentBook) }
                }
            }
            .alert("Notifications are off", isPresented: $notificationsOff) {
                Button("Not now", role: .cancel) {}
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
                }
            } message: {
                Text("To get your reminder or monthly recap, allow notifications for Quiet Reading in iPhone Settings.")
            }
            .alert("Delete everything on this phone?", isPresented: $confirmDelete) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive, action: deleteEverything)
            } message: {
                Text("Your books, progress, quotes and notes will be deleted. This can’t be undone.")
            }
            .onAppear { avatar = Avatar.load() }
            #if DEBUG
            // Test builds only: `-qsSettings profile | icon | theme`.
            .task {
                switch UserDefaults.standard.string(forKey: "qsSettings") {
                case "profile": path = [.profile]
                case "icon": path = [.icon]
                case "theme": path = [.theme]
                case "companion": path = [.companion]
                default: break
                }
            }
            #endif
        }
    }

    // MARK: Parts

    /// Figma 273:1394 · Profile summary: photo, name, handle, one line of reading facts, Edit profile.
    private var profileCard: some View {
        VStack(spacing: Space.s4) {
            Button { path.append(.profile) } label: {
                AvatarView(image: avatar, name: name, size: 88, initials: true)
            }
            .buttonStyle(QsPressStyle())
            .accessibilityLabel("Edit profile photo")
            .padding(.bottom, Space.s8)
            Text(name.isEmpty ? String(localized: "Add your name") : name)
                .font(theme.headline(26, relativeTo: .title))
                .foregroundStyle(theme.palette.ink)
                .multilineTextAlignment(.center)
            if !handle.isEmpty {
                Text("@\(handle)").font(.subheadline).foregroundStyle(theme.palette.ink2)
            }
            Text(factsLine).font(.footnote).foregroundStyle(theme.palette.ink2).multilineTextAlignment(.center)
            Button("Edit profile") { path.append(.profile) }
                .buttonStyle(QsButtonStyle(priority: .outline, size: .small))
                .fixedSize()
                .padding(.top, Space.s8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.s8)
    }

    /// "24 books in 2026 · 6 quotes saved"
    private var factsLine: String {
        let year = String(Calendar.current.component(.year, from: .now))
        let quotes = books.reduce(0) { $0 + $1.quotes.count }
        var parts = [finishedThisYear == 1 ? String(localized: "1 book in \(year)") : String(localized: "\(finishedThisYear) books in \(year)")]
        if quotes > 0 { parts.append(quotes == 1 ? String(localized: "1 quote saved") : String(localized: "\(quotes) quotes saved")) }
        return parts.joined(separator: " · ")
    }

    private var recapRow: some View {
        Toggle(isOn: $monthlyRecap) {
          HStack(spacing: Space.s16) {
            Image("qs.calendar").resizable().frame(width: Size.iconM + 2, height: Size.iconM + 2)
                .foregroundStyle(theme.palette.accentInk)
                .frame(width: Space.s40, height: Space.s40)
                .background(theme.palette.soft2, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.s2) {
                Text("Monthly recap").font(.body.weight(.medium)).foregroundStyle(theme.palette.ink)
                Text("On the 1st, a short look back at your month").font(.footnote).foregroundStyle(theme.palette.ink2)
            }
          }
        }
        .tint(theme.palette.accent)
        .padding(Space.s16)
        .onChange(of: monthlyRecap) { _, on in
            Task {
                if on, !(await ReminderScheduler.requestPermission()) {
                    monthlyRecap = false
                    notificationsOff = true
                }
                RecapScheduler.update(books: books)
            }
        }
    }

    private var reminderRow: some View {
        HStack(spacing: Space.s16) {
            Image("qs.bell").resizable().frame(width: Size.iconM + 2, height: Size.iconM + 2)
                .foregroundStyle(theme.palette.accentInk)
                .frame(width: Space.s40, height: Space.s40)
                .background(theme.palette.soft2, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
                .accessibilityHidden(true)
            Button { editingReminder = true } label: {
                VStack(alignment: .leading, spacing: Space.s2) {
                    Text("Daily reminder").font(.body.weight(.medium)).foregroundStyle(theme.palette.ink)
                    Text(timeText).font(.footnote).foregroundStyle(theme.palette.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Change the time")
            Toggle("Daily reminder", isOn: $reminderOn)
                .labelsHidden()
                .tint(theme.palette.accent)
        }
        .padding(Space.s16)
        .onChange(of: reminderOn) { _, on in
            Task {
                if on {
                    if await ReminderScheduler.requestPermission() {
                        ReminderScheduler.schedule(minutes: reminderMinutes, book: currentBook)
                    } else {
                        // Flow 3 › Notification permission declined: say so calmly, offer the way back.
                        reminderOn = false
                        notificationsOff = true
                    }
                } else {
                    ReminderScheduler.cancel()
                }
            }
        }
    }

    private var timeText: String {
        var c = DateComponents(); c.hour = reminderMinutes / 60; c.minute = reminderMinutes % 60
        return (Calendar.current.date(from: c) ?? .now).formatted(date: .omitted, time: .shortened)
    }

    private var sourcesLine: String {
        guard lastImport > 0 else { return String(localized: "Import from Goodreads or StoryGraph") }
        let when = Date(timeIntervalSince1970: lastImport).formatted(.relative(presentation: .named))
        return String(localized: "\(lastImportSource) · imported \(when)")
    }

    private func section<C: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text(title)
                .textCase(.uppercase)
                .font(.caption.weight(.semibold))
                .tracking(0.72)
                .foregroundStyle(theme.palette.ink2)
                .accessibilityAddTraits(.isHeader)
            QsListCard { content() }
        }
    }

    private func deleteEverything() {
        for b in books { context.delete(b) }
        try? context.save()
        Avatar.save(nil)
        for key in [ProfileKeys.name, ProfileKeys.handle, ProfileKeys.about, ProfileKeys.goal, ProfileKeys.lastImport, ProfileKeys.lastImportSource] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        ReminderScheduler.cancel()
        reminderOn = false
        onboardingDone = false
    }
}

/// A list-row look for ShareLink / Button labels inside a `QsListCard`.
struct QsListRowLabel: View {
    let icon: String
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    var destructive = false
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Space.s16) {
            Image(icon).resizable().frame(width: Size.iconM + 2, height: Size.iconM + 2)
                .foregroundStyle(destructive ? theme.palette.error : theme.palette.accentInk)
                .frame(width: Space.s40, height: Space.s40)
                .background(destructive ? theme.palette.errorSoft : theme.palette.soft2,
                            in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.s2) {
                Text(title).font(.body.weight(.medium)).foregroundStyle(destructive ? theme.palette.error : theme.palette.ink)
                if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(theme.palette.ink2) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Space.s16)
        .contentShape(Rectangle())
    }
}

/// Round profile photo, or the reader's initial on soft.
struct AvatarView: View {
    let image: UIImage?
    let name: String
    let size: CGFloat
    /// Two initials ("OK" for Ola Kowalska) instead of one.
    var initials = false
    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                if letters.isEmpty {
                    Image("qs.user").resizable().frame(width: size * 0.45, height: size * 0.45)
                        .foregroundStyle(theme.palette.accentInk)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(theme.palette.soft)
                } else {
                Text(letters)
                    .font(theme.headline(size * 0.42, relativeTo: .title))
                    .foregroundStyle(theme.palette.accentInk)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.palette.soft)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var letters: String {
        let words = name.split(separator: " ").filter { $0.first?.isLetter == true }
        guard let first = words.first?.first else { return "" }
        guard initials, words.count > 1, let last = words.last?.first else { return String(first).uppercased() }
        return (String(first) + String(last)).uppercased()
    }
}

// MARK: - App theme

/// Flow 5 › App theme: theme cards drawn in their own colours. Free first, then Plus.
/// Tapping a locked Plus theme tries it on across the app (Live preview) instead of locking a door.
struct ThemePickerView: View {
    @AppStorage(ThemeStorage.key) private var chosenTheme: ThemeID = .peachSage
    @AppStorage(ThemeStorage.forceHighContrast) private var forceHighContrast = false
    @Environment(\.theme) private var theme
    @Environment(PlusAccess.self) private var plus
    private let plusThemes: [ThemeID] = [.clayCream, .blushIvory, .lavenderMist]
    private let columns = [GridItem(.flexible(), spacing: Space.s12), GridItem(.flexible(), spacing: Space.s12)]

    var body: some View {
        PinnedBackScroll(backTitle: "Settings") {
            VStack(alignment: .leading, spacing: Space.s16) {
                ScreenTitle(title: "App theme")
                sectionLabel("Free")
                LazyVGrid(columns: columns, spacing: Space.s12) { card(.peachSage) }
                HStack(spacing: Space.s4) {
                    sectionLabel("Plus")
                    Image("qs.crown").resizable().frame(width: Size.iconS - 2, height: Size.iconS - 2)
                        .foregroundStyle(theme.palette.ink2).accessibilityHidden(true)
                }
                .padding(.top, Space.s8)
                LazyVGrid(columns: columns, spacing: Space.s12) {
                    ForEach(plusThemes, id: \.self) { card($0) }
                }
                if !plus.isUnlocked {
                    Text("Tap a Plus theme to try it on. Nothing changes until you choose to unlock.")
                        .font(.footnote).foregroundStyle(theme.palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                sectionLabel("Accessibility · always free").padding(.top, Space.s8)
                QsListCard {
                    HStack(spacing: Space.s12) {
                        Image("qs.eye").resizable().frame(width: Size.iconM, height: Size.iconM)
                            .foregroundStyle(theme.palette.accentInk)
                            .frame(width: Space.s32 + Space.s4, height: Space.s32 + Space.s4)
                            .background(theme.palette.soft2, in: Circle())
                            .accessibilityHidden(true)
                        Toggle("High contrast", isOn: $forceHighContrast)
                            .font(.body).foregroundStyle(theme.palette.ink).tint(theme.palette.accent)
                    }
                    .padding(.horizontal, Space.s16)
                    .padding(.vertical, Space.s8)
                    .frame(minHeight: Size.touchIos)
                }
                Text("Night follows Dark Mode. High contrast also turns on with Increase Contrast in iPhone settings.")
                    .font(.footnote).foregroundStyle(theme.palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s8)
            .padding(.bottom, Space.s24)
            .gentleAnimation(chosenTheme)
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.selection, trigger: chosenTheme)
    }

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text).textCase(.uppercase)
            .font(.caption.weight(.semibold)).tracking(0.5)
            .foregroundStyle(theme.palette.ink2)
            .accessibilityAddTraits(.isHeader)
    }

    private func card(_ id: ThemeID) -> some View {
        let locked = id.requiresPlus && !plus.isUnlocked
        return Button {
            if locked { plus.previewTheme = id } else { chosenTheme = id }
        } label: {
            ThemePreviewCard(id: id, title: id.displayName, isSelected: !locked && id == chosenTheme, isLocked: locked)
        }
        .buttonStyle(QsPressStyle())
        .accessibilityHint(locked ? "Try it on" : "")
    }
}

struct PlusBadge: View {
    @Environment(\.theme) private var theme
    var body: some View {
        Text("Plus")
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.palette.accentInk)
            .padding(.horizontal, Space.s8)
            .padding(.vertical, Space.s2)
            .background(theme.palette.soft2, in: Capsule())
    }
}

// MARK: - App icon

enum AppIconChoice: String, CaseIterable {
    case green, clay, blush, lavender

    var name: String {
        switch self {
        case .green: String(localized: "Green")
        case .clay: String(localized: "Clay")
        case .blush: String(localized: "Blush")
        case .lavender: String(localized: "Lavender")
        }
    }
    var iconName: String? { self == .green ? nil : "AppIcon-" + rawValue.capitalized }
    var preview: String { "icon.preview.\(rawValue)" }
    var requiresPlus: Bool { self != .green }
}

struct AppIconView: View {
    @AppStorage(ProfileKeys.appIcon) private var appIcon = "green"
    @Environment(\.theme) private var theme
    @Environment(PlusAccess.self) private var plus

    var body: some View {
        PinnedBackScroll(backTitle: "Settings") {
            VStack(alignment: .leading, spacing: Space.s16) {
                ScreenTitle(title: "App icon")
                Text("Choose how Quiet Reading looks on your Home Screen.")
                    .font(.subheadline).foregroundStyle(theme.palette.ink2)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.s12), GridItem(.flexible())], spacing: Space.s12) {
                    ForEach(AppIconChoice.allCases, id: \.self) { choice in tile(choice) }
                }
                Text("iOS shows a short message to confirm the change. Widgets stay where they are.")
                    .font(.footnote).foregroundStyle(theme.palette.ink2)
                Text("Plus icons come with Quiet Reading Plus. Without Plus, tapping one opens the Plus screen.")
                    .font(.footnote).foregroundStyle(theme.palette.ink2)
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s8)
            .gentleAnimation(appIcon)
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func tile(_ choice: AppIconChoice) -> some View {
        let inUse = appIcon == choice.rawValue
        return Button { pick(choice) } label: {
            VStack(spacing: Space.s8) {
                Image(choice.preview).resizable().frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityHidden(true)
                HStack(spacing: Space.s4) {
                    Text(choice == .green ? String(localized: "Green · default") : choice.name)
                        .font(.subheadline.weight(.medium)).foregroundStyle(theme.palette.ink)
                    if choice.requiresPlus { PlusBadge() }
                }
                Text(inUse ? "✓ In use" : "Tap to use").font(.footnote).foregroundStyle(theme.palette.ink2)
            }
            .padding(Space.s16)
            .frame(maxWidth: .infinity)
            .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.card - 4, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: theme.radii.card - 4, style: .continuous)
                .strokeBorder(inUse ? theme.palette.accent : theme.palette.line, lineWidth: inUse ? 1.5 : Size.stroke))
        }
        .buttonStyle(QsPressStyle())
        .accessibilityAddTraits(inUse ? [.isSelected] : [])
    }

    private func pick(_ choice: AppIconChoice) {
        if choice.requiresPlus && !plus.isUnlocked { plus.showPaywall = true; return }
        guard choice.rawValue != appIcon else { return }
        UIApplication.shared.setAlternateIconName(choice.iconName) { error in
            if error == nil { Task { @MainActor in appIcon = choice.rawValue } }
        }
    }
}

// MARK: - Sources

struct SourcesView: View {
    let onImport: () -> Void
    @AppStorage(ProfileKeys.lastImport) private var lastImport = 0.0
    @AppStorage(ProfileKeys.lastImportSource) private var lastImportSource = ""
    @Environment(\.theme) private var theme

    var body: some View {
        PinnedBackScroll(backTitle: "Settings") {
            VStack(alignment: .leading, spacing: Space.s16) {
                ScreenTitle(title: "Sources")
                if lastImport > 0 {
                    QsListCard {
                        QsListRow(icon: "qs.file", title: LocalizedStringKey(lastImportSource),
                                  subtitle: LocalizedStringKey(String(localized: "Imported \(Date(timeIntervalSince1970: lastImport).formatted(date: .abbreviated, time: .shortened))")))
                    }
                }
                Text("Import again any time. Books already on your shelf are skipped, so nothing doubles.")
                    .font(.subheadline).foregroundStyle(theme.palette.ink2)
                Button("Import a library", action: onImport)
                    .buttonStyle(QsButtonStyle(priority: .secondary))
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s8)
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Goal & reminder sheets

private struct ReminderSheet: View {
    @Binding var minutes: Int
    let onSave: () -> Void
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var time = Date.now

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            Text("Daily reminder").font(theme.headline(24, relativeTo: .title2)).foregroundStyle(theme.palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("One gentle reminder at the time you choose. Never more than once a day.")
                .font(.subheadline).foregroundStyle(theme.palette.ink2)
            DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.s20)
        .padding(.top, Space.s24)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button("Save") {
                let c = Calendar.current.dateComponents([.hour, .minute], from: time)
                minutes = (c.hour ?? 20) * 60 + (c.minute ?? 30)
                onSave()
                dismiss()
            }
            .buttonStyle(QsButtonStyle(priority: .primary))
            .padding(.horizontal, Space.s20)
            .padding(.bottom, QsLayout.actionsAboveBottomLine)
        }
        .background(theme.palette.surface.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationCornerRadius(theme.radii.sheet)
        .onAppear {
            var c = DateComponents(); c.hour = minutes / 60; c.minute = minutes % 60
            time = Calendar.current.date(from: c) ?? .now
        }
    }
}

/// The system share sheet with a fixed list of items (so it never re-presents while open).
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
