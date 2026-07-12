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

    @Test func clampEnforcesMinSize() {
        let visible = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let tiny = CGRect(x: 0, y: 0, width: 50, height: 50)
        let f = OverlayFrameMath.clamped(tiny, to: visible)
        #expect(f.width >= OverlayFrameMath.minSize)
        #expect(f.height >= OverlayFrameMath.minSize)
        // Still fully inside:
        #expect(f.minX >= 0 && f.minY >= 0 && f.maxX <= 1920 && f.maxY <= 1080)
    }

    // MARK: - Wave 3c: modifier-key resize (aspect / from-center)

    /// initial is 400x300 → aspect 4:3.

    // 1. Shift + right edge dragged +60: width authoritative (460), height derived
    //    460 * 3/4 = 345, other axis (y) centered on initial midY, minX unchanged.
    @Test func shiftRightEdgePreservesAspectCenteredOnMidY() {
        let f = OverlayFrameMath.frame(
            after: .right, translation: CGSize(width: 60, height: 0),
            initial: initial, options: [.preserveAspect]
        )
        #expect(abs(f.width - 460) < 1e-6)
        #expect(abs(f.height - 345) < 1e-6)
        #expect(abs(f.midY - initial.midY) < 1e-6)   // 250 → minY 77.5
        #expect(abs(f.minY - 77.5) < 1e-6)
        #expect(abs(f.minX - initial.minX) < 1e-6)    // 100 (left anchored)
    }

    // 2. Shift + bottomRight corner (+80, +30 view-space): tentative (480 x 330).
    //    relW = 80/400 = 0.2 > relH = 30/300 = 0.1 → width dominates.
    //    width 480, height 480*3/4 = 360. Opposite corner (minX 100, maxY 400) fixed.
    @Test func shiftBottomRightCornerWidthDominates() {
        let f = OverlayFrameMath.frame(
            after: .bottomRight, translation: CGSize(width: 80, height: 30),
            initial: initial, options: [.preserveAspect]
        )
        #expect(abs(f.width - 480) < 1e-6)
        #expect(abs(f.height - 360) < 1e-6)
        #expect(abs(f.minX - initial.minX) < 1e-6)   // 100 fixed
        #expect(abs(f.maxY - initial.maxY) < 1e-6)   // 400 fixed
        #expect(abs(f.minY - 40) < 1e-6)             // 400 - 360
    }

    // 3. Shift + right edge dragged −1000: width clamps to minSize 120, derived
    //    height 90 < minSize → scale pair up so height = 120 (smaller dim),
    //    width = 160 (= 120 * 4/3). Ratio preserved; left edge (minX) stays anchored
    //    per the edge rule (NOT maxX — the brief sketch is corrected here).
    @Test func shiftRightEdgeMinSizeScalesPairUp() {
        let f = OverlayFrameMath.frame(
            after: .right, translation: CGSize(width: -1000, height: 0),
            initial: initial, options: [.preserveAspect]
        )
        #expect(abs(f.width - 160) < 1e-6)
        #expect(abs(f.height - 120) < 1e-6)
        #expect(abs(f.minX - initial.minX) < 1e-6)   // 100 (left anchored)
        #expect(abs(f.midY - initial.midY) < 1e-6)   // centered on midY
    }

    // 4. Option + right edge +60: plain resize (width 460, height 300) recentered
    //    on the initial frame's center — size unchanged, center fixed.
    @Test func optionRightEdgeResizesFromCenter() {
        let f = OverlayFrameMath.frame(
            after: .right, translation: CGSize(width: 60, height: 0),
            initial: initial, options: [.fromCenter]
        )
        #expect(abs(f.width - 460) < 1e-6)
        #expect(abs(f.height - 300) < 1e-6)
        #expect(abs(f.midX - initial.midX) < 1e-6)   // 300
        #expect(abs(f.midY - initial.midY) < 1e-6)   // 250
    }

    // 5. Option + Shift + right edge +60: aspect computes the size (460 x 345),
    //    from-center places it — center stays at the initial center.
    @Test func optionShiftRightEdgeAspectFromCenter() {
        let f = OverlayFrameMath.frame(
            after: .right, translation: CGSize(width: 60, height: 0),
            initial: initial, options: [.preserveAspect, .fromCenter]
        )
        #expect(abs(f.width - 460) < 1e-6)
        #expect(abs(f.height - 345) < 1e-6)
        #expect(abs(f.midX - initial.midX) < 1e-6)   // 300
        #expect(abs(f.midY - initial.midY) < 1e-6)   // 250
    }

    // MARK: - On-screen predicate

    @Test func intersectsAnyTrueWhenOverlappingAScreen() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1920, height: 1080),
            CGRect(x: 1920, y: 0, width: 1920, height: 1080),
        ]
        #expect(OverlayFrameMath.intersectsAny(CGRect(x: 100, y: 100, width: 400, height: 300), of: screens))
    }

    @Test func intersectsAnyFalseWhenFullyOffscreen() {
        let screens = [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        #expect(OverlayFrameMath.intersectsAny(CGRect(x: 5000, y: 5000, width: 400, height: 300), of: screens) == false)
    }

    @Test func intersectsAnyFalseForEmptyList() {
        #expect(OverlayFrameMath.intersectsAny(CGRect(x: 0, y: 0, width: 10, height: 10), of: []) == false)
    }

    // 6. Empty options must be byte-identical to the 3-arg form (no regression).
    @Test func emptyOptionsMatchesLegacyBehavior() {
        for handle in ResizeHandle.allCases {
            let t = CGSize(width: 37, height: -21)
            let legacy = OverlayFrameMath.frame(after: handle, translation: t, initial: initial)
            let withOpts = OverlayFrameMath.frame(after: handle, translation: t, initial: initial, options: [])
            #expect(legacy == withOpts)
        }
    }
}
