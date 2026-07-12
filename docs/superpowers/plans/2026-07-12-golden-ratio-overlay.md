# Golden Ratio Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menu-bar-only macOS app that shows one resizable, movable, rotatable/flippable composition-guide overlay (6 types) floating above all apps, with a lock/click-through mode.

**Architecture:** SwiftUI `MenuBarExtra` (window style) for the control panel + a non-activating borderless `NSPanel` hosting SwiftUI content for the overlay. One shared `@MainActor @Observable OverlayState` is the single source of truth; `OverlayWindowController` observes it and applies window-level side effects. All guide drawing goes through pure, unit-tested `GuideGeometry` path builders.

**Tech Stack:** Swift, SwiftUI, AppKit (NSPanel), Swift Testing (unit tests), UserDefaults persistence. No third-party dependencies.

**Spec:** `docs/superpowers/specs/2026-07-12-golden-ratio-overlay-design.md`

## Global Constraints

- Deployment target macOS 26.5; build with the installed Xcode 26. Liquid Glass via `.glassEffect` is available unconditionally (no availability gates needed).
- App Sandbox stays enabled; the app must require **zero** permissions (no screen capture, no accessibility API, no synthetic input).
- Menu-bar-only: `INFOPLIST_KEY_LSUIElement = YES` (Info.plist is generated — this is a build setting).
- No new dependencies, no SPM packages.
- The Xcode project uses **filesystem-synchronized groups** (`objectVersion = 77`): creating a file under `Golden Ratio/` or `Golden RatioTests/` automatically adds it to the respective target. Never edit `project.pbxproj` to add files (only Task 1 touches it, for one build setting).
- Unit tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`), live in `Golden RatioTests/`, and import the app with `@testable import Golden_Ratio`.
- Test command (unit tests only, skips UI tests):
  `xcodebuild test -project "Golden Ratio.xcodeproj" -scheme "Golden Ratio" -destination 'platform=macOS' -only-testing:"Golden RatioTests" -quiet`
- Build command:
  `xcodebuild build -project "Golden Ratio.xcodeproj" -scheme "Golden Ratio" -configuration Debug -quiet`
- Motion rules (from spec): no animation on guide-type switches or rotate/flip; hover chrome fades ~150 ms ease-out in / 200 ms out; drags track 1:1; respect `accessibilityReduceMotion` (fades become instant).
- Everything UI-facing is `@MainActor`. Do not introduce other isolation domains.
- Commit after every task with the trailer:
  `Claude-Session: https://claude.ai/code/session_013MWRUVUp6BnjFdQxS4PjBd`

## File Structure (end state)

```
Golden Ratio/
├── Golden_RatioApp.swift            @main, MenuBarExtra scene, AppModel
├── Models/
│   ├── OverlayType.swift            6 guide types + display names
│   ├── Orientation.swift            dihedral-8 orientation (rotation + flips)
│   └── OverlayState.swift           @Observable source of truth + GuideColor + persistence
├── Geometry/
│   ├── GuideGeometry.swift          pure Path builders per guide type
│   └── OverlayFrameMath.swift       ResizeHandle + pure frame math for move/resize
├── Overlay/
│   ├── OverlayPanel.swift           NSPanel subclass + hosting view
│   ├── OverlayWindowController.swift panel lifecycle, observation, lock, clamping
│   └── OverlayContentView.swift     Canvas guide drawing + hover chrome + drag logic
└── MenuPanel/
    └── MenuPanelView.swift          tile grid, swatches, control row (incl. tile subview)
Golden RatioTests/
├── OrientationTests.swift
├── GuideGeometryTests.swift
├── OverlayStateTests.swift
└── OverlayFrameMathTests.swift
```

---

### Task 1: App shell — menu-bar-only skeleton

**Files:**
- Modify: `Golden Ratio/Golden_RatioApp.swift`
- Delete: `Golden Ratio/ContentView.swift`
- Modify: `Golden Ratio.xcodeproj/project.pbxproj` (one build setting, both app configs)

**Interfaces:**
- Consumes: nothing.
- Produces: `@main struct Golden_RatioApp` with a `MenuBarExtra` scene whose content is a placeholder `Text`. Later tasks replace the placeholder with `MenuPanelView` and add `AppModel`.

- [ ] **Step 1: Replace the app entry point**

Replace the entire contents of `Golden Ratio/Golden_RatioApp.swift` with:

```swift
import SwiftUI

@main
struct Golden_RatioApp: App {
    var body: some Scene {
        MenuBarExtra("Golden Ratio", systemImage: "hurricane") {
            Text("Golden Ratio")
                .padding()
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 2: Delete the template ContentView**

```bash
rm "Golden Ratio/ContentView.swift"
```

(Synchronized groups: no project-file edit needed.)

- [ ] **Step 3: Make the app menu-bar-only**

In `Golden Ratio.xcodeproj/project.pbxproj`, find the **two** build-configuration blocks (Debug and Release) that contain `PRODUCT_BUNDLE_IDENTIFIER = "com.weichart.Golden-Ratio";` and in each, add this line directly after `GENERATE_INFOPLIST_FILE = YES;`:

```
				INFOPLIST_KEY_LSUIElement = YES;
```

(Tab-indented like its neighbors. Do NOT touch the Tests/UITests configurations.)

- [ ] **Step 4: Build**

Run: `xcodebuild build -project "Golden Ratio.xcodeproj" -scheme "Golden Ratio" -configuration Debug -quiet`
Expected: succeeds with no errors.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: menu-bar-only app shell with MenuBarExtra"
```

---

### Task 2: Orientation + OverlayType models

**Files:**
- Create: `Golden Ratio/Models/OverlayType.swift`
- Create: `Golden Ratio/Models/Orientation.swift`
- Test: `Golden RatioTests/OrientationTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum OverlayType: String, Codable, CaseIterable, Identifiable, Sendable` — cases `thirds, phiGrid, goldenSpiral, diagonals, harmonicArmature, centerCross`; `var id: String`; `var displayName: String`.
  - `struct Orientation: Codable, Equatable, Sendable` — `var quarterTurns: Int` (0...3), `var flippedH: Bool`, `var flippedV: Bool`; `static let identity: Orientation`; `mutating func rotate90()`, `mutating func flipHorizontal()`, `mutating func flipVertical()`; `func transform(in rect: CGRect) -> CGAffineTransform`.

Semantics: the stored form is canonical — the drawing transform applies flipH, then flipV, then `quarterTurns` × 90° clockwise, all in the rect's own space (a non-square rect maps onto itself; content stretches). User-facing ops compose **on top of** what's on screen, which is why `flipHorizontal()` toggles `flippedV` when the current rotation is odd (dihedral-group conjugation).

- [ ] **Step 1: Write the failing tests**

Create `Golden RatioTests/OrientationTests.swift`:

