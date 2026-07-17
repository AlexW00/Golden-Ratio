import SwiftUI
import KeyboardShortcuts

/// Content of a transient HUD badge (currently the lock hint).
private struct OverlayBadge: Equatable {
    var symbol: String
    var text: String
}

struct OverlayContentView: View {
    let state: OverlayState
    unowned let controller: OverlayWindowController

    @State private var hovering = false
    @State private var hoveredHandle: ResizeHandle?
    @State private var dragStart: (mouse: CGPoint, frame: CGRect)?
    @State private var badge: OverlayBadge?
    @State private var badgeTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var chromeVisible: Bool {
        hovering && (!state.isLocked || state.isTemporarilyUnlocked)
    }

    /// Inset from the window edge at which the guide, dashed frame, and handles
    /// render. Gives corner/edge handles room to sit exactly on the frame.
    private let chromeMargin: CGFloat = 8

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
            if let badge { badgeView(badge) }
        }
        .contentShape(Rectangle())
        // Grab cursor only while the chrome is showing; default when the
        // overlay is locked (click-through) or the pointer is elsewhere.
        .pointerStyle(chromeVisible ? .grabIdle : .default)
        .background(ActiveAlwaysHoverTracker { hovering = $0 })
        .gesture(moveGesture)
        .onChange(of: state.isLocked) { _, locked in
            guard locked else { return }
            hovering = false
            hoveredHandle = nil
            let text = state.tempUnlockModifier.keySymbol
                .map { "Locked — hold \($0) to adjust" }
                ?? "Locked — unlock from the menu bar"
            showBadge(OverlayBadge(symbol: "lock.fill", text: text))
        }
        .ignoresSafeArea()
    }

    // MARK: - Guide drawing

    private var guideCanvas: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: chromeMargin, dy: chromeMargin)
            let path = GuideGeometry.path(for: state.type, in: rect, orientation: state.orientation)
            // Understroke so lines read on any background.
            context.stroke(path, with: .color(state.color.understroke.opacity(0.35)), lineWidth: 2.5)
            context.stroke(path, with: .color(state.color.color.opacity(0.9)), lineWidth: 1.5)
        }
    }

    // MARK: - Chrome

    private var chrome: some View {
        GeometryReader { geo in
            ZStack {
                frameBorder
                controlStrip
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 10)
                handles(in: geo.size)
            }
        }
    }

    /// Two-pass dashed border (understroke + color), matching the guide
    /// drawing style so the frame reads on any background.
    private var frameBorder: some View {
        ZStack {
            Rectangle()
                .inset(by: chromeMargin)
                .stroke(
                    state.color.understroke.opacity(0.5),
                    style: StrokeStyle(lineWidth: 3, dash: [6, 4])
                )
            Rectangle()
                .inset(by: chromeMargin)
                .stroke(
                    state.color.color.opacity(0.85),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
        }
        .allowsHitTesting(false)
    }

    private var controlStrip: some View {
        HStack(spacing: 8) {
            ChromeStripButton("trapezoid.and.line.vertical",
                              helpText("Flip Horizontal", shortcut: .flipHorizontal)) {
                state.orientation.flipHorizontal()
            }
            ChromeStripButton("trapezoid.and.line.horizontal",
                              helpText("Flip Vertical", shortcut: .flipVertical)) {
                state.orientation.flipVertical()
            }
            ChromeStripButton("rotate.right",
                              helpText("Rotate 90°", shortcut: .rotateGuide)) {
                state.orientation.rotate90()
            }
            // During a temporary unlock the overlay is still locked; the same
            // slot then offers a permanent unlock.
            ChromeStripButton(
                state.isLocked ? "lock.open" : "lock",
                helpText(
                    state.isLocked ? "Unlock Overlay" : "Lock (click-through)",
                    shortcut: .toggleLock
                )
            ) {
                state.isLocked.toggle()
            }
            ChromeStripButton("xmark",
                              helpText("Close Overlay", shortcut: .toggleOverlay)) {
                state.isVisible = false
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .hudCapsule()
    }

    /// Shows a transient HUD badge, replacing any badge currently on screen
    /// and restarting the auto-dismiss timer.
    private func showBadge(_ new: OverlayBadge) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
            badge = new
        }
        badgeTask?.cancel()
        badgeTask = Task {
            try? await Task.sleep(for: .seconds(1.4))
            if Task.isCancelled { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                badge = nil
            }
        }
    }

    private func badgeView(_ badge: OverlayBadge) -> some View {
        Label(badge.text, systemImage: badge.symbol)
            .font(.callout)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .hudCapsule()
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
        let isHovered = hoveredHandle == handle
        let metrics = handleMetrics(for: handle)
        let shape = RoundedRectangle(cornerRadius: metrics.cornerRadius)
        return shape
            .fill(state.color.color)
            .overlay(
                shape.strokeBorder(
                    isHovered ? Color.white.opacity(0.9) : Color.black.opacity(0.4),
                    lineWidth: 1
                )
            )
            .frame(width: metrics.size.width, height: metrics.size.height)
            .scaleEffect(isHovered ? 1.15 : 1.0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovered)
            .contentShape(shape.inset(by: -8))  // generous hit area
            .onHover { inside in
                if inside {
                    hoveredHandle = handle
                } else if hoveredHandle == handle {
                    hoveredHandle = nil
                }
            }
            .pointerStyle(.frameResize(position: frameResizePosition(for: handle)))
            .gesture(resizeGesture(handle))
    }

    /// Per-axis handle geometry: corners are rounded squares that sit on the
    /// frame corner; edges are elongated pills oriented along their edge.
    private func handleMetrics(for handle: ResizeHandle) -> (size: CGSize, cornerRadius: CGFloat) {
        switch handle {
        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            return (CGSize(width: 13, height: 13), 3.5)
        case .top, .bottom:
            return (CGSize(width: 26, height: 9), 4.5)
        case .left, .right:
            return (CGSize(width: 9, height: 26), 4.5)
        }
    }

    private func frameResizePosition(for handle: ResizeHandle) -> FrameResizePosition {
        switch handle {
        case .topLeft: .topLeading
        case .top: .top
        case .topRight: .topTrailing
        case .left: .leading
        case .right: .trailing
        case .bottomLeft: .bottomLeading
        case .bottom: .bottom
        case .bottomRight: .bottomTrailing
        }
    }

    private func position(of handle: ResizeHandle, in size: CGSize) -> CGPoint {
        let midX = size.width / 2, midY = size.height / 2
        let minX = chromeMargin, minY = chromeMargin
        let maxX = size.width - chromeMargin, maxY = size.height - chromeMargin
        switch handle {
        case .topLeft: return CGPoint(x: minX, y: minY)
        case .top: return CGPoint(x: midX, y: minY)
        case .topRight: return CGPoint(x: maxX, y: minY)
        case .left: return CGPoint(x: minX, y: midY)
        case .right: return CGPoint(x: maxX, y: midY)
        case .bottomLeft: return CGPoint(x: minX, y: maxY)
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

    /// Captures the drag anchor once per gesture: the initial mouse location
    /// and the panel frame at drag start. Returns nil until a frame exists.
    private func beginDragIfNeeded() -> (mouse: CGPoint, frame: CGRect)? {
        if dragStart == nil {
            guard let frame = controller.dragStartFrame() else { return nil }
            dragStart = (NSEvent.mouseLocation, frame)
        }
        return dragStart
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { _ in
                guard let start = beginDragIfNeeded() else { return }
                controller.move(from: start.frame, translation: screenTranslation(since: start.mouse))
            }
            .onEnded { _ in
                dragStart = nil
                controller.dragEnded()
            }
    }

    private func resizeGesture(_ handle: ResizeHandle) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { _ in
                guard let start = beginDragIfNeeded() else { return }
                // Sample modifiers live so pressing/releasing mid-drag takes
                // effect immediately (frame math is recomputed from `initial`).
                // A modifier held to sustain the temporary unlock is consumed —
                // it must not double as a resize option (⌥ = from-center).
                var options: OverlayFrameMath.ResizeOptions = []
                var mods = NSEvent.modifierFlags
                if state.isTemporarilyUnlocked {
                    mods = state.tempUnlockModifier.consumed(from: mods)
                }
                if mods.contains(.shift) { options.insert(.preserveAspect) }
                if mods.contains(.option) { options.insert(.fromCenter) }
                controller.resize(
                    handle,
                    from: start.frame,
                    translation: screenTranslation(since: start.mouse),
                    options: options
                )
            }
            .onEnded { _ in
                dragStart = nil
                controller.dragEnded()
            }
    }
}

// MARK: - HUD capsule chrome

private struct HUDCapsule: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    BehindWindowMaterial().clipShape(Capsule())
                    Capsule().strokeBorder(.white.opacity(0.15))
                }
            )
            .colorScheme(.dark)
            .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
    }
}

private extension View {
    /// Shared HUD capsule chrome: behind-window material clipped to a capsule
    /// with a hairline border, forced dark, with a soft drop shadow.
    func hudCapsule() -> some View { modifier(HUDCapsule()) }
}

// MARK: - Chrome button styling

/// Borderless HUD strip button: white glyph on the shared material capsule,
/// with a circular hover highlight behind the icon (instant in, ease-out out)
/// and a subtle pressed scale.
private struct ChromeStripButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ symbol: String, _ help: String, action: @escaping () -> Void) {
        self.symbol = symbol
        self.help = help
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 26, height: 22)
                .background(
                    Circle().fill(.white.opacity(hovering ? 0.15 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.95))
        .onHover { hovering = $0 }
        // Instant highlight in, 0.12s ease-out fade out; nil under Reduce Motion.
        .animation(reduceMotion ? nil : (hovering ? nil : .easeOut(duration: 0.12)), value: hovering)
        .pointerStyle(.link)
        .help(help)
        .accessibilityLabel(help)
    }
}
