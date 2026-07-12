import AppKit
import SwiftUI
import Observation

/// Owns the overlay NSPanel and keeps it in sync with OverlayState.
/// Views mutate state; this controller applies window-level side effects.
@MainActor
final class OverlayWindowController {
    private let state: OverlayState
    private(set) var panel: OverlayPanel?

    init(state: OverlayState) {
        self.state = state
        observe()
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
            show()
        } else {
            panel?.orderOut(nil)
        }
        panel?.ignoresMouseEvents = state.isLocked
    }

    private func show() {
        let panel = self.panel ?? makePanel()
        if let screen = panel.screen ?? NSScreen.main {
            let clamped = OverlayFrameMath.clamped(panel.frame, to: screen.visibleFrame)
            panel.setFrame(clamped, display: false)
        }
        panel.orderFrontRegardless()
    }

    private func makePanel() -> OverlayPanel {
        let panel = OverlayPanel()
        panel.setFrameAutosaveName("OverlayPanel")
        let root = OverlayContentView(state: state, controller: self)
        panel.contentView = OverlayHostingView(rootView: root)
        self.panel = panel
        return panel
    }
}
