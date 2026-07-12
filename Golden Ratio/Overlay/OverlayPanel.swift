import AppKit
import SwiftUI

/// Borderless, non-activating floating panel that carries the overlay.
/// Never becomes key or main, so clicks on it don't steal focus from the
/// app being composed (e.g. Photomator).
final class OverlayPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 200, y: 200, width: 480, height: 320),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = false  // we implement dragging ourselves
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Hosting view that responds to the first click even though the panel
/// never becomes key.
final class OverlayHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
