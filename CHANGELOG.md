# Changelog

## 1.1 — unreleased

### Added
- **Global keyboard shortcuts** for every overlay action — show/hide (⌃⌥G), cycle guide (⌃⌥C), flip horizontal (⌃⌥H), flip vertical (⌃⌥V), rotate 90° (⌃⌥R), and lock (⌃⌥L). All remappable.
- **Settings window** (gear button in the menu bar panel, doubles as the welcome window): shortcut recorders with conflict warnings, reset-to-defaults, and launch options.
- **Hold ⌥ to adjust while locked** — temporarily move/resize a locked overlay without unlocking; release to snap back to click-through. The modifier is configurable (⌥/⌘/⌃/off).
- **Open at login** and **show this window at launch** options.
- Tooltips on every control now display the live keyboard-shortcut binding.

### Changed
- The held unlock modifier is consumed while temporarily unlocked, so ⌥ no longer forces resize-from-center; ⇧ (keep aspect) still works mid-hold. From-center resize remains available when the overlay is unlocked normally.
- The lock badge now teaches the hold-to-adjust gesture ("Locked — hold ⌥ to adjust").

## 1.0 — 2026-07-12

- Initial release: six composition guides (Rule of Thirds, Phi Grid, Golden Spiral, Golden Diagonals, Harmonic Armature, Center Cross), eight orientations (rotate/flip), six line colors with contrast understroke, click-through lock mode, full state persistence, menu-bar-only UI.
