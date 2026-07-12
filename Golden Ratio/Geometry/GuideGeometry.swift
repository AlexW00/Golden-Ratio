import SwiftUI

/// Pure geometry for all guide types. No state, no UI — fully unit-testable.
nonisolated enum GuideGeometry {
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
        return orientation == .identity ? raw : raw.applying(orientation.transform(in: rect))
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
