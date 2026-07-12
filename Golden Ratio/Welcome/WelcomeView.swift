import SwiftUI
import AppKit

/// Minimal first-run explainer for a menu-bar-only app: says where the app
/// lives and how to summon the overlay, then gets out of the way. Deliberately
/// header-less and setting-less — one icon, one title, two lines, one button.
struct WelcomeView: View {
    /// Supplied by the window controller; dismisses (orders out) the window.
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.2), radius: 6, y: 2)

            Text("Golden Ratio")
                .font(.title2.bold())

            VStack(spacing: 6) {
                Text("Golden Ratio lives in your menu bar.")
                Text(
                    "Click the \(Image(systemName: "hurricane")) spiral icon to place a composition overlay on your screen."
                )
                .multilineTextAlignment(.center)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Button("Got It", action: dismiss)
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 4)
        }
        .padding(40)
        .frame(width: 360)
    }
}
