import CoreGraphics

nonisolated enum ResizeHandle: CaseIterable, Sendable {
    case topLeft, top, topRight, left, right, bottomLeft, bottom, bottomRight
}

/// Pure frame math for the overlay panel. Frames are AppKit y-up;
/// `translation` values are SwiftUI view-space (y-down). Conversion is internal.
nonisolated enum OverlayFrameMath {
    static let minSize: CGFloat = 120

    /// Modifier-key resize behaviors, sampled live during a handle drag.
    nonisolated struct ResizeOptions: OptionSet, Sendable {
        let rawValue: Int
        /// Shift: keep the aspect ratio the frame had at drag start.
        static let preserveAspect = ResizeOptions(rawValue: 1 << 0)
        /// Option: resize symmetrically about the initial frame's center.
        static let fromCenter = ResizeOptions(rawValue: 1 << 1)
    }

    static func moved(from initial: CGRect, translation: CGSize) -> CGRect {
        CGRect(
            x: initial.origin.x + translation.width,
            y: initial.origin.y - translation.height,
            width: initial.width,
            height: initial.height
        )
    }

    static func frame(
        after handle: ResizeHandle,
        translation: CGSize,
        initial: CGRect,
        options: ResizeOptions = []
    ) -> CGRect {
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

        // Aspect first (computes the size + anchors it), then from-center
        // (keeps that size, moves origin so the center matches `initial`).
        if options.contains(.preserveAspect) {
            f = aspectPreserved(handle: handle, tentative: f, initial: initial)
        }
        if options.contains(.fromCenter) {
            f.origin.x = initial.midX - f.width / 2
            f.origin.y = initial.midY - f.height / 2
        }
        return f
    }

    /// Re-derives `tentative`'s size to preserve `initial`'s aspect ratio and
    /// anchors it. Corners: the dominant axis (larger relative change) drives the
    /// other; the opposite corner stays fixed. Edges: the dragged axis is
    /// authoritative and the derived axis is centered on `initial`'s center on
    /// that axis. If a derived dimension drops below `minSize`, the pair is scaled
    /// up uniformly so the smaller dimension equals `minSize`.
    private static func aspectPreserved(
        handle: ResizeHandle,
        tentative: CGRect,
        initial: CGRect
    ) -> CGRect {
        // Multiply by the initial ratio (rather than divide by a precomputed
        // aspect) to keep values exact for clean ratios.
        func widthFromHeight(_ h: CGFloat) -> CGFloat { h * initial.width / initial.height }
        func heightFromWidth(_ w: CGFloat) -> CGFloat { w * initial.height / initial.width }

        var w: CGFloat
        var h: CGFloat
        switch handle {
        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            let relW = abs(tentative.width - initial.width) / initial.width
            let relH = abs(tentative.height - initial.height) / initial.height
            if relW >= relH {
                w = tentative.width
                h = heightFromWidth(w)
            } else {
                h = tentative.height
                w = widthFromHeight(h)
            }
        case .left, .right:
            w = tentative.width
            h = heightFromWidth(w)
        case .top, .bottom:
            h = tentative.height
            w = widthFromHeight(h)
        }

        // Uniform scale-up so the smaller derived dimension reaches minSize.
        let scale = max(1, minSize / w, minSize / h)
        w *= scale
        h *= scale

        // Anchor: keep the same fixed point the tentative (per-edge) logic used.
        var f = CGRect(x: 0, y: 0, width: w, height: h)
        switch handle {
        case .topLeft:      // opposite corner fixed: (maxX, minY)
            f.origin = CGPoint(x: initial.maxX - w, y: initial.minY)
        case .topRight:     // (minX, minY)
            f.origin = CGPoint(x: initial.minX, y: initial.minY)
        case .bottomLeft:   // (maxX, maxY)
            f.origin = CGPoint(x: initial.maxX - w, y: initial.maxY - h)
        case .bottomRight:  // (minX, maxY)
            f.origin = CGPoint(x: initial.minX, y: initial.maxY - h)
        case .left:         // right edge (maxX) fixed; centered on midY
            f.origin = CGPoint(x: initial.maxX - w, y: initial.midY - h / 2)
        case .right:        // left edge (minX) fixed; centered on midY
            f.origin = CGPoint(x: initial.minX, y: initial.midY - h / 2)
        case .top:          // bottom edge (minY) fixed; centered on midX
            f.origin = CGPoint(x: initial.midX - w / 2, y: initial.minY)
        case .bottom:       // top edge (maxY) fixed; centered on midX
            f.origin = CGPoint(x: initial.midX - w / 2, y: initial.maxY - h)
        }
        return f
    }

    /// Returns `frame` adjusted to lie fully inside `visible`, shrinking if needed.
    static func clamped(_ frame: CGRect, to visible: CGRect) -> CGRect {
        var f = frame
        // Enforce minSize against corrupt/legacy autosave, but never exceed the
        // screen (a screen smaller than minSize wins, to keep the fully-inside
        // guarantee).
        f.size.width = min(max(f.width, minSize), visible.width)
        f.size.height = min(max(f.height, minSize), visible.height)
        f.origin.x = min(max(f.origin.x, visible.minX), visible.maxX - f.width)
        f.origin.y = min(max(f.origin.y, visible.minY), visible.maxY - f.height)
        return f
    }
}
