import Testing
import Foundation
@testable import Golden_Ratio

@MainActor
struct OverlayStateTests {
    private func freshDefaults() -> UserDefaults {
        let name = "OverlayStateTests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func defaultsAreSpecCompliant() {
        let s = OverlayState(defaults: freshDefaults())
        #expect(s.type == .thirds)
        #expect(s.color == .gold)
        #expect(s.orientation == .identity)
        #expect(s.isVisible == false)
        #expect(s.isLocked == false)
    }

    @Test func stateRoundTripsThroughDefaults() {
        let d = freshDefaults()
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

    @Test func lockNeverPersistsAsLocked() {
        let d = freshDefaults()
        let s1 = OverlayState(defaults: d)
        s1.isVisible = true
        s1.isLocked = true

        let s2 = OverlayState(defaults: d)
        #expect(s2.isLocked == false)  // relaunch must never strand the user
        #expect(s2.isVisible == true)
    }
}
