# Golden Ratio v1.1 Spec — Snap, Shortcuts, Temporary Unlock, Settings

Status: implemented · 2026-07-17

> **Post-implementation revisions (2026-07-17):**
> - **F1 Snap to Window was removed at the user's request** after implementation;
>   §F1 and its shortcut are kept below for history only.
> - **F3 modifier-conflict fix:** the held unlock modifier is *consumed* during a
>   temporary unlock — engaging still requires the modifier alone, but once
>   engaged, chords may join (⇧ = aspect resize) and the held key never doubles
>   as a resize option (⌥ no longer forces from-center while temp-unlocked).
>   From-center resize is only available when the overlay is properly unlocked.

## Overview

Four features plus one polish pass, all sandbox-safe (no new permissions, no
Accessibility API, MAS-compatible):

1. **Snap to Window** — one click fits the overlay to the window beneath it.
2. **Global keyboard shortcuts** — user-remappable via the KeyboardShortcuts package.
3. **Hold-modifier temporary unlock** — hold ⌥ (configurable) while locked to adjust.
4. **Welcome → Welcome & Settings window** — shortcut recorders, two launch
   checkboxes, re-openable from a gear button in the menu panel.
5. **Tooltip audit** — `.help` + `.accessibilityLabel` on every control (convention
   already largely in place).

Out of scope (deliberately): window *following*, auto contrast, opacity/thickness
controls, multiple overlays.

---

## F1 — Snap to Window

**Interaction.** New button on the overlay's HUD chrome strip (after Rotate,
before Lock): symbol `rectangle.arrowtriangle.2.inward`, tooltip **"Snap to
Window Below"**. Semantics: *fit to the topmost window under the overlay's
center point*. The user drags the overlay roughly over the target and clicks;
the overlay animates to that window's bounds. Mirrored in the menu panel's
control row (same disabled rules as flip/rotate: needs visible + unlocked),
where the semantics fall back to *frontmost window that isn't Golden Ratio*
(the menu panel steals focus, so "under the overlay" may not apply if the
overlay is elsewhere — use center-point first, frontmost-other as fallback in
both entry points). Also bound to a global shortcut (F2).

**Candidate window query.** `CGWindowListCopyWindowInfo([.optionOnScreenOnly,
.excludeDesktopElements])`, front-to-back order:
- exclude own PID (`NSRunningApplication.current.processIdentifier`)
- `kCGWindowLayer == 0` (normal windows only — skips menu bar, Dock, panels)
- `kCGWindowAlpha > 0`, bounds at least 50×50
- first window whose bounds contain the overlay's center → hit
- else: first window in the list passing the filters (≈ frontmost non-self)

No permissions needed: bounds + owner PID are readable in the sandbox (only
window *titles* would require Screen Recording — we never read titles).

**Coordinate conversion.** CGWindowList bounds are CG coordinates (origin
top-left of primary display, y-down); `NSPanel.setFrame` wants AppKit (y-up):
`appKitY = primaryScreenHeight − (cgY + height)`.

**Structure.**
- `Geometry/WindowSnapMath.swift` — `nonisolated` pure functions: coordinate
  flip, candidate filtering/selection over plain value structs (no CG types in
  signatures where avoidable). Unit-tested like `OverlayFrameMath`.
- `Overlay/WindowSnapper.swift` — thin `@MainActor` wrapper that performs the
  CGWindowList query and feeds `WindowSnapMath`.
- `OverlayWindowController.snapToWindowBelow()` — resolves target, animates
  `setFrame` via `NSAnimationContext` (~0.18 s ease-out; instant under Reduce
  Motion), then persists through the existing `dragEnded()` save path.

**No target found** (e.g. only the desktop under the overlay): show a transient
HUD badge reusing the lock-badge pattern — "No window below" — and leave the
frame untouched.

**Fit box.** Whole window bounds including title bar (matches what a window
screenshot shows). No content-region detection — that's AX territory we're
avoiding.

---

## F2 — Global keyboard shortcuts (user-remappable)

**Dependency.** `sindresorhus/KeyboardShortcuts` via SPM. MAS/sandbox-safe
(Carbon `RegisterEventHotKey` under the hood). ⚠️ Adding the package touches
`project.pbxproj` (package reference + product dependency) — coordinate with
the user's open Xcode per repo convention before editing; alternatively the
user adds the package in Xcode and the implementation lands afterwards.

