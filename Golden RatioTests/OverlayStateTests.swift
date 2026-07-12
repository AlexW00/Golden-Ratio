import Testing
import Foundation
@testable import Golden_Ratio

@MainActor
struct OverlayStateTests {
    /// Runs `body` with a private, empty UserDefaults suite and removes its
    /// persistent domain afterwards so tests don't leak plists. Swift Testing
    /// has no per-test teardown for value-type suites, so cleanup lives here.
    private func withFreshDefaults(_ body: (UserDefaults) -> Void) {
        let name = "OverlayStateTests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        defer { d.removePersistentDomain(forName: name) }
        body(d)
    }

    @Test func defaultsAreSpecCompliant() {
        withFreshDefaults { d in
            let s = OverlayState(defaults: d)
            #expect(s.type == .thirds)
            #expect(s.color == .gold)
            #expect(s.orientation == .identity)
            #expect(s.isVisible == false)
            #expect(s.isLocked == false)
        }
    }

    @Test func stateRoundTripsThroughDefaults() {
        withFreshDefaults { d in
            let s1 = OverlayState(defaults: d)
            s1.type = .goldenSpiral
            s1.color = .red
            s1.orientation.rotate90()
            s1.orientation.flipHorizontal()
            s1.isVisible = true

            let s2 = OverlayState(defaults: d)
            #expect(s2.type == .goldenSpiral)
            #expect(s2.color == .red)
            #expect(s2.orientation.quarterTurns == 1)
            #expect(s2.isVisible == true)
        }
    }

    @Test func lockNeverPersistsAsLocked() {
        withFreshDefaults { d in
            let s1 = OverlayState(defaults: d)
            s1.isVisible = true
            s1.isLocked = true

            let s2 = OverlayState(defaults: d)
            #expect(s2.isLocked == false)  // relaunch must never strand the user
            #expect(s2.isVisible == true)
        }
    }

    @Test func hidingResetsLock() {
        withFreshDefaults { d in
            let s = OverlayState(defaults: d)
            s.isVisible = true
            s.isLocked = true
            s.isVisible = false
            #expect(s.isLocked == false)  // re-showing must give recoverable chrome
        }
    }
}