```swift
import Testing
import CoreGraphics
@testable import Golden_Ratio

struct OrientationTests {
    let rect = CGRect(x: 0, y: 0, width: 200, height: 100)

    private func apply(_ o: Orientation, _ p: CGPoint) -> CGPoint {
        p.applying(o.transform(in: rect))
    }

    @Test func identityLeavesPointsAlone() {
        let p = CGPoint(x: 50, y: 25)
        #expect(apply(.identity, p) == p)
    }

    @Test func rotate90MapsTopLeftToTopRight() {
        var o = Orientation.identity
        o.rotate90()
        // unit-space (0,0) -> (1,0): rect top-left -> top-right
        let mapped = apply(o, CGPoint(x: 0, y: 0))
        #expect(abs(mapped.x - 200) < 0.001 && abs(mapped.y - 0) < 0.001)
    }

    @Test func fourRotationsAreIdentity() {
        var o = Orientation.identity
        for _ in 0..<4 { o.rotate90() }
        #expect(o == .identity)
    }

    @Test func doubleFlipsAreIdentity() {
        var o = Orientation.identity
        o.flipHorizontal(); o.flipHorizontal()
        #expect(o == .identity)
        o.flipVertical(); o.flipVertical()
        #expect(o == .identity)
    }

    @Test func flipHorizontalMirrorsX() {
        var o = Orientation.identity
        o.flipHorizontal()
        let mapped = apply(o, CGPoint(x: 0, y: 25))
        #expect(abs(mapped.x - 200) < 0.001 && abs(mapped.y - 25) < 0.001)
    }

    @Test func flipAfterRotationMirrorsOnScreen() {
        // Rotate 90, then user flips horizontally: the ON-SCREEN result must be
        // a horizontal mirror of the rotated image.
        var o = Orientation.identity
        o.rotate90()
        o.flipHorizontal()
        // Compose expectations in unit space: R(x,y)=(1-y,x); FH(x,y)=(1-x,y)
        // FH(R(0,0)) = FH(1,0) = (0,0) -> rect (0,0)
        let mapped = apply(o, CGPoint(x: 0, y: 0))
        #expect(abs(mapped.x - 0) < 0.001 && abs(mapped.y - 0) < 0.001)
    }

    @Test func allEightOrientationsMapCornersToCorners() {
        let corners = [
            CGPoint(x: 0, y: 0), CGPoint(x: 200, y: 0),
            CGPoint(x: 0, y: 100), CGPoint(x: 200, y: 100),
        ]
        var seen: Set<String> = []
        for turns in 0..<4 {
            for flip in [false, true] {
                var o = Orientation.identity
                for _ in 0..<turns { o.rotate90() }
                if flip { o.flipHorizontal() }
                seen.insert("\(o.quarterTurns)-\(o.flippedH)-\(o.flippedV)")
                for c in corners {
                    let m = apply(o, c)
                    let isCorner = corners.contains {
                        abs($0.x - m.x) < 0.001 && abs($0.y - m.y) < 0.001
                    }
                    #expect(isCorner, "orientation \(o) maps corner \(c) to non-corner \(m)")
                }
            }
        }
        #expect(seen.count == 8)  // the full dihedral group is reachable
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project "Golden Ratio.xcodeproj" -scheme "Golden Ratio" -destination 'platform=macOS' -only-testing:"Golden RatioTests" -quiet`
Expected: FAIL — `Orientation` / `OverlayType` not found.

- [ ] **Step 3: Implement the models**

Create `Golden Ratio/Models/OverlayType.swift`:

```swift
import Foundation

enum OverlayType: String, Codable, CaseIterable, Identifiable, Sendable {
    case thirds
    case phiGrid
    case goldenSpiral
    case diagonals
    case harmonicArmature
    case centerCross

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .thirds: "Rule of Thirds"
        case .phiGrid: "Phi Grid"
        case .goldenSpiral: "Golden Spiral"
        case .diagonals: "Golden Diagonals"
        case .harmonicArmature: "Harmonic Armature"
        case .centerCross: "Center Cross"
        }
    }
}
```

Create `Golden Ratio/Models/Orientation.swift`:

```swift
import CoreGraphics

/// One of the 8 dihedral orientations of a rectangle: flips applied first,
/// then `quarterTurns` × 90° clockwise. All in the rect's own (stretching) space.
struct Orientation: Codable, Equatable, Sendable {
    var quarterTurns: Int = 0  // 0...3, clockwise
    var flippedH: Bool = false
    var flippedV: Bool = false

    static let identity = Orientation()

    mutating func rotate90() {
        quarterTurns = (quarterTurns + 1) % 4
    }

    /// Mirrors the current on-screen image horizontally. Because the canonical
    /// form applies flips before rotation, a screen-space horizontal flip lands
    /// on the vertical stored flag when the rotation is odd.
    mutating func flipHorizontal() {
        if quarterTurns.isMultiple(of: 2) { flippedH.toggle() } else { flippedV.toggle() }
    }

    mutating func flipVertical() {
        if quarterTurns.isMultiple(of: 2) { flippedV.toggle() } else { flippedH.toggle() }
    }

    /// Maps `rect` onto itself with this orientation (content stretches).
    func transform(in rect: CGRect) -> CGAffineTransform {
        // Unit-space primitives (y down, unit square):
        let flipH = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 1, ty: 0)   // (x,y)->(1-x,y)
        let flipV = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 1)   // (x,y)->(x,1-y)
        let rot90 = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1, ty: 0)   // (x,y)->(1-y,x)

        var unit = CGAffineTransform.identity
        if flippedH { unit = unit.concatenating(flipH) }
        if flippedV { unit = unit.concatenating(flipV) }
        for _ in 0..<quarterTurns { unit = unit.concatenating(rot90) }

        let toUnit = CGAffineTransform(translationX: -rect.minX, y: -rect.minY)
            .concatenating(CGAffineTransform(scaleX: 1 / rect.width, y: 1 / rect.height))
        let fromUnit = CGAffineTransform(scaleX: rect.width, y: rect.height)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))
        return toUnit.concatenating(unit).concatenating(fromUnit)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project "Golden Ratio.xcodeproj" -scheme "Golden Ratio" -destination 'platform=macOS' -only-testing:"Golden RatioTests" -quiet`
Expected: PASS (all OrientationTests).

- [ ] **Step 5: Commit**

```bash
git add "Golden Ratio/Models" "Golden RatioTests/OrientationTests.swift"
git commit -m "feat: OverlayType and dihedral Orientation models"
```

---

### Task 3: GuideGeometry — pure path builders

**Files:**
- Create: `Golden Ratio/Geometry/GuideGeometry.swift`
- Test: `Golden RatioTests/GuideGeometryTests.swift`

**Interfaces:**
- Consumes: `OverlayType`, `Orientation` (Task 2).
- Produces: `enum GuideGeometry` with:
  - `static let phi: CGFloat` (≈ 1.618034), `static let invPhiSquared: CGFloat` (≈ 0.381966)
  - `static func path(for type: OverlayType, in rect: CGRect, orientation: Orientation) -> Path`

- [ ] **Step 1: Write the failing tests**

Create `Golden RatioTests/GuideGeometryTests.swift`:

