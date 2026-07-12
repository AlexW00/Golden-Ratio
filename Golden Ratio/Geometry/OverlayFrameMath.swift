import CoreGraphics

nonisolated enum ResizeHandle: CaseIterable, Sendable {
    case topLeft, top, topRight, left, right, bottomLeft, bottom, bottomRight
}

/// Pure frame math for the overlay panel. Frames are AppKit y-up;
/// `translation` values are SwiftUI view-space (y-down). Conversion is internal.
nonisolated enum OverlayFrameMath {
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
