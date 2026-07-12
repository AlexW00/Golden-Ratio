import CoreGraphics

/// One of the 8 dihedral orientations of a rectangle: flips applied first,
/// then `quarterTurns` × 90° clockwise. All in the rect's own (stretching) space.
nonisolated struct Orientation: Codable, Equatable, Sendable {
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