```swift
import Testing
import SwiftUI
@testable import Golden_Ratio

struct GuideGeometryTests {
    let rect = CGRect(x: 0, y: 0, width: 300, height: 200)

    @Test func phiConstants() {
        #expect(abs(GuideGeometry.phi - 1.6180) < 0.0001)
        #expect(abs(GuideGeometry.invPhiSquared - 0.3820) < 0.0001)
    }

    @Test func thirdsGridLinesAtThirds() {
        let path = GuideGeometry.path(for: .thirds, in: rect, orientation: .identity)
        let b = path.boundingRect
        // Grid lines span the rect
        #expect(abs(b.minX - 0) < 0.5 && abs(b.maxX - 300) < 0.5)
        // Verify line positions via the path's move elements
        var xs: Set<Int> = []
        path.forEach { element in
            if case .move(let to) = element { xs.insert(Int(to.x.rounded())) }
        }
        #expect(xs.contains(100) && xs.contains(200))
    }

    @Test func phiGridLinesAtGoldenPositions() {
        let path = GuideGeometry.path(for: .phiGrid, in: rect, orientation: .identity)
        var xs: Set<Int> = []
        path.forEach { element in
            if case .move(let to) = element { xs.insert(Int(to.x.rounded())) }
        }
        // 300 * 0.381966 ≈ 115, 300 * 0.618034 ≈ 185
        #expect(xs.contains(115) && xs.contains(185))
    }

    @Test func spiralStaysInsideRect() {
        let path = GuideGeometry.path(for: .goldenSpiral, in: rect, orientation: .identity)
        let b = path.boundingRect
        // A correctly-wound spiral (minor arcs) never leaves the rect.
        // If the arc `clockwise` flag is wrong, the bounding rect balloons far outside.
        #expect(b.minX > -1 && b.minY > -1 && b.maxX < 301 && b.maxY < 201)
        #expect(!path.isEmpty)
    }

    @Test func armatureHasFourteenSegments() {
        let path = GuideGeometry.path(for: .harmonicArmature, in: rect, orientation: .identity)
        var moves = 0
        path.forEach { if case .move = $0 { moves += 1 } }
        #expect(moves == 14)
    }

    @Test func diagonalsHasSixSegments() {
        let path = GuideGeometry.path(for: .diagonals, in: rect, orientation: .identity)
        var moves = 0
        path.forEach { if case .move = $0 { moves += 1 } }
        #expect(moves == 6)
    }

    @Test func reciprocalFootIsPerpendicular() {
        // Foot of perpendicular from top-right corner onto the TL->BR diagonal.
        let p = GuideGeometry.foot(
            of: CGPoint(x: 300, y: 0),
            onLineFrom: CGPoint(x: 0, y: 0),
            to: CGPoint(x: 300, y: 200)
        )
        // Dot product of (foot - corner) and diagonal direction must be 0.
        let v = CGPoint(x: p.x - 300, y: p.y - 0)
        let d = CGPoint(x: 300, y: 200)
        #expect(abs(v.x * d.x + v.y * d.y) < 0.01)
    }

    @Test func orientationRotatesGuide() {
        var o = Orientation.identity
        o.rotate90()
        let path = GuideGeometry.path(for: .phiGrid, in: rect, orientation: o)
        // After 90° rotation, the golden verticals become horizontals:
        // 200 * 0.381966 ≈ 76, 200 * 0.618034 ≈ 124
        var ys: Set<Int> = []
        path.forEach { element in
            if case .move(let to) = element { ys.insert(Int(to.y.rounded())) }
        }
        #expect(ys.contains(76) && ys.contains(124))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project "Golden Ratio.xcodeproj" -scheme "Golden Ratio" -destination 'platform=macOS' -only-testing:"Golden RatioTests" -quiet`
Expected: FAIL — `GuideGeometry` not found.

- [ ] **Step 3: Implement GuideGeometry**

Create `Golden Ratio/Geometry/GuideGeometry.swift`:

```swift
import SwiftUI

/// Pure geometry for all guide types. No state, no UI — fully unit-testable.
enum GuideGeometry {
    static let phi: CGFloat = (1 + sqrt(5)) / 2
    static let invPhiSquared: CGFloat = 1 / (phi * phi)  // ≈ 0.381966

    static func path(for type: OverlayType, in rect: CGRect, orientation: Orientation) -> Path {
        let raw: Path
        switch type {
        case .thirds:
            raw = grid(in: rect, fractions: [1.0 / 3.0, 2.0 / 3.0])
        case .phiGrid:
            raw = grid(in: rect, fractions: [invPhiSquared, 1 - invPhiSquared])
        case .goldenSpiral:
            raw = spiral(in: rect)
        case .diagonals:
            raw = diagonals(in: rect)
        case .harmonicArmature:
            raw = armature(in: rect)
        case .centerCross:
            raw = centerCross(in: rect)
        }
        return raw.applying(orientation.transform(in: rect))
    }

    // MARK: - Builders

    private static func grid(in rect: CGRect, fractions: [CGFloat]) -> Path {
        var p = Path()
        for f in fractions {
            let x = rect.minX + rect.width * f
            p.move(to: CGPoint(x: x, y: rect.minY))
            p.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        for f in fractions {
            let y = rect.minY + rect.height * f
            p.move(to: CGPoint(x: rect.minX, y: y))
            p.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return p
    }

    /// Golden spiral built in a φ:1 rect, then stretched to `rect`.
    /// Cuts squares left → top → right → bottom, adding the square outlines
    /// and a quarter arc per square. 8 windings.
    private static func spiral(in rect: CGRect) -> Path {
        var p = Path()
        var r = CGRect(x: 0, y: 0, width: phi, height: 1)
        for i in 0..<8 {
            let s = min(r.width, r.height)
            let square: CGRect
            let center: CGPoint
            switch i % 4 {
            case 0:  // cut from left
                square = CGRect(x: r.minX, y: r.minY, width: s, height: s)
                r = CGRect(x: r.minX + s, y: r.minY, width: r.width - s, height: r.height)
                center = CGPoint(x: square.maxX, y: square.maxY)
            case 1:  // cut from top
                square = CGRect(x: r.maxX - s, y: r.minY, width: s, height: s)
                r = CGRect(x: r.minX, y: r.minY + s, width: r.width, height: r.height - s)
                center = CGPoint(x: square.minX, y: square.maxY)
            case 2:  // cut from right
                square = CGRect(x: r.maxX - s, y: r.maxY - s, width: s, height: s)
                r = CGRect(x: r.minX, y: r.minY, width: r.width - s, height: r.height)
                center = CGPoint(x: square.minX, y: square.minY)
            default:  // cut from bottom
                square = CGRect(x: r.minX, y: r.maxY - s, width: s, height: s)
                r = CGRect(x: r.minX, y: r.minY, width: r.width, height: r.height - s)
                center = CGPoint(x: square.maxX, y: square.minY)
            }
            p.addRect(square)
            // Quarter arcs chain: 180→270, 270→360, 0→90, 90→180, …
            // NOTE: if the spiral visually bulges outward past the rect, flip
            // `clockwise` — SwiftUI's flipped coordinates invert the flag's meaning.
            // The spiralStaysInsideRect test catches the wrong choice.
            p.move(to: CGPoint(
                x: center.x + s * cos(CGFloat(180 + 90 * i) * .pi / 180),
                y: center.y + s * sin(CGFloat(180 + 90 * i) * .pi / 180)
            ))
            p.addArc(
                center: center,
                radius: s,
                startAngle: .degrees(Double(180 + 90 * i)),
                endAngle: .degrees(Double(270 + 90 * i)),
                clockwise: false
            )
        }
        let stretch = CGAffineTransform(scaleX: rect.width / phi, y: rect.height)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))
        return p.applying(stretch)
    }

    /// 2 main diagonals + 4 reciprocals (perpendicular from each corner onto
    /// the opposite diagonal). Computed in real rect space so the reciprocals
    /// are true perpendiculars for the current aspect ratio.
    private static func diagonals(in rect: CGRect) -> Path {
        let tl = CGPoint(x: rect.minX, y: rect.minY)
        let tr = CGPoint(x: rect.maxX, y: rect.minY)
        let bl = CGPoint(x: rect.minX, y: rect.maxY)
        let br = CGPoint(x: rect.maxX, y: rect.maxY)
        var p = Path()
        p.move(to: tl); p.addLine(to: br)
        p.move(to: tr); p.addLine(to: bl)
        for (corner, a, b) in [(tr, tl, br), (bl, tl, br), (tl, tr, bl), (br, tr, bl)] {
            p.move(to: corner)
            p.addLine(to: foot(of: corner, onLineFrom: a, to: b))
        }
        return p
    }

    /// Foot of the perpendicular from `p` onto the infinite line a→b.
    /// Internal (not private) for unit testing.
    static func foot(of p: CGPoint, onLineFrom a: CGPoint, to b: CGPoint) -> CGPoint {
        let dx = b.x - a.x, dy = b.y - a.y
        let t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / (dx * dx + dy * dy)
        return CGPoint(x: a.x + t * dx, y: a.y + t * dy)
    }

    /// Classic 14-line harmonic armature: 2 diagonals, 8 corner→far-side-midpoint
    /// lines, 4 midpoint-rhombus sides.
    private static func armature(in rect: CGRect) -> Path {
        let tl = CGPoint(x: rect.minX, y: rect.minY)
        let tr = CGPoint(x: rect.maxX, y: rect.minY)
        let bl = CGPoint(x: rect.minX, y: rect.maxY)
        let br = CGPoint(x: rect.maxX, y: rect.maxY)
        let mT = CGPoint(x: rect.midX, y: rect.minY)
        let mB = CGPoint(x: rect.midX, y: rect.maxY)
        let mL = CGPoint(x: rect.minX, y: rect.midY)
        let mR = CGPoint(x: rect.maxX, y: rect.midY)
        var p = Path()
        let segments: [(CGPoint, CGPoint)] = [
            (tl, br), (tr, bl),                          // diagonals
            (tl, mR), (tl, mB), (tr, mL), (tr, mB),      // corner → far midpoints
            (bl, mR), (bl, mT), (br, mL), (br, mT),
            (mT, mR), (mR, mB), (mB, mL), (mL, mT),      // midpoint rhombus
        ]
        for (a, b) in segments {
            p.move(to: a); p.addLine(to: b)
        }
        return p
    }

    private static func centerCross(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project "Golden Ratio.xcodeproj" -scheme "Golden Ratio" -destination 'platform=macOS' -only-testing:"Golden RatioTests" -quiet`
