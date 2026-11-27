import SwiftUI

/// Flow 8 › Edit goal. Typed number (never a stepper). Goals are optional: empty or 0 turns it off.
struct GoalSheet: View {
    @Binding var goal: Int
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationCenterModel.self) private var notifications
    @State private var value: Int?
    @FocusState private var focused: Bool

    private var year: String { String(Calendar.current.component(.year, from: .now)) }
    var finishedThisYear = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            Text("Reading goal").font(theme.headline(24, relativeTo: .title2)).foregroundStyle(theme.palette.ink)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: Space.s8) {
                Text("Books in \(year)").font(.footnote.weight(.medium)).foregroundStyle(theme.palette.ink2)
                HStack {
                    TextField("Books in \(year)", value: $value, format: .number)
                        .keyboardType(.numberPad).focused($focused)
                        .font(.body)
                    Text("books").foregroundStyle(theme.palette.ink2)
                }
                .padding(.horizontal, Space.s16)
                .frame(minHeight: Size.field)
                .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous)
                    .strokeBorder(focused ? theme.palette.focus : theme.palette.lineStrong, lineWidth: focused ? Size.focusRing : Size.stroke))
                Text("Type any number. Leave it empty to turn the goal off.").font(.footnote).foregroundStyle(theme.palette.ink2)
            }
            InfoBanner(message: "Goals are optional. No streaks, no guilt.")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.s20)
        .padding(.top, Space.s24)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button("Save", action: save)
                .buttonStyle(QsButtonStyle(priority: .primary))
                .padding(.horizontal, Space.s20)
                .padding(.bottom, QsLayout.actionsAboveBottomLine)
        }
        .background(theme.palette.surface.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(theme.radii.sheet)
        .onAppear { value = goal > 0 ? goal : nil; focused = true }
    }

    private func save() {
        let new = max(0, value ?? 0)
        let changed = new != goal
        goal = new
        dismiss()
        guard changed else { return }
        if new == 0 {
            notifications.show(String(localized: "Goal turned off"), message: String(localized: "Your stats keep counting quietly."))
        } else {
            let left = max(0, new - finishedThisYear)
            notifications.show(String(localized: "New goal: \(new) books"),
                               message: left == 0 ? String(localized: "You've already reached it.")
                                                  : String(localized: "\(left) to go this year. No rush."))
        }
    }
}
