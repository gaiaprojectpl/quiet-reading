import SwiftUI

/// The image people share from Stats and Year in books: soft card, up to three covers,
/// one sentence, a line of numbers and the app name. Sized for messages and Instagram Stories.
struct StatsShareCard: View {
    let books: [Book]
    let title: String
    var detail: String?
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            if !books.isEmpty {
                HStack(alignment: .bottom, spacing: Space.s8) {
                    ForEach(books) { BookCover(source: .data($0.coverData), title: $0.title, width: Size.coverM + Space.s8) }
                }
            }
            Text(title)
                .font(theme.headline(28, relativeTo: .title))
                .foregroundStyle(theme.palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail).font(.subheadline).foregroundStyle(theme.palette.ink2)
            }
            HStack(spacing: Space.s6) {
                Image("qs.logo").resizable()
                    .foregroundStyle(theme.palette.bg)
                    .frame(width: Space.s20, height: Space.s20)
                    .background(theme.palette.accent, in: RoundedRectangle(cornerRadius: Space.s4, style: .continuous))
                Text("Quiet Reading").font(.caption.weight(.semibold)).foregroundStyle(theme.palette.accentInk)
            }
            .padding(.top, Space.s8)
        }
        .padding(Space.s32)
        .frame(width: 400, alignment: .leading)
        .background(theme.palette.soft)
    }

    /// Renders the card to a PNG file, the format every sharing app accepts (Messages, Instagram, WhatsApp, Photos…).
    @MainActor
    static func file(books: [Book], title: String, detail: String?, theme: ThemeID, scale: CGFloat) -> SharedImage? {
        let renderer = ImageRenderer(content: StatsShareCard(books: books, title: title, detail: detail).environment(\.theme, theme))
        renderer.scale = scale
        guard let ui = renderer.uiImage, let png = ui.pngData() else { return nil }
        let url = URL.temporaryDirectory.appending(path: "My reading – Quiet Reading.png")
        do { try png.write(to: url, options: .atomic) } catch { return nil }
        return SharedImage(url: url, preview: Image(uiImage: ui))
    }
}

/// A rendered share card: the PNG file to send and a preview for the share sheet.
struct SharedImage: Equatable {
    let url: URL
    let preview: Image
    static func == (a: SharedImage, b: SharedImage) -> Bool { a.url == b.url && a.preview == b.preview }
}

/// Share button that opens the iPhone share sheet straight away (Messages, Instagram, WhatsApp…).
struct ShareImageButton: View {
    let image: SharedImage?
    let caption: String
    @Environment(\.theme) private var theme

    var body: some View {
        if let image {
            ShareLink(item: image.url, message: Text(caption), preview: SharePreview(caption, image: image.preview)) {
                Image("qs.share").resizable().frame(width: Size.iconL, height: Size.iconL)
                    .foregroundStyle(theme.palette.ink)
                    .frame(width: Size.touchIos, height: Size.touchIos)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share")
        }
    }
}
