#if DEBUG
import SwiftUI

/// Test builds only: launch with `-qsDuoProbe YES` to log screen size, reserved regions
/// (camera/system column = occlusion, hinge = division) and hinge state to the console.
struct DuoProbe: ViewModifier {
    @AppStorage("qsDuoProbe") private var enabled = false

    func body(content: Content) -> some View {
        if enabled, #available(iOS 27.1, *) {
            content.overlay {
                GeometryReader { geo in
                    let occ = geo.reservedRegions(kind: .occlusion, options: .includeInactive)
                    let div = geo.reservedRegions(kind: .division, options: .includeInactive)
                    let line = "QSPROBE size=\(fmt(geo.size)) safe=\(geo.safeAreaInsets) occlusion=\(occ.map(describe)) division=\(div.map(describe))"
                    Color.clear
                        .onAppear { print(line) }
                        .onChange(of: line) { _, new in print(new) }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            .onHingeChange { _, new in
                if let h = new.hinge { print("QSPROBE hinge status=\(h.status) angle=\(Int(h.angle.degrees))") }
                else { print("QSPROBE hinge none") }
            }
        } else {
            content
        }
    }

    @available(iOS 27.1, *)
    private func describe(_ r: ReservedRegion) -> String {
        "[\(r.kind) frame=\(Int(r.frame.minX)),\(Int(r.frame.minY)) \(Int(r.frame.width))x\(Int(r.frame.height)) active=\(r.isActive) margins=\(r.margins)]"
    }

    private func fmt(_ s: CGSize) -> String { "\(Int(s.width))x\(Int(s.height))" }
}
#endif
