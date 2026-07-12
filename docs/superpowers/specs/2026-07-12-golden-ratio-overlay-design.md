# Golden Ratio — Design Spec

**Date:** 2026-07-12
**Status:** Approved pending user review
**Platform:** macOS 26+ (deployment target 26.5), SwiftUI + AppKit hybrid, App Sandbox on

## Purpose

A stripped-down, menu-bar-only macOS utility that puts a resizable, rotatable composition-guide overlay (rule of thirds, golden spiral, …) on top of any app — built because Photomator can't rotate or flip its overlays. Inspired by Goldie App, reduced to the essentials.

**Non-goals:** no line-thickness/opacity parameters, no multiple simultaneous overlays, no per-display management UI, no onboarding, no Dock icon, no main window.

## User-Facing Behavior

### App shape
- Menu-bar-only app: `LSUIElement = true`, no Dock icon, no main window.
- Menu bar icon: spiral SF Symbol–style glyph, template rendering.
- Zero permissions required: the app never captures the screen or synthesizes input. App Sandbox stays enabled.

### Overlay types (6)
1. **Rule of Thirds** — 3×3 equal grid.
2. **Phi Grid** — 3×3 grid at golden proportions (1 : 0.618 : 1 per axis).
3. **Golden Spiral** — Fibonacci spiral with its golden-rectangle subdivisions. The rotate/flip flagship.
4. **Golden Diagonals** — corner-to-corner X plus reciprocal (Baroque/Sinister) diagonals.
5. **Harmonic Armature** — classic 14-line armature.
6. **Center Cross** — vertical + horizontal midlines with a small center crosshair.

### Menu bar panel (`MenuBarExtra`, `.window` style)
Icon-driven, no text labels except tooltips. ~280 pt wide. Liquid Glass background comes free from the system.
- **Overlay grid (3×2):** each tile is a miniature live drawing of its guide type (drawn with the same geometry code as the overlay, not static assets). Active tile highlighted with the accent. Click to show/switch; click the active tile again to hide the overlay.
- **Color swatches (row of 6):** gold (default), white, black, red, blue, green. Selected swatch shows a ring.
- **Control row:** flip horizontal, flip vertical, rotate 90° CW, lock (click-through toggle), quit. SF Symbols, monochrome, tooltips on hover.
- Controls affecting the overlay are disabled when no overlay is visible (except quit).

### Overlay window
- Borderless, transparent, no title bar/traffic lights. Floats above all normal windows (`.floating` level), appears on every Space and over full-screen apps (`.canJoinAllSpaces`, `.fullScreenAuxiliary`), never activates or steals key focus (non-activating `NSPanel`), excluded from Cmd-backtick cycling.
- **Guides rendering:** chosen color at 90 % opacity, 1.5 pt hairlines, each line with a sub-pixel contrasting shadow so lines read on any background.
- **Hover chrome** (fades in ~150 ms ease-out on mouse-enter, out ~200 ms on exit; no chrome while locked):
  - 8 resize handles (4 corners + 4 edge midpoints), Goldie-style pill/circle grips.
  - ✕ close button at top-left of the frame.
  - Small Liquid Glass control strip at the top edge: flip H, flip V, rotate 90°, lock — mirroring the panel controls.
- **Move:** drag anywhere inside the frame (1:1 tracking). **Resize:** drag handles, free aspect; guides stretch to fill.
- Minimum size 120×120 pt.
- **Rotation/flip are drawing transforms**, not window transforms: rotate 90° re-orients the guide inside the current rectangle; flips mirror it. Rotation + flips cover all 8 spiral orientations. For symmetric guides (thirds, center cross, diagonals) some operations are visual no-ops — that's fine and predictable.
- **Lock (click-through):** `ignoresMouseEvents = true`; all chrome hidden; clicks land in the app beneath. Unlock only via the menu bar panel. A brief glass "locked" badge flashes on lock so the state change is visible.

