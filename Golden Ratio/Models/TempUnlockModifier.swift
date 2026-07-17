import AppKit

/// Which modifier key, held while the overlay is locked, temporarily makes it
/// interactive. `off` disables the feature.
nonisolated enum TempUnlockModifier: String, Codable, CaseIterable, Identifiable, Sendable {
    case option, command, control, off

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .option: "⌥ Option"
        case .command: "⌘ Command"
        case .control: "⌃ Control"
        case .off: "Off"
        }
    }

    /// The bare key glyph for badge copy ("hold ⌥ to adjust").
    var keySymbol: String? {
        switch self {
        case .option: "⌥"
        case .command: "⌘"
        case .control: "⌃"
        case .off: nil
        }
    }

    private var flag: NSEvent.ModifierFlags? {
        switch self {
        case .option: .option
        case .command: .command
        case .control: .control
        case .off: nil
        }
    }

    /// True when `flags` engage the temporary unlock: exactly this modifier is
    /// down, nothing else. Exactness keeps ⌘C-style chords in other apps from
    /// unlocking the overlay.
    func isEngaged(by flags: NSEvent.ModifierFlags) -> Bool {
        guard let flag else { return false }
        return flags.intersection(.deviceIndependentFlagsMask) == flag
    }

    /// Once engaged, the unlock persists while this modifier stays held even
    /// as other modifiers join — ⇧ for aspect resize must not re-lock.
    func staysEngaged(by flags: NSEvent.ModifierFlags) -> Bool {
        guard let flag else { return false }
        return flags.intersection(.deviceIndependentFlagsMask).contains(flag)
    }

    /// Removes this modifier from sampled flags so the held unlock key never
    /// doubles as a gesture modifier (⌥-unlock forcing from-center resize).
    func consumed(from flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        guard let flag else { return flags }
        return flags.subtracting(flag)
    }
}
