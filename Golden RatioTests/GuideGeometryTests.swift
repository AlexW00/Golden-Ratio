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
