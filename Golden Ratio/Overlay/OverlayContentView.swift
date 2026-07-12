import SwiftUI

struct OverlayContentView: View {
    let state: OverlayState
    unowned let controller: OverlayWindowController

    @State private var hovering = false
    @State private var hoveredHandle: ResizeHandle?
    @State private var dragStart: (mouse: CGPoint, frame: CGRect)?
    @State private var showLockBadge = false
    @State private var badgeTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var chromeVisible: Bool { hovering && !state.isLocked }

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
            if showLockBadge { lockBadge }
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
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                showLockBadge = true
            }
            badgeTask?.cancel()
            badgeTask = Task {
                try? await Task.sleep(for: .seconds(1.4))
                if Task.isCancelled { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    showLockBadge = false
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Guide drawing

    private var guideCanvas: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
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
                closeButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
                handles(in: geo.size)
            }
        }
    }

    /// Two-pass dashed border (understroke + color), matching the guide
    /// drawing style so the frame reads on any background.
    private var frameBorder: some View {
        ZStack {
            Rectangle()
                .inset(by: 1)
                .stroke(
                    state.color.understroke.opacity(0.5),
                    style: StrokeStyle(lineWidth: 3, dash: [6, 4])
                )
            Rectangle()
                .inset(by: 1)
                .stroke(
                    state.color.color.opacity(0.85),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
        }
        .allowsHitTesting(false)
    }

    private var controlStrip: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                chromeButton("trapezoid.and.line.vertical", "Flip Horizontal") {
                    state.orientation.flipHorizontal()
                }
                chromeButton("trapezoid.and.line.horizontal", "Flip Vertical") {
                    state.orientation.flipVertical()
                }
                chromeButton("rotate.right", "Rotate 90°") {
                    state.orientation.rotate90()
                }
                chromeButton("lock", "Lock (click-through)") {
                    state.isLocked = true
                }
            }
        }
    }

    private func chromeButton(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 26, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.glass)
        .pointerStyle(.link)
        .help(help)
        .accessibilityLabel(help)
    }

    private var closeButton: some View {
        Button {
            state.isVisible = false
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .frame(width: 20, height: 20)
                .contentShape(Circle())
        }
        .buttonStyle(.glass)
        .pointerStyle(.link)
        .help("Close Overlay")
        .accessibilityLabel("Close Overlay")
    }

    private var lockBadge: some View {
        Label("Locked — unlock from the menu bar", systemImage: "lock.fill")
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: Capsule())
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
        return Circle()
            .fill(state.color.color)
            .overlay(
                Circle().strokeBorder(
                    isHovered ? Color.white.opacity(0.9) : Color.black.opacity(0.4),
                    lineWidth: 1
                )
            )
            .frame(width: 12, height: 12)
            .scaleEffect(isHovered ? 1.25 : 1.0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovered)
            .contentShape(Circle().inset(by: -10))  // generous hit area
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
        let maxX = size.width - 7, maxY = size.height - 7
        switch handle {
        case .topLeft: return CGPoint(x: 7, y: 7)
        case .top: return CGPoint(x: midX, y: 7)
        case .topRight: return CGPoint(x: maxX, y: 7)
        case .left: return CGPoint(x: 7, y: midY)
        case .right: return CGPoint(x: maxX, y: midY)
        case .bottomLeft: return CGPoint(x: 7, y: maxY)
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

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { _ in
                guard let panel = controller.panel else { return }
                if dragStart == nil { dragStart = (NSEvent.mouseLocation, panel.frame) }
                guard let start = dragStart else { return }
                let t = screenTranslation(since: start.mouse)
                panel.setFrameOrigin(OverlayFrameMath.moved(from: start.frame, translation: t).origin)
            }
            .onEnded { _ in dragStart = nil }
    }

    private func resizeGesture(_ handle: ResizeHandle) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { _ in
                guard let panel = controller.panel else { return }
                if dragStart == nil { dragStart = (NSEvent.mouseLocation, panel.frame) }
                guard let start = dragStart else { return }
                let f = OverlayFrameMath.frame(
                    after: handle,
                    translation: screenTranslation(since: start.mouse),
                    initial: start.frame
                )
                panel.setFrame(f, display: true)
            }
            .onEnded { _ in dragStart = nil }
    }
}
