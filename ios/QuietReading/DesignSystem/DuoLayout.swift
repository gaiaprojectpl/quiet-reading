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
    }

    var mode: Mode = .phone
    /// Width of the right system column (84 pt on Duo); content stays left of it.
    var column: CGFloat = 0
    /// The fold, in screen coordinates. `.zero` when there is none.
    var fold: CGRect = .zero

    var usesRail: Bool { mode == .single || mode == .book }

    @available(iOS 27.1, *)
    static func make(from geo: GeometryProxy, hinge: DeviceHinge?) -> DuoLayout {
        let size = geo.size
        // The system column: occlusion regions sitting against the right edge.
        let column = geo.reservedRegions(kind: .occlusion)
            .filter { $0.isActive && $0.frame.maxX >= size.width - 1 && $0.frame.minX > size.width / 2 }
            .map { size.width - $0.frame.minX }
            .max() ?? 0

        // The fold only matters while the phone is open.
        var fold: ReservedRegion?
        if let hinge, hinge.status != .closed {
            fold = geo.reservedRegions(kind: .division, options: .includeInactive).first
        } else if hinge == nil {
            fold = geo.reservedRegions(kind: .division).first { $0.isActive }
        }

        if let fold {
            let vertical = fold.frame.height > fold.frame.width
            return DuoLayout(mode: vertical ? .book : .tabletop, column: column, fold: fold.frame)
        }
        return DuoLayout(mode: column > 0 ? .single : .phone, column: column, fold: .zero)
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
