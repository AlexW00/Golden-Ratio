import AppKit
import SwiftUI
import Observation

/// Owns the overlay NSPanel and keeps it in sync with OverlayState.
/// Views mutate state; this controller applies window-level side effects.
@MainActor
final class OverlayWindowController {
    private let state: OverlayState
    private var panel: OverlayPanel?

    /// flagsChanged monitors (one global, one local) driving the temporary
    /// unlock. Installed only while the overlay is visible, locked, and the
    /// feature is enabled. Modifier-only monitoring needs no Accessibility
    /// permission.
    private var flagsMonitors: [Any] = []

    /// True between the first move/resize tick of a gesture and dragEnded().
    /// A temp-unlock release mid-drag is deferred until the gesture ends so
    /// the window isn't yanked out from under the pointer.
    private var isDragging = false

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
        isDragging = true
        panel?.setFrameOrigin(OverlayFrameMath.moved(from: initial, translation: translation).origin)
    }

    func resize(
        _ handle: ResizeHandle,
        from initial: CGRect,
        translation: CGSize,
        options: OverlayFrameMath.ResizeOptions
    ) {
        isDragging = true
        panel?.setFrame(
            OverlayFrameMath.frame(after: handle, translation: translation, initial: initial, options: options),
            display: true
        )
    }

    /// Persist the frame once, when a move/resize gesture ends.
    func dragEnded() {
        isDragging = false
        panel?.saveFrame(usingName: Self.frameAutosaveName)
        // Apply a temp-unlock release that was deferred for the gesture.
        if state.isTemporarilyUnlocked {
            state.isTemporarilyUnlocked = state.tempUnlockModifier.staysEngaged(by: NSEvent.modifierFlags)
        }
    }

    private func observe() {
        withObservationTracking {
            _ = state.isVisible
            _ = state.isLocked
            _ = state.isTemporarilyUnlocked
            _ = state.tempUnlockModifier
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
        panel?.ignoresMouseEvents = state.isLocked && !state.isTemporarilyUnlocked
        updateTempUnlockMonitors()
    }

    // MARK: - Temporary unlock (hold-modifier)

    private func updateTempUnlockMonitors() {
        let wanted = state.isVisible && state.isLocked && state.tempUnlockModifier != .off
        if wanted && flagsMonitors.isEmpty {
            // Global monitors don't fire while our own app is active; the
            // local monitor covers that case. Both deliver on the main thread.
            if let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
                self?.flagsChanged(event.modifierFlags)
            }) {
                flagsMonitors.append(global)
            }
            if let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
                self?.flagsChanged(event.modifierFlags)
                return event
            }) {
                flagsMonitors.append(local)
            }
        } else if !wanted && !flagsMonitors.isEmpty {
            flagsMonitors.forEach(NSEvent.removeMonitor)
            flagsMonitors = []
            state.isTemporarilyUnlocked = false
        }
    }

    private func flagsChanged(_ flags: NSEvent.ModifierFlags) {
        // Engaging requires the modifier alone (chords in other apps must not
        // unlock); once engaged, chords may join (⇧ for aspect resize).
        let engaged = state.isTemporarilyUnlocked
            ? state.tempUnlockModifier.staysEngaged(by: flags)
            : state.tempUnlockModifier.isEngaged(by: flags)
        // Don't re-lock mid-gesture; dragEnded() re-evaluates.
        if !engaged && isDragging { return }
        if state.isTemporarilyUnlocked != engaged {
            state.isTemporarilyUnlocked = engaged
        }
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