Expected: PASS. If `spiralStaysInsideRect` fails with a huge bounding rect, flip the `clockwise:` flag in `spiral(in:)` as noted in the code comment and re-run.

- [ ] **Step 5: Commit**

```bash
git add "Golden Ratio/Geometry/GuideGeometry.swift" "Golden RatioTests/GuideGeometryTests.swift"
git commit -m "feat: pure GuideGeometry path builders for all six guide types"
```

---

### Task 4: OverlayState + persistence

**Files:**
- Create: `Golden Ratio/Models/OverlayState.swift`
- Test: `Golden RatioTests/OverlayStateTests.swift`

**Interfaces:**
- Consumes: `OverlayType`, `Orientation` (Task 2).
- Produces:
  - `enum GuideColor: String, Codable, CaseIterable, Identifiable, Sendable` — cases `gold, white, black, red, blue, green`; `var id: String`; `var color: Color`; `var displayName: String`.
  - `@MainActor @Observable final class OverlayState` — `var type: OverlayType`, `var color: GuideColor`, `var orientation: Orientation`, `var isVisible: Bool`, `var isLocked: Bool`; `init(defaults: UserDefaults = .standard)`. Every property change persists immediately. On init, state restores from defaults **except** `isLocked`, which always restores as `false` (never strand the user in a locked overlay).

- [ ] **Step 1: Write the failing tests**

Create `Golden RatioTests/OverlayStateTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project "Golden Ratio.xcodeproj" -scheme "Golden Ratio" -destination 'platform=macOS' -only-testing:"Golden RatioTests" -quiet`
Expected: FAIL — `OverlayState` not found.

- [ ] **Step 3: Implement OverlayState**

Create `Golden Ratio/Models/OverlayState.swift`:

```swift
import SwiftUI
import Observation

enum GuideColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case gold, white, black, red, blue, green

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .gold: Color(red: 1.00, green: 0.72, blue: 0.00)
        case .white: .white
        case .black: .black
        case .red: Color(red: 0.96, green: 0.26, blue: 0.21)
        case .blue: Color(red: 0.04, green: 0.52, blue: 1.00)
        case .green: Color(red: 0.20, green: 0.78, blue: 0.35)
        }
    }

    var displayName: String { rawValue.capitalized }
}

/// Single source of truth shared by the menu panel and the overlay window.
@MainActor
@Observable
final class OverlayState {
    var type: OverlayType { didSet { save() } }
    var color: GuideColor { didSet { save() } }
    var orientation: Orientation { didSet { save() } }
    var isVisible: Bool { didSet { save() } }
    /// Not persisted as `true`: a relaunch always starts unlocked so the user
    /// is never stranded with an untouchable overlay.
    var isLocked: Bool = false

    private let defaults: UserDefaults
    private static let key = "overlayState.v1"

    private struct Snapshot: Codable {
        var type: OverlayType
        var color: GuideColor
        var orientation: Orientation
        var isVisible: Bool
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            type = snap.type
            color = snap.color
            orientation = snap.orientation
            isVisible = snap.isVisible
        } else {
            type = .thirds
            color = .gold
            orientation = .identity
            isVisible = false
        }
    }

    private func save() {
        let snap = Snapshot(type: type, color: color, orientation: orientation, isVisible: isVisible)
        if let data = try? JSONEncoder().encode(snap) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project "Golden Ratio.xcodeproj" -scheme "Golden Ratio" -destination 'platform=macOS' -only-testing:"Golden RatioTests" -quiet`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add "Golden Ratio/Models/OverlayState.swift" "Golden RatioTests/OverlayStateTests.swift"
