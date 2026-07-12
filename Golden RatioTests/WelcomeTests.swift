import Testing
import Foundation
@testable import Golden_Ratio

struct WelcomeTests {
    /// Runs `body` with a private, empty UserDefaults suite and removes its
    /// persistent domain afterwards so tests don't leak plists — mirrors the
    /// `withFreshDefaults` pattern in OverlayStateTests.
    private func withFreshDefaults(_ body: (UserDefaults) -> Void) {
        let name = "WelcomeTests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        defer { d.removePersistentDomain(forName: name) }
        body(d)
    }

    @Test func firstLaunchIsConsumedExactlyOnce() {
        withFreshDefaults { d in
            // Fresh container: the very first call reports "show".
            #expect(WelcomeWindowController.consumeFirstLaunch(defaults: d) == true)
            // Every subsequent call reports "already shown".
            #expect(WelcomeWindowController.consumeFirstLaunch(defaults: d) == false)
            #expect(WelcomeWindowController.consumeFirstLaunch(defaults: d) == false)
        }
    }

    @Test func consumeFirstLaunchPersistsTheFlag() {
        withFreshDefaults { d in
            _ = WelcomeWindowController.consumeFirstLaunch(defaults: d)
            // Flag is persisted under the documented key, so a "relaunch"
            // reading the same suite never shows the welcome window again.
            #expect(d.bool(forKey: WelcomeWindowController.hasShownWelcomeKey) == true)
        }
    }
}
