import SwiftUI
import AppKit
import KeyboardShortcuts

/// The app's single utility window: first-run explainer on top, then the
/// settings that don't fit a menu-bar panel — shortcut remapping, the
/// temporary-unlock modifier, and the two launch options.
struct WelcomeView: View {
    @Bindable var state: OverlayState
    /// Supplied by the window controller; dismisses (orders out) the window.
    let dismiss: () -> Void

    @AppStorage(WelcomeWindowController.showAtLaunchKey) private var showAtLaunch = false
    @State private var openAtLogin = LoginItem.isEnabled

    var body: some View {
        VStack(spacing: 18) {
            hero
            shortcutsSection
            optionsSection

            Button("Got It", action: dismiss)
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
                .help("Close this window")
                .padding(.top, 2)
        }
        .padding(28)
        .frame(width: 440)
        // Login-item status can change in System Settings while we're closed.
        .onAppear { openAtLogin = LoginItem.isEnabled }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
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
        }
    }

    // MARK: - Shortcuts

    private var shortcutsSection: some View {
        GroupBox {
            VStack(spacing: 10) {
                Form {
                    KeyboardShortcuts.Recorder("Toggle Overlay:", name: .toggleOverlay)
                    KeyboardShortcuts.Recorder("Cycle Guide:", name: .cycleGuide)
                    KeyboardShortcuts.Recorder("Flip Horizontal:", name: .flipHorizontal)
                    KeyboardShortcuts.Recorder("Flip Vertical:", name: .flipVertical)
                    KeyboardShortcuts.Recorder("Rotate 90°:", name: .rotateGuide)
                    KeyboardShortcuts.Recorder("Lock / Unlock:", name: .toggleLock)

                    Picker("Hold to Adjust While Locked:", selection: $state.tempUnlockModifier) {
                        ForEach(TempUnlockModifier.allCases) { modifier in
                            Text(modifier.displayName).tag(modifier)
                        }
                    }
                    .pickerStyle(.menu)
                    .help("Hold this key while the overlay is locked to move or resize it")

                    if state.tempUnlockModifier == .command {
                        Text("⌘ can interfere with Command-clicking in apps under the overlay.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .formStyle(.columns)

                Divider()

                Button("Reset All Shortcuts", action: resetAllShortcuts)
                    .controlSize(.small)
                    .help("Restore the default key combinations")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(6)
        } label: {
            Label("Shortcuts", systemImage: "keyboard")
                .font(.headline)
        }
    }

    private func resetAllShortcuts() {
        KeyboardShortcuts.reset(
            .toggleOverlay, .cycleGuide, .flipHorizontal, .flipVertical,
            .rotateGuide, .toggleLock
        )
    }

    // MARK: - Options

    private var optionsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Open Golden Ratio at login", isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { _, enabled in
                        LoginItem.setEnabled(enabled)
                    }
                    .help("Start Golden Ratio automatically when you log in")
                Toggle("Show this window at launch", isOn: $showAtLaunch)
                    .help("Reopen this window every time the app starts")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        } label: {
            Label("Options", systemImage: "switch.2")
                .font(.headline)
        }
    }
}
