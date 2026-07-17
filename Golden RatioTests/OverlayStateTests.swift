import Testing
import Foundation
@testable import Golden_Ratio

@MainActor
struct OverlayStateTests {
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

    @Test func cycleGuideAdvancesAndWraps() {
        withFreshDefaults { d in
            let s = OverlayState(defaults: d)
            s.isVisible = true
            s.type = .thirds
            s.cycleGuide()
            #expect(s.type == .phiGrid)
            // Wrap: from the last case back to the first.
            s.type = .centerCross
            s.cycleGuide()
            #expect(s.type == .thirds)
            #expect(s.isVisible == true)
        }
    }

    @Test func cycleGuideWhenHiddenShowsWithoutAdvancing() {
        withFreshDefaults { d in
            let s = OverlayState(defaults: d)
            s.type = .diagonals
            s.cycleGuide()
            #expect(s.isVisible == true)
            #expect(s.type == .diagonals)  // first press just shows
        }
    }

    @Test func toggleActivatesSwitchesAndHides() {
        withFreshDefaults { d in
            let s = OverlayState(defaults: d)
            // Activate: hidden → shows the tapped type.
            s.toggle(.goldenSpiral)
            #expect(s.isVisible == true)
            #expect(s.type == .goldenSpiral)
            // Switch: tapping another type selects it and stays visible.
            s.toggle(.diagonals)
            #expect(s.isVisible == true)
            #expect(s.type == .diagonals)
            // Hide: tapping the active type hides; type stays put.
            s.toggle(.diagonals)
            #expect(s.isVisible == false)
            #expect(s.type == .diagonals)
        }
    }
}
