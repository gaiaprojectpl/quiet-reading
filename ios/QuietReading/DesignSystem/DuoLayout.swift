import SwiftUI

/// How the screen is arranged on iPhone Duo (Figma: Flow 6 / 6b, "Duo system column", "Nav bar · Duo").
/// Read from the system's reserved regions (camera/status column = occlusion, fold = division)
/// and the hinge state, so the layout follows the real device instead of fixed sizes.
struct DuoLayout: Equatable {
    enum Mode: Equatable {
        /// Regular iPhone: bottom tab bar.
        case phone
        /// Duo, one screen (closed, or open without a fold to respect): content left of the system column, rail in the column.
        case single
        /// Duo open like a book: two panes either side of a vertical fold, rail in the column.
        case book
        /// Duo half-folded or turned sideways: view on top, controls below, bottom tab bar.
        case tabletop
        /// Duo open and held upright without a fold to respect: one column, camera/status band
        /// across the top, bottom tab bar.
        case upright
    }

    var mode: Mode = .phone
    /// Width of the right system column (84 pt on Duo); content stays left of it.
    var column: CGFloat = 0
    /// The fold, in screen coordinates. `.zero` when there is none.
    var fold: CGRect = .zero
    /// Height of a camera/status band across the top (Duo upright), 0 when there is none.
    var topBand: CGFloat = 0

    var usesRail: Bool { mode == .single || mode == .book }

    /// Kaja's button rule (27 Nov): buttons are pinned to the bottom and sit 24 pt above the bottom line –
    /// the screen edge, the home-indicator area, the tab bar or the keyboard, whichever is at the bottom.
    var actionsBottom: CGFloat { QsLayout.actionsAboveBottomLine }

    /// Room above titles: the Duo has no status bar at the top edge, or a camera/status band.
    var topSpacing: CGFloat {
        switch mode {
        case .phone, .tabletop: 0
        case .single, .book: Space.s48
        case .upright: max(Space.s48, topBand + Space.s16)
        }
    }

    @available(iOS 27.1, *)
    static func make(from geo: GeometryProxy, hinge: DeviceHinge?) -> DuoLayout {
        let size = geo.size
        let occlusion = geo.reservedRegions(kind: .occlusion).filter(\.isActive)
        // The system column: a tall occlusion region against the right edge.
        let column = occlusion
            .filter { $0.frame.maxX >= size.width - 1 && $0.frame.minX > size.width / 2 && $0.frame.height > $0.frame.width }
            .map { size.width - $0.frame.minX }
            .max() ?? 0
        // A camera/status band across the top (anything at the top edge that isn't inside the column).
        let topBand = occlusion
            .filter { $0.frame.minY <= 1 && $0.frame.minX < size.width - column - 1 }
            .map(\.frame.maxY)
            .max() ?? 0
        // Only a foldable reports a fold (even while flat). iPhones report the Dynamic Island as occlusion, so that isn't enough.
        let isDuo = !geo.reservedRegions(kind: .division, options: .includeInactive).isEmpty

        // The fold only matters while the phone is open. When the app starts already open, the hinge
        // hasn't been reported yet and a flat fold counts as "inactive" – so use it unless the hinge says closed.
        // (Closed, the outer screen reports no fold at all.)
        let fold: ReservedRegion? = hinge?.status == .closed
            ? nil
            : geo.reservedRegions(kind: .division, options: .includeInactive).first

        if let fold {
            let vertical = fold.frame.height > fold.frame.width
            if vertical && column > 0 {
                return DuoLayout(mode: .book, column: column, fold: fold.frame, topBand: topBand)
            }
            if !vertical {
                return DuoLayout(mode: .tabletop, column: column, fold: fold.frame, topBand: topBand)
            }
        }
        if column > 0 { return DuoLayout(mode: .single, column: column, topBand: topBand) }
        return DuoLayout(mode: isDuo ? .upright : .phone, column: 0, topBand: topBand)
    }
}

extension EnvironmentValues {
    @Entry var duoLayout = DuoLayout()
}

/// Measures the screen and publishes `\.duoLayout` to everything inside.
struct DuoLayoutReader<Content: View>: View {
    @ViewBuilder var content: (DuoLayout) -> Content
    @State private var layout = DuoLayout()
    @State private var hingeBox = HingeBox()

    var body: some View {
        content(layout)
            .environment(\.duoLayout, layout)
            .background {
                if #available(iOS 27.1, *) {
                    GeometryReader { geo in
                        let new = DuoLayout.make(from: geo, hinge: hingeBox.hinge as? DeviceHinge)
                        Color.clear
                            .onAppear { layout = new }
                            .onChange(of: new) { _, value in layout = value }
                    }
                    .ignoresSafeArea()
                    .onHingeChange { _, context in hingeBox.hinge = context.hinge }
                }
            }
    }
}

/// Holds the hinge value without naming the iOS 27.1 type in stored properties (the app supports iOS 18).
@Observable
final class HingeBox {
    var hinge: Any?
}