**Actions and defaults** (all remappable; ⌃⌥ family chosen to avoid common
app/menu conflicts):

| Action | Default | Behavior |
|---|---|---|
| Toggle Overlay | ⌃⌥G | `state.isVisible.toggle()` |
| Cycle Guide | ⌃⌥C | next `OverlayType` (wraps); shows overlay if hidden |
| Flip Horizontal | ⌃⌥H | `orientation.flipHorizontal()` — requires visible + unlocked |
| Flip Vertical | ⌃⌥V | `orientation.flipVertical()` — requires visible + unlocked |
| Rotate 90° | ⌃⌥R | `orientation.rotate90()` — requires visible + unlocked |
| Lock / Unlock | ⌃⌥L | `isLocked.toggle()` — requires visible |
| Snap to Window | ⌃⌥S | F1 action — requires visible + unlocked |

**Wiring.** `Shortcuts/ShortcutNames.swift` defines the
`KeyboardShortcuts.Name` extensions with `initial:` values. `AppModel` owns one
`for await event in KeyboardShortcuts.events(for:)` task per action (keyUp),
each mutating `OverlayState` — the existing observation plumbing does the rest.
Guards (visible/unlocked) live next to the mutations so menu buttons and
shortcuts share the same rules.

**Remapping UI** lives in the Welcome & Settings window (F4) via
`KeyboardShortcuts.Recorder` rows — persistence, conflict warnings (menu/system
shortcuts), and reset come with the package. Include a small "Reset All
Shortcuts" affordance.

---

## F3 — Hold-modifier temporary unlock

**Interaction.** While the overlay is **locked**, holding the configured
modifier (default **⌥ Option**) makes it temporarily interactive: chrome fades
in, drags/resizes/strip buttons work. Releasing the modifier instantly returns
it to click-through. Lock state itself never changes — this is a bypass, not a
toggle.

**Configurable modifier.** Picker in Settings: **Option (recommended) /
Command / Control / Off**. Engage rule: *exactly* the chosen modifier is down
(`flags.intersection(.deviceIndependentFlagsMask) == chosen`) — so ⌘C, ⌥⇧-drag
in other apps, etc. don't engage it. Copy in Settings should carry a one-line
hint for Command ("may interfere with ⌘-clicking in apps under the overlay") —
reason ⌥ is the default.

**Implementation.**
- `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` +
  `addLocalMonitorForEvents` (global monitors don't fire while our own app is
  active). Modifier-only monitoring requires **no** Accessibility permission.
- New transient `OverlayState.isTemporarilyUnlocked` (not persisted, no `didSet`
  save). Effective interactivity: `panel.ignoresMouseEvents = isLocked &&
  !isTemporarilyUnlocked`; chrome visibility gains the same term.
- Monitor lifecycle owned by `OverlayWindowController` (installed only while
  `isLocked`, torn down on unlock/hide).
- Edge: modifier released mid-drag → finish the frame math from the captured
  anchor, then re-engage click-through on gesture end (don't yank the window
  mid-gesture).
- Pure, testable piece: `TempUnlockMath.engaged(flags:chosen:)`-style helper,
  `nonisolated`, unit-tested.

**Lock badge copy** updates to teach the feature:
"Locked — hold ⌥ to adjust" (symbol reflects the configured modifier; falls
back to the current "unlock from the menu bar" wording when set to Off).

---

## F4 — Welcome & Settings window

The existing welcome window grows into the app's single utility window: still
the first-run greeting, now also the settings surface. Keep
`WelcomeWindowController` / `WelcomeView` names (role is "welcome & settings";
rename is churn with no behavior gain — revisit if a real Settings scene ever
appears).

**Layout** (single column, ~380 pt wide, sections in order):
1. **Hero** — unchanged: app icon, title, two-line explainer.
2. **Shortcuts** — `Form`/`GroupBox` with one `KeyboardShortcuts.Recorder` row
   per F2 action, labels matching tooltip wording ("Toggle Overlay:", …), plus
   the temporary-unlock modifier picker ("Hold to adjust while locked:") and a
   right-aligned small "Reset All" button.
