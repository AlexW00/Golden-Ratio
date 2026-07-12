import SwiftUI
import Observation

@MainActor
@Observable
final class AppModel {
    let overlayState: OverlayState
    let windowController: OverlayWindowController

    init() {
        let state = OverlayState()
        overlayState = state
        windowController = OverlayWindowController(state: state)
    }
}

@main
struct Golden_RatioApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Golden Ratio", systemImage: "hurricane") {
            MenuPanelView(state: model.overlayState)
        }
        .menuBarExtraStyle(.window)
    }
}
