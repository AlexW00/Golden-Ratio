# Wave 2: Chrome Polish, Liquid Glass, Welcome Window

> **For agentic workers:** executed via superpowers:subagent-driven-development. Spec deltas are inlined here; base spec: `docs/superpowers/specs/2026-07-12-golden-ratio-overlay-design.md`.

**Goal:** Address user feedback on v1: more visible overlay border, easier/hover-reactive resize grips, action-reflecting cursors, *correct* Liquid Glass usage on overlay chrome, and a minimal welcome window (first launch + Finder/Dock reopen) so a menu-bar-only app isn't confusing to open.

## Global Constraints

Same as wave 1 (macOS 26.5, sandbox on, no deps, filesystem-synchronized groups — never edit pbxproj, `-derivedDataPath build` on every xcodebuild, commits `--no-gpg-sign` with the session trailer, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` → pure value types `nonisolated`). An unrelated uncommitted `project.pbxproj` change (user's Xcode) must never be staged.

**Liquid Glass rules (from axiom-design liquid-glass docs):**
- Interactive glass controls use `.buttonStyle(.glass)` (or `.glassEffect(.regular.interactive())` for non-button interactive elements) — never plain buttons inside one static glass shape (that's the "frosted" look being replaced).
- Multiple nearby glass elements go in a `GlassEffectContainer(spacing:)`; never glass-on-glass nesting.
- Regular variant only; no `.clear`. Tint nothing (no primary action here). Accessibility (Reduce Transparency/Contrast/Motion) is automatic.
- The MenuBarExtra panel is already a system glass surface → its inner controls stay plain (glass-on-glass prohibition); only the overlay chrome and welcome CTA adopt glass styles.

---

### Task A: Overlay chrome polish + true Liquid Glass

**Files:** Modify `Golden Ratio/Overlay/OverlayContentView.swift` only.

1. **Visible frame border** — replace the single dashed stroke with a two-pass dashed border like the guides: understroke `state.color.understroke.opacity(0.5)` lineWidth 3, then `state.color.color.opacity(0.85)` lineWidth 1.5, both `StrokeStyle(dash: [6, 4])` (use `Rectangle().inset(by: 1)` + `.stroke`, or overlay two `strokeBorder`s).
2. **Grips** — diameter 10 → 12 (`.frame(width: 12, height: 12)`), edge inset 6 → 7 in `position(of:in:)`, hit shape inset -8 → -10. Per-grip hover state (`@State private var hoveredHandle: ResizeHandle?` + `.onHover` per grip): hovered grip scales 1.25 and its border ring brightens to `.white.opacity(0.9)`; animate `.easeOut(duration: 0.12)` (nil under `reduceMotion`).
3. **Cursors** (`.pointerStyle`, macOS 15+ API, fine on 26):
   - Each grip: `.pointerStyle(.frameResize(position: ...))` mapping ResizeHandle → `FrameResizePosition` (`.topLeading, .top, .topTrailing, .leading, .trailing, .bottomLeading, .bottom, .bottomTrailing`).
   - Overlay body (the move surface): `.pointerStyle(.grabIdle)` while chrome is visible (skip while locked/chrome hidden — cursor must stay default when click-through).
   - All chrome buttons (strip + close): `.pointerStyle(.link)`.
4. **True Liquid Glass chrome** — replace the current strip (plain borderless buttons inside one `.glassEffect` capsule) with `GlassEffectContainer(spacing: 8) { HStack(spacing: 8) { ... } }` where each control is its own `Button { } label: { Image(...) }.buttonStyle(.glass)`. Close button becomes `.buttonStyle(.glass)` too (drop its manual `.glassEffect`). Lock badge keeps its non-interactive `.glassEffect(.regular, in: Capsule())`. Remove the now-unneeded manual pressed-scale from chrome buttons if `.glass` provides its own interaction feedback (it does).
5. Keep: hover fade timing, NSEvent.mouseLocation gestures, accessibility labels, `.help` tooltips.

**Verify:** build clean; full unit suite green (regression only — no new unit-testable logic); headless launch/kill smoke.

### Task B: Welcome window

**Files:** Create `Golden Ratio/Welcome/WelcomeView.swift`, `Golden Ratio/Welcome/WelcomeWindowController.swift`; modify `Golden Ratio/Golden_RatioApp.swift`.

1. **WelcomeWindowController** (@MainActor, owned by AppModel): lazily creates one centered NSWindow — `[.titled, .closable, .fullSizeContentView]`, `titlebarAppearsTransparent`, `titleVisibility = .hidden`, `isMovableByWindowBackground = true`, not resizable (`styleMask` excludes `.resizable`), `isReleasedWhenClosed = false`, content = `NSHostingView(rootView: WelcomeView(dismiss:))`. `show()` centers, `NSApp.activate()`, `makeKeyAndOrderFront`. Tracks `hasShownWelcome` (UserDefaults key `"hasShownWelcome.v1"`, injectable defaults): `showIfFirstLaunch()` shows once and sets the flag.
2. **WelcomeView** — minimal, ~360×420: app icon `Image(nsImage: NSApp.applicationIconImage)` at 96pt with subtle shadow (picks up the real icon automatically once one is added), app name in `.title2.bold()`, two short lines of `.secondary` text: "Golden Ratio lives in your menu bar." / "Click the ✱ spiral icon to place a composition overlay on your screen." (use `Image(systemName: "hurricane")` inline via `Label`/text interpolation), then a `Button("Got It")` with `.buttonStyle(.glassProminent)` + `.keyboardShortcut(.defaultAction)` that closes the window. Generous whitespace, no headers, no settings.
3. **App wiring** — `AppModel` gains `let welcomeController: WelcomeWindowController`. Add an `NSApplicationDelegateAdaptor` AppDelegate: `applicationDidFinishLaunching` → `model.welcomeController.showIfFirstLaunch()`; `applicationShouldHandleReopen(_:hasVisibleWindows:)` → `welcomeController.show()`, return true (this is the Finder/Dock double-click-while-running path). Wire the delegate to the model (static/shared hook or assign in AppModel init — keep it simple and documented).
4. **Unit tests** (Golden RatioTests/WelcomeTests.swift): `showIfFirstLaunch` sets the flag in an injected fresh defaults suite and reports it would show exactly once (test the flag logic, not the window: expose a small pure decision, e.g. `shouldShowOnLaunch` reads+flips the flag; keep NSWindow creation lazy so the test can run without ordering a window — or test via a `dryRun` seam. Simplest: test a `static func consumeFirstLaunch(defaults:) -> Bool` pure-ish helper used by showIfFirstLaunch).

**Verify:** build clean; suite green incl. new test; headless smoke: launch → window should appear on first launch (fresh container flag) — verify `pgrep` alive; screenshot verification by controller.

### Review & wrap-up

Per-task review after each; controller runs visual verification (screenshots of chrome hover state can't be captured headlessly — border/glass/welcome verified via screenshot, hover/cursor by the user); commit docs; user decides merge timing.
