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
            // Temporary controls; replaced by MenuPanelView in Task 7.
            Button(model.overlayState.isVisible ? "Hide Overlay" : "Show Overlay") {
                model.overlayState.isVisible.toggle()
            }
            .padding()
        }
        .menuBarExtraStyle(.window)
    }
}
