import SwiftUI

struct MenuPanelView: View {
    let state: OverlayState

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(OverlayType.allCases) { type in
                    tile(for: type)
                }
            }
            swatchRow
            Divider()
            controlRow
        }
        .padding(12)
        .frame(width: 280)
    }

    // MARK: - Tiles

    private func tile(for type: OverlayType) -> some View {
        let isActive = state.isVisible && state.type == type
        return Button {
            if isActive {
                state.isVisible = false
            } else {
                state.type = type
                state.isVisible = true
            }
        } label: {
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: 6, dy: 6)
                let path = GuideGeometry.path(for: type, in: rect, orientation: .identity)
                let color: Color = isActive ? .accentColor : .secondary
                context.stroke(path, with: .color(color), lineWidth: 1)
            }
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isActive ? Color.accentColor : .clear, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PressableButtonStyle())
        .help(type.displayName)
        .accessibilityLabel(type.displayName)
    }

    // MARK: - Swatches

    private var swatchRow: some View {
        HStack(spacing: 10) {
            ForEach(GuideColor.allCases) { swatch in
                Button {
                    state.color = swatch
                } label: {
                    Circle()
                        .fill(swatch.color)
                        .overlay(Circle().strokeBorder(.primary.opacity(0.2), lineWidth: 0.5))
                        .overlay(
                            Circle()
                                .strokeBorder(Color.accentColor, lineWidth: 2)
                                .padding(-3)
                                .opacity(state.color == swatch ? 1 : 0)
                        )
                        .frame(width: 18, height: 18)
                        .contentShape(Circle().inset(by: -4))
                }
                .buttonStyle(PressableButtonStyle())
                .help(swatch.displayName)
                .accessibilityLabel(swatch.displayName)
            }
        }
    }

    // MARK: - Controls

    private var controlRow: some View {
        HStack(spacing: 4) {
            controlButton("trapezoid.and.line.vertical", "Flip Horizontal") {
                state.orientation.flipHorizontal()
            }
            controlButton("trapezoid.and.line.horizontal", "Flip Vertical") {
                state.orientation.flipVertical()
            }
            controlButton("rotate.right", "Rotate 90°") {
                state.orientation.rotate90()
            }
            Button {
                state.isLocked.toggle()
            } label: {
                Image(systemName: state.isLocked ? "lock.fill" : "lock")
                    .frame(width: 30, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!state.isVisible)
            .help(state.isLocked ? "Unlock Overlay" : "Lock (click-through)")
            .accessibilityLabel(state.isLocked ? "Unlock Overlay" : "Lock Overlay")
            Spacer()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .frame(width: 30, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .help("Quit Golden Ratio")
            .accessibilityLabel("Quit Golden Ratio")
        }
    }

    private func controlButton(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 30, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!state.isVisible || state.isLocked)
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Instant 0.97 press-scale; no animation on release path beyond the default.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
