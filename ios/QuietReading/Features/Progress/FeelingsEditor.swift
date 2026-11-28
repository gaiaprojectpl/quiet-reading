import SwiftUI

/// Feelings a reader can tag a book with. A wide, calm range (not just "good/bad");
/// feelings the reader adds are kept and offered next time.
enum Feelings {
    static let suggested = ["Cozy", "Hopeful", "Heartwarming", "Funny", "Romantic", "Moving", "Sad",
                            "Dark", "Tense", "Mysterious", "Adventurous", "Thoughtful", "Inspiring",
                            "Challenging", "Slow", "Fast-paced", "Comforting", "Re-read"]
    static let storageKey = "customFeelings"

    /// Feelings added by the reader, oldest first (UserDefaults, a few short strings).
    static var custom: [String] {
        get { UserDefaults.standard.stringArray(forKey: storageKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: storageKey) }
    }

    /// Adds a feeling to the saved options (case-insensitive, no duplicates).
    static func remember(_ feeling: String) {
        let all = suggested + custom
        guard !all.contains(where: { $0.caseInsensitiveCompare(feeling) == .orderedSame }) else { return }
        custom.append(feeling)
    }
}

/// "How did it feel?": stars (tap twice for a half) and feeling chips, with "+ Add" for your own.
/// Used by the Finished moment and by Moods in a book's details.
struct FeelingsEditor: View {
    @Binding var stars: Double?
    @Binding var moods: Set<String>
    /// Feelings already on this book that aren't in the options (from an import or an older version).
    var extra: [String] = []
    var showsRating = true
    @Environment(\.theme) private var theme
    @State private var custom = Feelings.custom
    @State private var adding = false
    @State private var newFeeling = ""

    private var options: [String] {
        var seen = Set<String>()
        return (Feelings.suggested + custom + extra).filter { seen.insert($0.lowercased()).inserted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            if showsRating {
                VStack(alignment: .leading, spacing: Space.s8) {
                    label("Your rating")
                    QsStarRating(value: $stars)
                    Text(stars.map { String(localized: "\($0.formatted()) stars · tap a star twice for a half") }
                         ?? String(localized: "Tap a star twice for a half"))
                        .font(.footnote).foregroundStyle(theme.palette.ink2)
                        .accessibilityHidden(true)
                }
            }
            VStack(alignment: .leading, spacing: Space.s8) {
                label("How did it feel?")
                FlowLayout(spacing: Space.s8) {
                    ForEach(options, id: \.self) { mood in
                        QsChip(title: String(localized: String.LocalizationValue(mood)), isSelected: moods.contains(mood)) {
                            if moods.contains(mood) { moods.remove(mood) } else { moods.insert(mood) }
                        }
                    }
                    QsChip(title: String(localized: "Add"), icon: "qs.plus") { adding = true }
                        .accessibilityLabel("Add a feeling")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert("Add a feeling", isPresented: $adding) {
            TextField("For example: Nostalgic", text: $newFeeling)
                .textInputAutocapitalization(.sentences)
            Button("Add") { add() }
            Button("Cancel", role: .cancel) { newFeeling = "" }
        } message: {
            Text("It’s saved for your next books too.")
        }
    }

    private func label(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(theme.palette.ink)
            .accessibilityAddTraits(.isHeader)
    }

    private func add() {
        let feeling = newFeeling.trimmingCharacters(in: .whitespacesAndNewlines)
        newFeeling = ""
        guard !feeling.isEmpty, feeling.count <= 30 else { return }
        let existing = options.first { $0.caseInsensitiveCompare(feeling) == .orderedSame }
        if existing == nil { Feelings.remember(feeling); custom = Feelings.custom }
        moods.insert(existing ?? feeling)
    }
}
