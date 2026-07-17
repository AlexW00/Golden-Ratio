import SwiftUI
import AppKit
import Observation
import KeyboardShortcuts

@MainActor
@Observable
final class AppModel {
    let overlayState: OverlayState
    let windowController: OverlayWindowController
    let welcomeController: WelcomeWindowController

    /// Weak hook so the AppDelegate (created by AppKit, not by us) can reach the
    /// model without a global singleton. Set in `init`; there is only ever one
    /// AppModel, held by the `@State` on the App struct.
    static weak var shared: AppModel?

    init() {
        let state = OverlayState()
        overlayState = state
        windowController = OverlayWindowController(state: state)
        welcomeController = WelcomeWindowController(state: state)
        Self.shared = self
        observeShortcuts()
    }

    /// One listener task per global shortcut, alive for the app's lifetime
    /// (AppModel is never deallocated). Guards mirror the menu panel's
    /// disabled rules so shortcuts can't do what the buttons can't.
    private func observeShortcuts() {
        listen(to: .toggleOverlay) { state in
            state.isVisible.toggle()
        }
        listen(to: .cycleGuide) { state in
            state.cycleGuide()
        }
        listen(to: .flipHorizontal) { state in
            guard state.isVisible, !state.isLocked else { return }
            state.orientation.flipHorizontal()
        }
        listen(to: .flipVertical) { state in
            guard state.isVisible, !state.isLocked else { return }
            state.orientation.flipVertical()
        }
        listen(to: .rotateGuide) { state in
            guard state.isVisible, !state.isLocked else { return }
            state.orientation.rotate90()
        }
        listen(to: .toggleLock) { state in
            guard state.isVisible else { return }
            state.isLocked.toggle()
        }
    }

    private func listen(
        to name: KeyboardShortcuts.Name,
        action: @escaping @MainActor (OverlayState) -> Void
    ) {
        Task { [overlayState] in
            for await event in KeyboardShortcuts.events(for: name) where event == .keyUp {
                action(overlayState)
            }
        }
    }
}

/// Bridges AppKit lifecycle callbacks that SwiftUI's App protocol doesn't
/// surface — first-launch presentation and the Finder/Dock reopen path — to the
/// welcome window controller on the shared model.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppModel.shared?.welcomeController.showIfNeeded()
    }

    /// Fires when the user activates the app from Finder/Dock while it's already
    /// running (a menu-bar-only app has no windows, so this is the only "open"
    /// signal). Re-show the welcome window and return true to satisfy AppKit.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppModel.shared?.welcomeController.show()
        return true
    }
}

@main
struct Golden_RatioApp: App {
    @State private var model: AppModel
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Construct the model eagerly in App.init (not via a @State autoclosure)
        // so `AppModel.shared` is set before AppKit fires
        // `applicationDidFinishLaunching`, which reads it.
        _model = State(initialValue: AppModel())
    }

    var body: some Scene {
        MenuBarExtra("Golden Ratio", systemImage: "hurricane") {
            MenuPanelView(
                state: model.overlayState,
                openSettings: { [model] in model.welcomeController.show() }
            )
        }
        .menuBarExtraStyle(.window)
    }
}
