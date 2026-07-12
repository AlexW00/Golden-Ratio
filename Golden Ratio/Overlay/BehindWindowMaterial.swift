import AppKit
import SwiftUI

/// Behind-window vibrancy for chrome on the transparent overlay panel.
/// glassEffect cannot work here: it lenses in-window content, and this window
/// has none — .behindWindow sampling blurs the apps beneath the overlay.
/// Pinned to dark vibrancy regardless of system appearance: this HUD chrome
/// floats over arbitrary content and uses white glyphs, so it must always
/// render dark to stay legible whether the system is in light or dark mode.
struct BehindWindowMaterial: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .vibrantDark)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}
