import SwiftUI
import AppKit
import Observation

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
        welcomeController = WelcomeWindowController()
        Self.shared = self
    }
}

/// Bridges AppKit lifecycle callbacks that SwiftUI's App protocol doesn't
/// surface — first-launch presentation and the Finder/Dock reopen path — to the
/// welcome window controller on the shared model.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppModel.shared?.welcomeController.showIfFirstLaunch()
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
            MenuPanelView(state: model.overlayState)
        }
        .menuBarExtraStyle(.window)
    }
}
