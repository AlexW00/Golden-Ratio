import SwiftUI

/// Guide drawing + interactive chrome. Task 7 fills this in; this stub
/// only proves the window pipeline (visible tinted guide rectangle).
struct OverlayContentView: View {
    let state: OverlayState
    unowned let controller: OverlayWindowController

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let path = GuideGeometry.path(for: state.type, in: rect, orientation: state.orientation)
            context.stroke(path, with: .color(state.color.color.opacity(0.9)), lineWidth: 1.5)
        }
        .ignoresSafeArea()
    }
}
