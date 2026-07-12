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