3. **Options** — two toggles with parallel wording:
   - **"Open Golden Ratio at login"** — backed by `SMAppService.mainApp`
     (`register()`/`unregister()`); read `.status` on window appear rather than
     storing a flag, since System Settings can change it behind our back.
     Sandbox-safe, no prompt (user can manage it in System Settings › Login Items).
   - **"Show this window at launch"** — new `showWelcomeAtLaunch` default
     (default **off**). First launch keeps the existing show-once
     `consumeFirstLaunch` flag; afterwards the window appears at launch only if
     this is checked. `showIfFirstLaunch()` becomes `showIfNeeded()`:
     first-launch OR preference.
4. **"Got It"** button — unchanged (glass styles are fine here; it's a real
   window, unlike the overlay panel where glass must not be used).

**Re-opening.** New gear button in the menu panel's control row, placed left of
the Spacer's quit button group: symbol `gearshape`, tooltip **"Settings"**,
action `AppModel.shared`-free — `MenuPanelView` gets the welcome controller (or
a callback) injected the same way it gets `state`. Always enabled.

**Window sizing.** The window grows past the current 360 pt fixed frame; keep
fixed-width, intrinsic height. Content must remain scannable — if it feels
long, the Shortcuts section may collapse into a `DisclosureGroup` (default
expanded on first launch, collapsed thereafter).

---

## F5 — Tooltip audit

Convention (already followed by `controlButton` and `ChromeStripButton`): every
interactive control gets `.help` **and** `.accessibilityLabel` with the same
string. Sweep:
- ✅ existing menu tiles, swatches, control row, chrome strip — done.
- ➕ new controls: snap buttons, gear button, recorder rows (labels suffice),
  toggles (labels suffice), Reset All.
- ➕ "Got It" gets `.help("Close this window")` for completeness.
- Tooltips should mention the current default shortcut where one exists, e.g.
  "Lock (click-through) — ⌃⌥L". If dynamic (post-remap) strings are cheap via
  `KeyboardShortcuts.getShortcut(for:)`, show the live binding; otherwise ship
  the defaults in copy and revisit.

---

## Cross-cutting

**Persistence.** New keys: `showWelcomeAtLaunch` (Bool), `tempUnlockModifier`
(raw string: option/command/control/off) — added to the existing
`overlayState.v1`-style snapshot or standalone defaults keys (implementer's
choice; shortcuts persist via the package; login item state lives in
`SMAppService`, never duplicated).

**Reduce Motion.** Snap animation, chrome fades, badge transitions all gate on
`accessibilityReduceMotion`, matching existing code.

**Testing** (mirrors existing `nonisolated` test pattern):
- `WindowSnapMathTests` — coordinate flip, candidate filtering, center-hit vs
  frontmost fallback selection.
- `TempUnlockTests` — exact-modifier engage/disengage matrix.
- `WelcomeTests` — extend for `showIfNeeded()` decision table
  (first-launch × preference).
- Manual: snap across two displays; snap with no window below; ⌥-hold during
  an active drag; login-item toggle round-trip vs System Settings.

**Risks / notes.**
- SPM addition edits `project.pbxproj` — coordinate with the user's open Xcode
  (repo convention). Safest: user adds the package in Xcode first.
- Global monitors receive nothing if another app captures the modifier — fine;
  worst case temp-unlock doesn't engage.
- `CGWindowListCopyWindowInfo` is rumored deprecated-ish territory
  (ScreenCaptureKit is the anointed successor for *content*); for bounds-only
  queries it remains the sandbox-safe API of record — verify at implementation
  time against the current SDK.

## Decisions taken (flag if you disagree)

1. Snap = one-shot fit, center-point-under-overlay semantics, whole window incl. title bar.
2. Default shortcuts use the ⌃⌥ family per the table.
3. Temp-unlock modifier choices: Option/Command/Control/Off, default Option; engage requires the modifier *alone*.
4. "Show this window at launch" defaults **off** (first launch still always shows once).
5. Keep `Welcome*` type names; gear button opens the same window.
6. Checkbox wording: "Open Golden Ratio at login" / "Show this window at launch".
