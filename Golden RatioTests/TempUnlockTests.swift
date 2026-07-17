import Testing
import AppKit
@testable import Golden_Ratio

nonisolated struct TempUnlockModifierTests {
    @Test func exactModifierEngages() {
        #expect(TempUnlockModifier.option.isEngaged(by: .option))
        #expect(TempUnlockModifier.command.isEngaged(by: .command))
        #expect(TempUnlockModifier.control.isEngaged(by: .control))
    }

    @Test func combinedModifiersDoNotEngage() {
        // ⌥⇧ etc. must not engage: the user is doing something else.
        #expect(!TempUnlockModifier.option.isEngaged(by: [.option, .shift]))
        #expect(!TempUnlockModifier.command.isEngaged(by: [.command, .option]))
    }

    @Test func wrongModifierDoesNotEngage() {
        #expect(!TempUnlockModifier.option.isEngaged(by: .command))
        #expect(!TempUnlockModifier.control.isEngaged(by: .shift))
    }

    @Test func offNeverEngages() {
        #expect(!TempUnlockModifier.off.isEngaged(by: .option))
        #expect(!TempUnlockModifier.off.isEngaged(by: []))
    }

    @Test func deviceDependentBitsAreIgnored() {
        // Raw event flags carry device-dependent bits (e.g. left-vs-right key);
        // only the device-independent mask must be compared.
        let leftOption = NSEvent.ModifierFlags(
            rawValue: NSEvent.ModifierFlags.option.rawValue | 0x20
        )
        #expect(TempUnlockModifier.option.isEngaged(by: leftOption))
    }

    @Test func emptyFlagsDisengage() {
        #expect(!TempUnlockModifier.option.isEngaged(by: []))
    }

    // MARK: - Staying engaged (chords may join once unlocked)

    @Test func staysEngagedWhileChordsJoin() {
        // ⇧ joining ⌥ mid-unlock (aspect resize) must not re-lock.
        #expect(TempUnlockModifier.option.staysEngaged(by: [.option, .shift]))
        #expect(TempUnlockModifier.option.staysEngaged(by: .option))
    }

    @Test func staysEngagedEndsWhenModifierReleases() {
        #expect(!TempUnlockModifier.option.staysEngaged(by: .shift))
        #expect(!TempUnlockModifier.option.staysEngaged(by: []))
        #expect(!TempUnlockModifier.off.staysEngaged(by: .option))
    }

    // MARK: - Consuming the held flag (⌥-unlock must not force from-center)

    @Test func consumedRemovesOnlyOwnFlag() {
        #expect(TempUnlockModifier.option.consumed(from: [.option, .shift]) == .shift)
        #expect(TempUnlockModifier.option.consumed(from: .shift) == .shift)
        #expect(TempUnlockModifier.off.consumed(from: .option) == .option)
    }
}

@MainActor
struct TempUnlockStateTests {
    @Test func modifierDefaultsToOption() {
        withFreshDefaults { d in
            let s = OverlayState(defaults: d)
            #expect(s.tempUnlockModifier == .option)
        }
    }

    @Test func modifierRoundTripsThroughDefaults() {
        withFreshDefaults { d in
            let s1 = OverlayState(defaults: d)
            s1.tempUnlockModifier = .command
            let s2 = OverlayState(defaults: d)
            #expect(s2.tempUnlockModifier == .command)
        }
    }

    @Test func temporaryUnlockNeverPersists() {
        withFreshDefaults { d in
            let s1 = OverlayState(defaults: d)
            s1.isVisible = true
            s1.isLocked = true
            s1.isTemporarilyUnlocked = true
            let s2 = OverlayState(defaults: d)
            #expect(s2.isTemporarilyUnlocked == false)
        }
    }
}
