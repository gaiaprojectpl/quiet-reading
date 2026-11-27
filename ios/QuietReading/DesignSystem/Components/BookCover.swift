import SwiftUI
import UIKit

/// A book cover at 2:3, with the theme's cover radius and soft shadow.
/// Without an image it shows a calm placeholder with the title (covers fill in later).
struct BookCover: View {
    enum Source {
        case data(Data?)
        case asset(String)
    }

    let source: Source
    var title: String = ""
    var width: CGFloat = Size.coverM
    @Environment(\.theme) private var theme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.radii.cover, style: .continuous)
        content
            .frame(width: width, height: width * 1.5)
            .clipShape(shape)
            .shadow(color: .black.opacity(0.16), radius: 4, x: 0, y: 3)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var content: some View {
        switch source {
        case .asset(let name):
            Image(name).resizable().scaledToFill()
        case .data(let data):
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    theme.palette.disabledBg
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(theme.palette.ink2)
                        .multilineTextAlignment(.center)
                        .padding(Space.s4)
                }
            }
        }
    }
}
