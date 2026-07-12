import SwiftUI

@main
struct Golden_RatioApp: App {
    var body: some Scene {
        MenuBarExtra("Golden Ratio", systemImage: "hurricane") {
            Text("Golden Ratio")
                .padding()
        }
        .menuBarExtraStyle(.window)
    }
}
