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