### Persistence
Overlay frame, type, color, rotation, flips, and visibility persist across launches (`UserDefaults`). On relaunch, a previously visible overlay reappears (unlocked, so the user is never stranded).

### Motion & feel (from apple-design / emil-design-eng)
- High-frequency actions (switching overlay type, rotate/flip) apply **instantly** — no transition on the guide drawing itself.
- Hover chrome: opacity fade only, ease-out in (~150 ms), slightly slower out. Never blocks interaction.
- Buttons: pressed state scales to 0.97 instantly on mouse-down.
- Drag/resize: strictly 1:1 with the pointer, honoring the grab offset. No spring on release — an overlay is an alignment tool; it must stop exactly where placed.
- Respect Reduce Motion (drop fades to instant) and Reduce Transparency (system handles glass).

## Architecture

```
Golden Ratio/
├── Golden_RatioApp.swift        @main; MenuBarExtra scene; owns AppModel
├── Models/
│   ├── OverlayType.swift        enum: 6 cases + display metadata
│   ├── OverlayState.swift       @Observable: type, color, rotation, flippedH/V,
│   │                            isVisible, isLocked; persistence via UserDefaults
├── Geometry/
│   └── GuideGeometry.swift      pure functions: Path builders for each guide type
│                                in a unit rect + orientation transform (rotation/flip)
├── Overlay/
│   ├── OverlayPanel.swift       NSPanel subclass: borderless, non-activating, floating
│   ├── OverlayWindowController.swift  creates/shows/hides panel, syncs with OverlayState,
│   │                            frame persistence, ignoresMouseEvents on lock
│   ├── OverlayContentView.swift SwiftUI: Canvas guide drawing + hover chrome
│   └── ResizeHandles.swift      handle layout + drag-to-resize/move logic
└── MenuPanel/
    ├── MenuPanelView.swift      tile grid, swatches, control row
    └── OverlayTileView.swift    mini guide preview tile (reuses GuideGeometry)
```

- **`OverlayState`** (@Observable, @MainActor) is the single source of truth, shared by the panel UI and the overlay window controller. Views mutate state; the controller observes and applies window-level side effects (show/hide, lock).
- **`GuideGeometry`** is pure and UI-free: `path(for: OverlayType, in: CGRect, orientation: Orientation) -> Path`. Unit-testable (Swift Testing): phi line positions, spiral rectangle subdivision, orientation-transform composition (rotate×4 ∘ flip = identity group of 8).
- **Orientation** modeled as rotation (0/90/180/270) + flipH/flipV, applied as a single CGAffineTransform to the drawing space.

## Error Handling

Essentially no failure surface: no I/O beyond UserDefaults, no network, no permissions. Defensive cases: overlay frame restored off-screen (clamp to visible screen on show); display disconnected while overlay visible (AppKit reassigns; clamp on next show).

## Testing

- **Unit (Swift Testing):** GuideGeometry path invariants (line counts, phi positions to 4 decimals, spiral bounding behavior), Orientation group composition, OverlayState persistence round-trip.
- **Manual verification:** overlay above full-screen Photomator/Preview, click-through when locked, no focus stealing while dragging, all 8 spiral orientations reachable, handles usable at min size.

## Implementation Notes

- `MenuBarExtra` with `.menuBarExtraStyle(.window)`; `Info.plist` gains `LSUIElement`.
- Remove template `ContentView.swift` / default `WindowGroup`.
- Panel: `NSPanel` with `[.borderless, .nonactivatingPanel]`, `isFloatingPanel`, `level = .floating`, `backgroundColor = .clear`, `isOpaque = false`, `hidesOnDeactivate = false`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`, content = `NSHostingView(rootView: OverlayContentView(...))`.
- Custom resize (no `.resizable` style mask) so handles + hit zones are fully ours; drag loop in SwiftUI gestures, frame math clamps to min size.
- Swift 6 language mode with strict concurrency if feasible; everything is @MainActor.
