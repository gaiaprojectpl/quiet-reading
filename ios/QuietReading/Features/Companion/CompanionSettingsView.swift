import SwiftUI

/// Flow 12 › Settings · Companion & privacy. Everything in one place; mirrors the consent screen.
struct CompanionSettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(CompanionStore.self) private var companion
    @AppStorage(CompanionKeys.nudge) private var nudge = false
    @AppStorage(CompanionKeys.includeNotes) private var includeNotes = false
    @AppStorage(CompanionKeys.includeProfile) private var includeProfile = false
    @AppStorage(CompanionKeys.historyDays) private var historyDays = 30
    @AppStorage(CompanionKeys.leftPane) private var leftPane = false
    @Environment(\.duoLayout) private var duo
    @State private var confirmDelete = false
    @State private var showSees = false

    var body: some View {
        PinnedBackScroll(backTitle: "Back") {
            VStack(alignment: .leading, spacing: Space.s16) {
                ScreenTitle(title: "Astrid & privacy")
                QsListCard {
                    toggle("Astrid, reading companion", "AI chat, book ideas and reading insights", isOn: Binding(
                        get: { companion.isEnabled },
                        set: { on in if on { companion.isEnabled = true } else { companion.turnOff() } }))
                    toggle("On-device only", deviceNote, isOn: .constant(true)).disabled(true)
                    toggle("Gentle nudge on Home", "One card near the end of a book, never a notification", isOn: $nudge)
                        .disabled(!companion.isEnabled)
                    toggle("Include my notes", "Lets Astrid talk about what you wrote", isOn: $includeNotes)
                        .disabled(!companion.isEnabled)
                    toggle("Include my profile", "Your first name and “About me”, so answers feel more personal", isOn: $includeProfile)
                        .disabled(!companion.isEnabled)
                    if duo.mode != .phone {
                        toggle("Astrid on the left page", "iPhone Duo, open: swap sides for left-handed use", isOn: $leftPane)
                    }
                }
                QsListCard {
                    QsListRow(icon: "qs.info", title: "What Astrid sees") { showSees = true }
                    Menu {
                        Picker("Chat history", selection: $historyDays) {
                            Text("Keep for 30 days").tag(30)
                            Text("Keep for 7 days").tag(7)
                            Text("Don’t keep").tag(0)
                        }
                    } label: {
                        QsListRowLabel(icon: "qs.calendar", title: "Chat history", subtitle: LocalizedStringKey(historyLabel))
                    }
                    .buttonStyle(.plain)
                    Button { confirmDelete = true } label: {
                        QsListRowLabel(icon: "qs.trash", title: "Delete chat history", destructive: true)
                    }
                    .buttonStyle(.plain)
                }
                Text(availabilityLine).font(.footnote).foregroundStyle(theme.palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s8)
            .padding(.bottom, Space.s24)
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .alert("Delete chat history?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { companion.deleteHistory() }
        } message: {
            Text("Your chats with Astrid are removed from this phone. Your books stay as they are.")
        }
        .sheet(isPresented: $showSees) { WhatItSeesSheet() }
        .onChange(of: historyDays) { _, days in if days == 0 { companion.deleteHistory() } }
    }

    private var deviceNote: String {
        String(localized: "Private and offline. Needs an Apple Intelligence iPhone. Cloud answers for other phones come later.")
    }

    private var historyLabel: String {
        switch historyDays {
        case 0: String(localized: "Not kept")
        case 7: String(localized: "Keep for 7 days")
        default: String(localized: "Keep for 30 days")
        }
    }

    private var availabilityLine: String {
        switch companion.availability {
        case .available: String(localized: "Apple Intelligence is ready on this iPhone. Chats stay on your phone.")
        case .appleIntelligenceOff: String(localized: "Turn on Apple Intelligence in iPhone Settings to chat. Goal and reading numbers work without it.")
        case .notReady: String(localized: "Apple Intelligence is still getting ready on this iPhone.")
        case .notEligible, .needsNewerIOS: String(localized: "This iPhone can’t run the on-device model. The companion can still answer questions about your goal and reading numbers.")
        }
    }

    private func toggle(_ title: LocalizedStringKey, _ subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: Space.s2) {
                Text(title).font(.body).foregroundStyle(theme.palette.ink)
                Text(subtitle).font(.footnote).foregroundStyle(theme.palette.ink2)
            }
        }
        .tint(theme.palette.accent)
        .padding(.horizontal, Space.s16)
        .padding(.vertical, Space.s12)
        .frame(minHeight: Size.touchIos)
    }
}

/// "What the companion sees": the exact list, same as the consent screen.
private struct WhatItSeesSheet: View {
    @Environment(\.theme) private var theme
    @AppStorage(CompanionKeys.includeNotes) private var includeNotes = false
    @AppStorage(CompanionKeys.includeProfile) private var includeProfile = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            Text("What Astrid sees").font(theme.headline(22, relativeTo: .title2)).foregroundStyle(theme.palette.ink)
                .accessibilityAddTraits(.isHeader)
            group("It can see", [String(localized: "Titles, authors, ratings and moods of your books"),
                                 String(localized: "Your shelves, reading progress and goal")]
                  + (includeNotes ? [String(localized: "Your reading notes (you turned this on)")] : [])
                  + (includeProfile ? [String(localized: "Your first name and “About me” (you turned this on)")] : []))
            group("It never sees", [includeProfile ? String(localized: "Your email, photo or location")
                                                   : String(localized: "Your name, email, photo or location")]
                  + (includeNotes ? [] : [String(localized: "Your notes")]))
            // The same switch here, so the reader can decide while reading the list.
            Toggle(isOn: $includeProfile) {
                VStack(alignment: .leading, spacing: Space.s2) {
                    Text("Astrid sees my profile").font(.body.weight(.medium)).foregroundStyle(theme.palette.ink)
                    Text("First name and “About me” only").font(.footnote).foregroundStyle(theme.palette.ink2)
                }
            }
            .tint(theme.palette.accent)
            .padding(.vertical, Space.s4)
            Text("Everything runs on your iPhone. To find book ideas, only a short search like “cosy fantasy” goes to Google Books and Open Library.")
                .font(.footnote).foregroundStyle(theme.palette.ink2)
            Spacer(minLength: 0)
        }
        .padding(Space.s24)
        .background(theme.palette.surface.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationCornerRadius(theme.radii.sheet)
    }

    private func group(_ title: LocalizedStringKey, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(theme.palette.ink)
            ForEach(items, id: \.self) { Text("• \($0)").font(.subheadline).foregroundStyle(theme.palette.ink) }
        }
    }
}
