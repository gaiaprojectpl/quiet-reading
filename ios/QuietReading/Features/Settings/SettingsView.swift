import SwiftUI

struct SettingsView: View {
    @AppStorage(ThemeStorage.key) private var chosenTheme: ThemeID = .peachSage
    @Environment(\.theme) private var theme

    /// Night and High contrast follow the system settings (Dark Mode, Increase Contrast).
    private let pickable: [ThemeID] = [.peachSage, .clayCream, .blushIvory, .lavenderMist]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(pickable, id: \.self) { id in
                        Button {
                            chosenTheme = id
                        } label: {
                            HStack(spacing: Space.s12) {
                                ThemeSwatch(id: id)
                                Text(id.displayName)
                                    .foregroundStyle(theme.palette.ink)
                                if id.requiresPlus {
                                    Text("Plus")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(theme.palette.accentInk)
                                        .padding(.horizontal, Space.s8)
                                        .padding(.vertical, Space.s2)
                                        .background(theme.palette.soft, in: Capsule())
                                }
                                Spacer()
                                if id == chosenTheme {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(theme.palette.accentInk)
                                        .accessibilityLabel("Selected")
                                }
                            }
                            .frame(minHeight: Size.touchIos)
                        }
                    }
                } header: {
                    Text("App theme")
                } footer: {
                    Text("Dark Mode uses Night and Increase Contrast uses High contrast. Both are always free.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.palette.bg.ignoresSafeArea())
            .navigationTitle("Settings")
        }
    }
}

private struct ThemeSwatch: View {
    let id: ThemeID
    var body: some View {
        HStack(spacing: 0) {
            id.palette.bg
            id.palette.soft
            id.palette.accent
        }
        .frame(width: 36, height: 24)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(id.palette.line))
        .accessibilityHidden(true)
    }
}

#Preview { SettingsView() }
