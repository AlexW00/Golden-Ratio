import AppKit
import SwiftUI

/// Owns the single welcome NSWindow and the "have we greeted this user yet"
/// flag. The window is created lazily so tests can exercise the first-launch
/// decision without ordering a window on screen.
@MainActor
final class WelcomeWindowController {
    /// UserDefaults key persisting whether the welcome window has been shown.
    /// Versioned so a future redesign can re-greet existing users by bumping it.
    nonisolated static let hasShownWelcomeKey = "hasShownWelcome.v1"

    private let defaults: UserDefaults
    private var window: NSWindow?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Pure first-launch decision: returns `true` exactly once per defaults
    /// suite (the first call), flipping the persisted flag as a side effect so
    /// every later call — including after relaunch — returns `false`.
    /// `nonisolated` so the logic is testable off the main actor.
    nonisolated static func consumeFirstLaunch(defaults: UserDefaults) -> Bool {
        guard !defaults.bool(forKey: hasShownWelcomeKey) else { return false }
        defaults.set(true, forKey: hasShownWelcomeKey)
        return true
    }

    /// Shows the welcome window only on the first launch of a fresh install.
    func showIfFirstLaunch() {
        if Self.consumeFirstLaunch(defaults: defaults) {
            show()
        }
    }

    /// Shows (creating on first use) and brings the welcome window to front.
    /// Also drives the Finder/Dock reopen path, so it may run while the window
    /// already exists — `isReleasedWhenClosed = false` keeps it reusable.
    func show() {
        let window = window ?? makeWindow()
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let hosting = NSHostingController(rootView: WelcomeView(dismiss: { [weak self] in
            self?.window?.close()
        }))
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        // Keep the instance alive after the user closes it so a later reopen
        // (Finder/Dock) can reuse it instead of dereferencing a freed window.
        window.isReleasedWhenClosed = false
        self.window = window
        return window
    }
}
