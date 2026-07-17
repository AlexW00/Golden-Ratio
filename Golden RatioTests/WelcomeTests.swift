import Testing
import Foundation
@testable import Golden_Ratio

struct WelcomeTests {
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

    // MARK: - "Show this window at launch" decision

    @Test func firstLaunchAlwaysShows() {
        withFreshDefaults { d in
            // Preference defaults to off, but the very first launch shows once.
            #expect(WelcomeWindowController.shouldShowAtLaunch(defaults: d) == true)
        }
    }

    @Test func laterLaunchesRespectThePreference() {
        withFreshDefaults { d in
            _ = WelcomeWindowController.shouldShowAtLaunch(defaults: d)  // consume first launch
            // Preference off (default): stay hidden.
            #expect(WelcomeWindowController.shouldShowAtLaunch(defaults: d) == false)
            // Preference on: show every launch.
            d.set(true, forKey: WelcomeWindowController.showAtLaunchKey)
            #expect(WelcomeWindowController.shouldShowAtLaunch(defaults: d) == true)
            d.set(false, forKey: WelcomeWindowController.showAtLaunchKey)
            #expect(WelcomeWindowController.shouldShowAtLaunch(defaults: d) == false)
        }
    }
}