git commit -m "feat: observable OverlayState with UserDefaults persistence"
```

---

### Task 5: OverlayFrameMath — pure move/resize math

**Files:**
- Create: `Golden Ratio/Geometry/OverlayFrameMath.swift`
- Test: `Golden RatioTests/OverlayFrameMathTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum ResizeHandle: CaseIterable, Sendable` — cases `topLeft, top, topRight, left, right, bottomLeft, bottom, bottomRight`.
  - `enum OverlayFrameMath` — `static let minSize: CGFloat` (120); `static func frame(after handle: ResizeHandle, translation: CGSize, initial: CGRect) -> CGRect` (AppKit y-up frames; `translation` is SwiftUI view-space, y-down); `static func moved(from initial: CGRect, translation: CGSize) -> CGRect`; `static func clamped(_ frame: CGRect, to visible: CGRect) -> CGRect`.

Coordinate convention (critical): window frames are AppKit **y-up** (origin bottom-left of screen); SwiftUI gesture translations are **y-down**. All conversion happens inside these functions — callers pass raw gesture translations.

- [ ] **Step 1: Write the failing tests**

Create `Golden RatioTests/OverlayFrameMathTests.swift`:

```swift
import Testing
import CoreGraphics
@testable import Golden_Ratio

struct OverlayFrameMathTests {
    // AppKit y-up frame: origin is BOTTOM-left.
    let initial = CGRect(x: 100, y: 100, width: 400, height: 300)

    @Test func moveConvertsYDownToYUp() {
        // Dragging 10 right, 20 down (view space) moves origin +10, -20 (AppKit).
        let f = OverlayFrameMath.moved(from: initial, translation: CGSize(width: 10, height: 20))
        #expect(f == CGRect(x: 110, y: 80, width: 400, height: 300))
    }

    @Test func rightHandleGrowsWidth() {
        let f = OverlayFrameMath.frame(after: .right, translation: CGSize(width: 50, height: 0), initial: initial)
        #expect(f == CGRect(x: 100, y: 100, width: 450, height: 300))
    }

    @Test func leftHandleMovesOriginAndShrinksWidth() {
        let f = OverlayFrameMath.frame(after: .left, translation: CGSize(width: 50, height: 0), initial: initial)
        #expect(f == CGRect(x: 150, y: 100, width: 350, height: 300))
    }

    @Test func topHandleDraggedUpGrowsHeight() {
        // Top edge in view space = high y in AppKit. Dragging up = negative view dy.
        let f = OverlayFrameMath.frame(after: .top, translation: CGSize(width: 0, height: -40), initial: initial)
        #expect(f == CGRect(x: 100, y: 100, width: 400, height: 340))
    }

    @Test func bottomHandleDraggedDownGrowsHeightAndLowersOrigin() {
        let f = OverlayFrameMath.frame(after: .bottom, translation: CGSize(width: 0, height: 40), initial: initial)
        #expect(f == CGRect(x: 100, y: 60, width: 400, height: 340))
    }

    @Test func cornerHandleResizesBothAxes() {
        let f = OverlayFrameMath.frame(after: .bottomRight, translation: CGSize(width: 30, height: 40), initial: initial)
        #expect(f == CGRect(x: 100, y: 60, width: 430, height: 340))
    }

    @Test func resizeClampsToMinSize() {
        let f = OverlayFrameMath.frame(after: .right, translation: CGSize(width: -1000, height: 0), initial: initial)
        #expect(f.width == OverlayFrameMath.minSize)
        let f2 = OverlayFrameMath.frame(after: .left, translation: CGSize(width: 1000, height: 0), initial: initial)
        #expect(f2.width == OverlayFrameMath.minSize)
        #expect(f2.maxX == initial.maxX)  // right edge stays anchored
    }

    @Test func clampBringsOffscreenFrameBack() {
        let visible = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let off = CGRect(x: 2000, y: -500, width: 400, height: 300)
        let f = OverlayFrameMath.clamped(off, to: visible)
        #expect(visible.intersects(f))
        #expect(f.width == 400 && f.height == 300)
        // Fully inside:
        #expect(f.minX >= 0 && f.minY >= 0 && f.maxX <= 1920 && f.maxY <= 1080)
    }

    @Test func clampShrinksFrameLargerThanScreen() {
        let visible = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let huge = CGRect(x: 0, y: 0, width: 3000, height: 2000)
        let f = OverlayFrameMath.clamped(huge, to: visible)
        #expect(f.width <= 1920 && f.height <= 1080)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project "Golden Ratio.xcodeproj" -scheme "Golden Ratio" -destination 'platform=macOS' -only-testing:"Golden RatioTests" -quiet`
Expected: FAIL — `OverlayFrameMath` not found.

- [ ] **Step 3: Implement OverlayFrameMath**

Create `Golden Ratio/Geometry/OverlayFrameMath.swift`:

```swift
import CoreGraphics

enum ResizeHandle: CaseIterable, Sendable {
    case topLeft, top, topRight, left, right, bottomLeft, bottom, bottomRight
}

/// Pure frame math for the overlay panel. Frames are AppKit y-up;
/// `translation` values are SwiftUI view-space (y-down). Conversion is internal.
enum OverlayFrameMath {
    static let minSize: CGFloat = 120

    static func moved(from initial: CGRect, translation: CGSize) -> CGRect {
        CGRect(
            x: initial.origin.x + translation.width,
            y: initial.origin.y - translation.height,
            width: initial.width,
            height: initial.height
        )
    }

    static func frame(after handle: ResizeHandle, translation: CGSize, initial: CGRect) -> CGRect {
        let dx = translation.width
        let dy = -translation.height  // to AppKit y-up
        var f = initial

        func dragLeftEdge() {
            let newMinX = min(initial.minX + dx, initial.maxX - minSize)
            f.origin.x = newMinX
            f.size.width = initial.maxX - newMinX
        }
        func dragRightEdge() {
            f.size.width = max(initial.width + dx, minSize)
        }
        func dragTopEdge() {  // view-space top = AppKit maxY
            f.size.height = max(initial.height + dy, minSize)
        }
        func dragBottomEdge() {  // view-space bottom = AppKit minY
            let newMinY = min(initial.minY + dy, initial.maxY - minSize)
            f.origin.y = newMinY
            f.size.height = initial.maxY - newMinY
        }

        switch handle {
        case .topLeft: dragLeftEdge(); dragTopEdge()
        case .top: dragTopEdge()
        case .topRight: dragRightEdge(); dragTopEdge()
        case .left: dragLeftEdge()
        case .right: dragRightEdge()
        case .bottomLeft: dragLeftEdge(); dragBottomEdge()
        case .bottom: dragBottomEdge()
        case .bottomRight: dragRightEdge(); dragBottomEdge()
        }
        return f
    }

    /// Returns `frame` adjusted to lie fully inside `visible`, shrinking if needed.
    static func clamped(_ frame: CGRect, to visible: CGRect) -> CGRect {
        var f = frame
        f.size.width = min(f.width, visible.width)
        f.size.height = min(f.height, visible.height)
        f.origin.x = min(max(f.origin.x, visible.minX), visible.maxX - f.width)
        f.origin.y = min(max(f.origin.y, visible.minY), visible.maxY - f.height)
        return f
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project "Golden Ratio.xcodeproj" -scheme "Golden Ratio" -destination 'platform=macOS' -only-testing:"Golden RatioTests" -quiet`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add "Golden Ratio/Geometry/OverlayFrameMath.swift" "Golden RatioTests/OverlayFrameMathTests.swift"
git commit -m "feat: pure overlay frame math for move, resize, and screen clamping"
```

---

### Task 6: OverlayPanel + OverlayWindowController

**Files:**
- Create: `Golden Ratio/Overlay/OverlayPanel.swift`
- Create: `Golden Ratio/Overlay/OverlayWindowController.swift`
- Create: `Golden Ratio/Overlay/OverlayContentView.swift` (stub — full version in Task 7)

**Interfaces:**
- Consumes: `OverlayState` (Task 4), `OverlayFrameMath.clamped` (Task 5).
- Produces:
  - `final class OverlayPanel: NSPanel` — `init()` configures borderless/non-activating/floating/all-Spaces; `canBecomeKey`/`canBecomeMain` are `false`.
  - `final class OverlayHostingView<Content: View>: NSHostingView<Content>` — accepts first mouse.
  - `@MainActor final class OverlayWindowController` — `init(state: OverlayState)`; observes `state.isVisible` / `state.isLocked` via `withObservationTracking` and shows/hides the panel, toggles `ignoresMouseEvents`, clamps the restored frame to the visible screen; `var panel: OverlayPanel?` (internal, read by OverlayContentView drags in Task 7).
  - `struct OverlayContentView: View` — `init(state: OverlayState, controller: OverlayWindowController)` (stub body for now).

No unit tests for this task (window plumbing); verification is a build + a scripted smoke run. Panel configuration correctness is asserted in Task 8's manual checklist.

- [ ] **Step 1: Create OverlayPanel**

Create `Golden Ratio/Overlay/OverlayPanel.swift`:

```swift
import AppKit
import SwiftUI

/// Borderless, non-activating floating panel that carries the overlay.
/// Never becomes key or main, so clicks on it don't steal focus from the
/// app being composed (e.g. Photomator).
final class OverlayPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 200, y: 200, width: 480, height: 320),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = false  // we implement dragging ourselves
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Hosting view that responds to the first click even though the panel
/// never becomes key.
final class OverlayHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
```

- [ ] **Step 2: Create the OverlayContentView stub**

Create `Golden Ratio/Overlay/OverlayContentView.swift`:

```swift
import SwiftUI

/// Guide drawing + interactive chrome. Task 7 fills this in; this stub
/// only proves the window pipeline (visible tinted guide rectangle).
struct OverlayContentView: View {
    let state: OverlayState
    unowned let controller: OverlayWindowController

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let path = GuideGeometry.path(for: state.type, in: rect, orientation: state.orientation)
            context.stroke(path, with: .color(state.color.color.opacity(0.9)), lineWidth: 1.5)
        }
        .ignoresSafeArea()
    }
}
```

- [ ] **Step 3: Create OverlayWindowController**

Create `Golden Ratio/Overlay/OverlayWindowController.swift`:

```swift
import AppKit
import SwiftUI
import Observation

