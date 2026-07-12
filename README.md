# Golden Ratio

A tiny macOS menu bar app that floats a composition guide over anything on your screen — and, unlike most editors' built-in overlays, lets you **rotate and flip** it.

Born from a simple frustration: Photomator (and many other apps) can't rotate or mirror the golden spiral. Golden Ratio puts the guide in a floating overlay you can place over *any* app, in any of its eight orientations.

## Guides

- **Rule of Thirds** — 3×3 equal grid
- **Phi Grid** — 3×3 grid at golden proportions (1 : 0.618 : 1)
- **Golden Spiral** — Fibonacci spiral with its golden-rectangle subdivisions
- **Golden Diagonals** — corner diagonals plus their reciprocals
- **Harmonic Armature** — the classic 14-line armature
- **Center Cross** — centered midlines

## Usage

Everything lives in the menu bar (look for the spiral). Click a guide tile to show it; click the active tile to hide it. Pick a line color from the swatches.

The overlay itself:

| Action | How |
| --- | --- |
| Move | Drag anywhere inside the frame |
| Resize | Drag a corner or edge handle |
| Resize, keeping aspect ratio | Hold **⇧ Shift** while dragging a handle |
| Resize from center | Hold **⌥ Option** while dragging a handle |
| Rotate 90° / flip | Buttons on the overlay (hover) or in the menu bar panel |
| Click-through mode | **Lock** — clicks pass through to the app beneath; unlock from the menu bar |
| Close | ✕ in the overlay's toolbar, or the active tile in the menu |

The overlay floats above every window (full-screen apps included), never steals focus from the app you're working in, and remembers its position, guide, color, and orientation across launches. No permissions required.

## Building

Requires macOS 26+ and Xcode 26+.

```sh
git clone <this repo>
open "Golden Ratio.xcodeproj"   # ⌘R
```

Or headless: `xcodebuild -scheme "Golden Ratio" -configuration Release build`

## License

[MIT](LICENSE)
