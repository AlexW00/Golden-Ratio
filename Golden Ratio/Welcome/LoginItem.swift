import AppKit
import ServiceManagement

/// Thin wrapper over SMAppService for the "Open Golden Ratio at login"
/// toggle. Status is always read live — System Settings › Login Items can
/// change it behind our back, so it is never cached in defaults.
@MainActor
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Non-fatal: the toggle re-reads live status on next appearance.
            NSLog("Login item toggle failed: %@", error.localizedDescription)
        }
    }
}