/// Owns the overlay NSPanel and keeps it in sync with OverlayState.
/// Views mutate state; this controller applies window-level side effects.
@MainActor
final class OverlayWindowController {
    private let state: OverlayState
    private(set) var panel: OverlayPanel?

    init(state: OverlayState) {
        self.state = state
        observe()
    }

    private func observe() {
        withObservationTracking {
            _ = state.isVisible
            _ = state.isLocked
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.apply()
                self?.observe()  // re-arm: observation tracking is one-shot
            }
        }
        apply()
    }

    private func apply() {
        if state.isVisible {
            show()
        } else {
            panel?.orderOut(nil)
        }
        panel?.ignoresMouseEvents = state.isLocked
    }

    private func show() {
        let panel = self.panel ?? makePanel()
        if let screen = panel.screen ?? NSScreen.main {
            let clamped = OverlayFrameMath.clamped(panel.frame, to: screen.visibleFrame)
            panel.setFrame(clamped, display: false)
        }
        panel.orderFrontRegardless()
    }

    private func makePanel() -> OverlayPanel {
        let panel = OverlayPanel()
        panel.setFrameAutosaveName("OverlayPanel")
        let root = OverlayContentView(state: state, controller: self)
        panel.contentView = OverlayHostingView(rootView: root)
        self.panel = panel
        return panel
    }
}
```

- [ ] **Step 4: Wire into the app for a smoke test**

Replace the entire contents of `Golden Ratio/Golden_RatioApp.swift` with:

```swift
import SwiftUI
import Observation

@MainActor
@Observable
final class AppModel {
    let overlayState: OverlayState
    let windowController: OverlayWindowController

    init() {
        let state = OverlayState()
        overlayState = state
        windowController = OverlayWindowController(state: state)
    }
}

@main
struct Golden_RatioApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Golden Ratio", systemImage: "hurricane") {
            // Temporary controls; replaced by MenuPanelView in Task 7.
            Button(model.overlayState.isVisible ? "Hide Overlay" : "Show Overlay") {
                model.overlayState.isVisible.toggle()
            }
            .padding()
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 5: Build and smoke-run**

```bash
xcodebuild build -project "Golden Ratio.xcodeproj" -scheme "Golden Ratio" -configuration Debug -derivedDataPath build -quiet && open "build/Build/Products/Debug/Golden Ratio.app"
```

Expected: app launches with no Dock icon; a hurricane icon appears in the menu bar; clicking it shows the toggle button; toggling shows/hides a floating rule-of-thirds guide rectangle that stays above other windows. Quit the app afterwards (`pkill -x "Golden Ratio"`).

- [ ] **Step 6: Run all tests (regression)**

Run: `xcodebuild test -project "Golden Ratio.xcodeproj" -scheme "Golden Ratio" -destination 'platform=macOS' -only-testing:"Golden RatioTests" -quiet`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add "Golden Ratio/Overlay" "Golden Ratio/Golden_RatioApp.swift"
git commit -m "feat: floating non-activating overlay panel with state-driven lifecycle"
```

---

### Task 7: OverlayContentView — drawing, hover chrome, move/resize

**Files:**
- Modify: `Golden Ratio/Overlay/OverlayContentView.swift` (replace the stub entirely)

**Interfaces:**
- Consumes: `OverlayState`, `GuideGeometry`, `OverlayFrameMath`, `ResizeHandle`, `OverlayWindowController.panel`.
- Produces: final `OverlayContentView` (same `init(state:controller:)` signature as the stub — no changes needed elsewhere).

Behavior checklist implemented here (from spec):
- Guide stroked in `state.color` at 90 % opacity, 1.5 pt, over a wider black 35 %-opacity understroke so lines read on any background.
- Hover chrome: dashed frame border, 8 handles, ✕ close (top-left), glass control strip (flip H, flip V, rotate, lock) top-center. Fade in 150 ms ease-out, out 200 ms; instant under Reduce Motion; never shown while locked.
- Drag anywhere → move window (1:1). Drag handle → resize via `OverlayFrameMath`. Window frame is read once at drag start (`initialFrame`), all math is relative to it.
- Rotate/flip/type changes apply instantly (no animation on the Canvas).
- Lock: chrome disappears; a "Locked — unlock from the menu bar" glass badge fades in and out once (~1.4 s).

- [ ] **Step 1: Replace the stub with the full implementation**

Replace the entire contents of `Golden Ratio/Overlay/OverlayContentView.swift` with:

```swift
import SwiftUI

