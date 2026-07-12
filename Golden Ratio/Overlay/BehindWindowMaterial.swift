import AppKit
import SwiftUI

/// Behind-window vibrancy for chrome on the transparent overlay panel.
/// glassEffect cannot work here: it lenses in-window content, and this window
/// has none — .behindWindow sampling blurs the apps beneath the overlay.
struct BehindWindowMaterial: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}
