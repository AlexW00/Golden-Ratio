import AppKit
import KeyboardShortcuts

/// Global shortcut actions. Defaults use the ⌃⌥ family to stay clear of
/// common app and menu shortcuts; all are user-remappable in the welcome &
/// settings window.
extension KeyboardShortcuts.Name {
    static let toggleOverlay = Self(
        "toggleOverlay", default: .init(.g, modifiers: [.control, .option])
    )
    static let cycleGuide = Self(
        "cycleGuide", default: .init(.c, modifiers: [.control, .option])
    )
    static let flipHorizontal = Self(
        "flipHorizontal", default: .init(.h, modifiers: [.control, .option])
    )
    static let flipVertical = Self(
        "flipVertical", default: .init(.v, modifiers: [.control, .option])
    )
    static let rotateGuide = Self(
        "rotateGuide", default: .init(.r, modifiers: [.control, .option])
    )
    static let toggleLock = Self(
        "toggleLock", default: .init(.l, modifiers: [.control, .option])
    )
}

/// Tooltip text with the live shortcut binding appended, e.g.
/// "Lock (click-through) — ⌃⌥L". Falls back to the bare text when the
/// user has cleared the binding.
@MainActor
func helpText(_ base: String, shortcut name: KeyboardShortcuts.Name) -> String {
    guard let shortcut = KeyboardShortcuts.getShortcut(for: name) else { return base }
    return "\(base) — \(shortcut)"
}
