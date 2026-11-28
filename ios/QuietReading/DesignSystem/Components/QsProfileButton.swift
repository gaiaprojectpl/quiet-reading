import SwiftUI

/// 🧱 Components › Profile button (Figma 273:1393): opens Profile & Settings.
/// Trailing-most item of the title row on the root tab screens only (Home, Explore, Library, Stats);
/// never on pushed screens, sheets, modals, onboarding, camera or paywall.
/// 32 pt photo in a 44 pt hit area. No photo → initials on soft (a person icon until there's a name).
struct QsProfileButton: View {
    @Environment(WidgetRouter.self) private var router
    @Environment(\.theme) private var theme
    @AppStorage(ProfileKeys.name) private var name = ""
    @State private var photo: UIImage?
    @ScaledMetric(relativeTo: .body) private var size = Space.s32

    var body: some View {
        Button { router.showSettings = true } label: {
            Group {
                if photo == nil && name.trimmingCharacters(in: .whitespaces).isEmpty {
                    Image("qs.user").resizable().frame(width: Size.iconM, height: Size.iconM)
                        .foregroundStyle(theme.palette.accentInk)
                        .frame(width: size, height: size)
                        .background(theme.palette.soft, in: Circle())
                } else {
                    AvatarView(image: photo, name: name, size: size, initials: true)
                }
            }
            .frame(width: Size.touchIos, height: Size.touchIos)
            .contentShape(Circle())
        }
        .buttonStyle(QsPressStyle())
        .accessibilityLabel("Profile and settings")
        .onAppear { photo = Avatar.load() }
        // Edit profile saves a new photo: pick it up when Settings closes.
        .onChange(of: router.showSettings) { _, open in if !open { photo = Avatar.load() } }
    }
}
