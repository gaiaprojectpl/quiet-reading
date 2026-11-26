import SwiftUI

struct StatsView: View {
    var body: some View {
        ScreenScaffold(title: "Stats") {
            EmptyStateView(
                systemImage: "chart.bar",
                title: "Your stats will grow with you",
                message: "Update a page or finish a book."
            )
        }
    }
}

#Preview { StatsView() }