struct OverlayContentView: View {
    let state: OverlayState
    unowned let controller: OverlayWindowController

    @State private var hovering = false
    @State private var dragStart: (mouse: CGPoint, frame: CGRect)?
    @State private var showLockBadge = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var chromeVisible: Bool { hovering && !state.isLocked }

    var body: some View {
        ZStack {
            guideCanvas
            chrome
                .opacity(chromeVisible ? 1 : 0)
                .animation(
                    reduceMotion ? nil : .easeOut(duration: chromeVisible ? 0.15 : 0.20),
                    value: chromeVisible
                )
                .allowsHitTesting(chromeVisible)
            if showLockBadge { lockBadge }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .gesture(moveGesture)
        .onChange(of: state.isLocked) { _, locked in
            guard locked else { return }
            hovering = false
            showLockBadge = true
            Task {
                try? await Task.sleep(for: .seconds(1.4))
                showLockBadge = false
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Guide drawing

    private var guideCanvas: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
            let path = GuideGeometry.path(for: state.type, in: rect, orientation: state.orientation)
            // Understroke so lines read on any background.
            context.stroke(path, with: .color(.black.opacity(0.35)), lineWidth: 2.5)
            context.stroke(path, with: .color(state.color.color.opacity(0.9)), lineWidth: 1.5)
        }
    }

    // MARK: - Chrome

    private var chrome: some View {
        GeometryReader { geo in
            ZStack {
                Rectangle()
                    .strokeBorder(
                        state.color.color.opacity(0.5),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
                controlStrip
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 10)
                closeButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
                handles(in: geo.size)
            }
        }
    }

    private var controlStrip: some View {
        HStack(spacing: 2) {
            chromeButton("trapezoid.and.line.vertical", "Flip Horizontal") {
                state.orientation.flipHorizontal()
            }
            chromeButton("trapezoid.and.line.horizontal", "Flip Vertical") {
                state.orientation.flipVertical()
            }
            chromeButton("rotate.right", "Rotate 90°") {
                state.orientation.rotate90()
            }
            chromeButton("lock", "Lock (click-through)") {
                state.isLocked = true
            }
        }
        .padding(4)
        .glassEffect(.regular, in: Capsule())
    }

    private func chromeButton(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 26, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    private var closeButton: some View {
        Button {
            state.isVisible = false
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .frame(width: 20, height: 20)
                .contentShape(Circle())
        }
        .buttonStyle(.borderless)
        .glassEffect(.regular, in: Circle())
        .help("Close Overlay")
    }

    private var lockBadge: some View {
        Label("Locked — unlock from the menu bar", systemImage: "lock.fill")
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: Capsule())
            .transition(reduceMotion ? .identity : .opacity)
    }

    // MARK: - Handles

    private func handles(in size: CGSize) -> some View {
        ForEach(Array(ResizeHandle.allCases.enumerated()), id: \.offset) { _, handle in
            handleGrip(handle)
                .position(position(of: handle, in: size))
        }
    }

    private func handleGrip(_ handle: ResizeHandle) -> some View {
        Circle()
            .fill(state.color.color)
            .overlay(Circle().strokeBorder(.black.opacity(0.4), lineWidth: 1))
            .frame(width: 10, height: 10)
            .contentShape(Circle().inset(by: -8))  // generous hit area
            .gesture(resizeGesture(handle))
    }

    private func position(of handle: ResizeHandle, in size: CGSize) -> CGPoint {
        let midX = size.width / 2, midY = size.height / 2
        let maxX = size.width - 1, maxY = size.height - 1
        switch handle {
        case .topLeft: return CGPoint(x: 1, y: 1)
        case .top: return CGPoint(x: midX, y: 1)
        case .topRight: return CGPoint(x: maxX, y: 1)
        case .left: return CGPoint(x: 1, y: midY)
        case .right: return CGPoint(x: maxX, y: midY)
        case .bottomLeft: return CGPoint(x: 1, y: maxY)
        case .bottom: return CGPoint(x: midX, y: maxY)
        case .bottomRight: return CGPoint(x: maxX, y: maxY)
        }
    }

    // MARK: - Gestures

    // NOTE: gesture deltas are measured with NSEvent.mouseLocation (screen
    // coordinates, y-up) rather than DragGesture.translation. The gesture's own
    // translation is window-relative — and since these drags MOVE the window,
    // window-relative translation feedback-loops (the classic window-drag jitter).
    // Screen-space mouse deltas are stable while the window moves.
    // The y sign is flipped when building `translation` because OverlayFrameMath
    // expects view-space (y-down) translations.

    private func screenTranslation(since start: CGPoint) -> CGSize {
        let mouse = NSEvent.mouseLocation
        return CGSize(width: mouse.x - start.x, height: start.y - mouse.y)
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { _ in
                guard let panel = controller.panel else { return }
                if dragStart == nil { dragStart = (NSEvent.mouseLocation, panel.frame) }
                guard let start = dragStart else { return }
                let t = screenTranslation(since: start.mouse)
                panel.setFrameOrigin(OverlayFrameMath.moved(from: start.frame, translation: t).origin)
            }
            .onEnded { _ in dragStart = nil }
    }

    private func resizeGesture(_ handle: ResizeHandle) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { _ in
                guard let panel = controller.panel else { return }
                if dragStart == nil { dragStart = (NSEvent.mouseLocation, panel.frame) }
                guard let start = dragStart else { return }
                let f = OverlayFrameMath.frame(
                    after: handle,
                    translation: screenTranslation(since: start.mouse),
                    initial: start.frame
                )
                panel.setFrame(f, display: true)
            }
            .onEnded { _ in dragStart = nil }
    }
}
```

- [ ] **Step 2: Build and smoke-run**

```bash
xcodebuild build -project "Golden Ratio.xcodeproj" -scheme "Golden Ratio" -configuration Debug -derivedDataPath build -quiet && open "build/Build/Products/Debug/Golden Ratio.app"
```

Expected: overlay shows guides; hovering fades in dashed border, 8 grips, ✕, and a glass control strip; dragging the body moves the window 1:1; dragging grips resizes with the opposite edge anchored; rotate/flip buttons re-orient the guide instantly; lock hides chrome, flashes the badge, and clicks pass through to windows beneath. Quit afterwards (`pkill -x "Golden Ratio"`).

- [ ] **Step 3: Run all tests (regression)**

Run: `xcodebuild test -project "Golden Ratio.xcodeproj" -scheme "Golden Ratio" -destination 'platform=macOS' -only-testing:"Golden RatioTests" -quiet`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add "Golden Ratio/Overlay/OverlayContentView.swift"
git commit -m "feat: overlay guide rendering with hover chrome, move/resize, and lock badge"
```

---

### Task 8: MenuPanelView — tiles, swatches, controls

**Files:**
- Create: `Golden Ratio/MenuPanel/MenuPanelView.swift`
- Modify: `Golden Ratio/Golden_RatioApp.swift` (swap the temporary button for `MenuPanelView`)

**Interfaces:**
- Consumes: `OverlayState`, `OverlayType`, `GuideColor`, `GuideGeometry`, `Orientation`.
- Produces: `struct MenuPanelView: View` — `init(state: OverlayState)`.

Behavior (from spec):
- 3×2 grid of tiles, each a mini `Canvas` drawing of its guide (identity orientation), reusing `GuideGeometry`. Active tile = accent-tinted background + border, only when the overlay is visible. Click inactive tile → select type and show overlay. Click active tile → hide overlay.
- Swatch row: 6 circles; selected shows a ring.
- Control row: flip H, flip V, rotate, lock-toggle, quit. Overlay-affecting controls disabled when `!state.isVisible`. Lock button shows `lock.fill` and stays enabled while locked (it's the only unlock path).
- Buttons press-scale to 0.97 instantly; no other animation (high-frequency actions).

- [ ] **Step 1: Implement MenuPanelView**

Create `Golden Ratio/MenuPanel/MenuPanelView.swift`:

```swift
import SwiftUI

struct MenuPanelView: View {
    let state: OverlayState

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(OverlayType.allCases) { type in
                    tile(for: type)
                }
            }
            swatchRow
            Divider()
            controlRow
        }
        .padding(12)
        .frame(width: 280)
    }

    // MARK: - Tiles

    private func tile(for type: OverlayType) -> some View {
        let isActive = state.isVisible && state.type == type
        return Button {
            if isActive {
                state.isVisible = false
            } else {
                state.type = type
                state.isVisible = true
            }
        } label: {
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: 6, dy: 6)
                let path = GuideGeometry.path(for: type, in: rect, orientation: .identity)
                let color: Color = isActive ? .accentColor : .secondary
                context.stroke(path, with: .color(color), lineWidth: 1)
            }
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isActive ? Color.accentColor : .clear, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PressableButtonStyle())
        .help(type.displayName)
        .accessibilityLabel(type.displayName)
    }

    // MARK: - Swatches

    private var swatchRow: some View {
        HStack(spacing: 10) {
            ForEach(GuideColor.allCases) { swatch in
                Button {
                    state.color = swatch
                } label: {
                    Circle()
                        .fill(swatch.color)
                        .overlay(Circle().strokeBorder(.primary.opacity(0.2), lineWidth: 0.5))
                        .overlay(
                            Circle()
                                .strokeBorder(Color.accentColor, lineWidth: 2)
                                .padding(-3)
                                .opacity(state.color == swatch ? 1 : 0)
                        )
                        .frame(width: 18, height: 18)
                        .contentShape(Circle().inset(by: -4))
                }
                .buttonStyle(PressableButtonStyle())
                .help(swatch.displayName)
                .accessibilityLabel(swatch.displayName)
            }
        }
    }

    // MARK: - Controls

    private var controlRow: some View {
        HStack(spacing: 4) {
            controlButton("trapezoid.and.line.vertical", "Flip Horizontal") {
                state.orientation.flipHorizontal()
            }
            controlButton("trapezoid.and.line.horizontal", "Flip Vertical") {
                state.orientation.flipVertical()
            }
            controlButton("rotate.right", "Rotate 90°") {
                state.orientation.rotate90()
            }
            Button {
                state.isLocked.toggle()
            } label: {
                Image(systemName: state.isLocked ? "lock.fill" : "lock")
                    .frame(width: 30, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!state.isVisible)
            .help(state.isLocked ? "Unlock Overlay" : "Lock (click-through)")
            Spacer()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .frame(width: 30, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .help("Quit Golden Ratio")
        }
    }

    private func controlButton(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 30, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!state.isVisible || state.isLocked)
        .help(help)
    }
}

/// Instant 0.97 press-scale; no animation on release path beyond the default.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
```

- [ ] **Step 2: Swap the panel into the app**

In `Golden Ratio/Golden_RatioApp.swift`, replace the `MenuBarExtra` content (the temporary `Button(...)...padding()` block) with:

```swift
            MenuPanelView(state: model.overlayState)
```

The scene should now read:

```swift
    var body: some Scene {
        MenuBarExtra("Golden Ratio", systemImage: "hurricane") {
            MenuPanelView(state: model.overlayState)
        }
        .menuBarExtraStyle(.window)
    }
```

- [ ] **Step 3: Build and smoke-run**

```bash
xcodebuild build -project "Golden Ratio.xcodeproj" -scheme "Golden Ratio" -configuration Debug -derivedDataPath build -quiet && open "build/Build/Products/Debug/Golden Ratio.app"
```

Expected: menu panel shows 6 mini-preview tiles, 6 swatches, control row. Tiles show/switch/hide the overlay; swatches recolor it live; flip/rotate re-orient it; lock toggles click-through and the lock button is the working unlock path; power button quits. Quit afterwards if still running (`pkill -x "Golden Ratio"`).

- [ ] **Step 4: Run all tests (regression)**

Run: `xcodebuild test -project "Golden Ratio.xcodeproj" -scheme "Golden Ratio" -destination 'platform=macOS' -only-testing:"Golden RatioTests" -quiet`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add "Golden Ratio/MenuPanel" "Golden Ratio/Golden_RatioApp.swift"
git commit -m "feat: menu bar panel with guide tiles, color swatches, and controls"
```

---

### Task 9: Final verification pass

**Files:**
- None created; fixes only if the checklist below finds issues.

**Interfaces:** none.

- [ ] **Step 1: Full unit test run**

Run: `xcodebuild test -project "Golden Ratio.xcodeproj" -scheme "Golden Ratio" -destination 'platform=macOS' -only-testing:"Golden RatioTests" -quiet`
Expected: PASS, zero failures.

- [ ] **Step 2: Manual verification checklist (run the app)**

```bash
xcodebuild build -project "Golden Ratio.xcodeproj" -scheme "Golden Ratio" -configuration Debug -derivedDataPath build -quiet && open "build/Build/Products/Debug/Golden Ratio.app"
```

Walk through each item; fix and re-run on any failure:

1. No Dock icon; hurricane icon in menu bar.
2. All 6 guide types render correctly (spiral winds inward, armature is a 14-line star, phi grid is visibly tighter to center than thirds).
3. Overlay floats above a full-screen app (put Preview into full screen, overlay still visible on that Space).
4. Clicking/dragging the overlay never activates the app (menu bar app name doesn't change; the previously focused app keeps focus).
5. All 8 spiral orientations reachable via rotate ×4 and flip H.
6. Resize from every handle; min size enforced; opposite edge anchored.
7. Lock: chrome gone, badge flashes, clicks land in the window beneath; unlock via menu bar works.
8. Quit and relaunch: overlay frame, type, color, orientation, and visibility restored; lock is off.
9. System Settings → Accessibility → Display → Reduce Motion on: chrome appears/disappears without fade.
10. Overlay dragged mostly off-screen, hide, quit, relaunch, show: frame is clamped back onto the screen.

- [ ] **Step 3: Quit the app and commit any fixes**

```bash
pkill -x "Golden Ratio"
git status --short   # commit any checklist fixes made above
```

- [ ] **Step 4: Final commit if fixes were made**

```bash
git add -A
git commit -m "fix: final verification pass adjustments"
```
