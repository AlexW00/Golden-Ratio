import AppKit
import SwiftUI
import Observation

/// Owns the overlay NSPanel and keeps it in sync with OverlayState.
/// Views mutate state; this controller applies window-level side effects.
@MainActor
final class OverlayWindowController {
    private let state: OverlayState
    private var panel: OverlayPanel?

    /// Frame persistence key. Frames are restored on panel creation and saved
    /// only at the end of a drag (and after an offscreen clamp), rather than on
    /// every move/resize tick as `setFrameAutosaveName` would do.
    private static let frameAutosaveName = "OverlayPanel"

    init(state: OverlayState) {
        self.state = state
        observe()
    }

    // MARK: - Drag API (views mutate the window only through these)

    /// The panel's current frame, captured once at the start of a drag.
    func dragStartFrame() -> CGRect? { panel?.frame }

    func move(from initial: CGRect, translation: CGSize) {
        panel?.setFrameOrigin(OverlayFrameMath.moved(from: initial, translation: translation).origin)
    }

    func resize(
        _ handle: ResizeHandle,
        from initial: CGRect,
        translation: CGSize,
        options: OverlayFrameMath.ResizeOptions
    ) {
        panel?.setFrame(
            OverlayFrameMath.frame(after: handle, translation: translation, initial: initial, options: options),
            display: true
        )
    }

    /// Persist the frame once, when a move/resize gesture ends.
    func dragEnded() {
        panel?.saveFrame(usingName: Self.frameAutosaveName)
    }

    private func observe() {
        withObservationTracking {
            _ = state.isVisible
            _ = state.isLocked
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.apply()
                self?.observe()  // re-arm: observation tracking is one-shot
            }
        }
        apply()
    }

    private func apply() {
        if state.isVisible {
            if panel?.isVisible != true { show() }
        } else {
            panel?.orderOut(nil)
        }
        panel?.ignoresMouseEvents = state.isLocked
    }

    private func show() {
        let panel = self.panel ?? makePanel()
        // Clamp only when the restored frame lies entirely off every screen —
        // otherwise leave a carefully placed (edge-straddling or multi-display)
        // overlay exactly where the user put it.
        let onScreen = OverlayFrameMath.intersectsAny(panel.frame, of: NSScreen.screens.map(\.visibleFrame))
        if !onScreen, let screen = panel.screen ?? NSScreen.main {
            panel.setFrame(OverlayFrameMath.clamped(panel.frame, to: screen.visibleFrame), display: false)
            panel.saveFrame(usingName: Self.frameAutosaveName)
        }
        panel.orderFrontRegardless()
    }

    private func makePanel() -> OverlayPanel {
        let panel = OverlayPanel()
        panel.setFrameUsingName(Self.frameAutosaveName)
        let root = OverlayContentView(state: state, controller: self)
        panel.contentView = OverlayHostingView(rootView: root)
        self.panel = panel
        return panel
    }
}
