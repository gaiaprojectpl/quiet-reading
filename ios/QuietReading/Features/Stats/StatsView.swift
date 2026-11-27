import SwiftUI

struct StatsView: View {
    var body: some View {
        ScreenScaffold(title: "Stats") {
            EmptyStateView(
                icon: "qs.stats",
                title: "Your stats will grow with you",
                message: "Update a page or finish a book."
            )
        }
    }
}

#Preview { StatsView() }
