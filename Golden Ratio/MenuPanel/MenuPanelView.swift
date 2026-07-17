import SwiftUI
import AppKit
import KeyboardShortcuts

struct MenuPanelView: View {
    let state: OverlayState
    /// Opens the welcome & settings window (owned by the app model).
    let openSettings: () -> Void

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
            state.toggle(type)
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
        .buttonStyle(PressScaleButtonStyle())
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
                .buttonStyle(PressScaleButtonStyle())
                .help(swatch.displayName)
                .accessibilityLabel(swatch.displayName)
            }
        }
    }

    // MARK: - Controls

    private var controlRow: some View {
        HStack(spacing: 4) {
            controlButton("trapezoid.and.line.vertical",
                          help: helpText("Flip Horizontal", shortcut: .flipHorizontal),
                          disabled: !state.isVisible || state.isLocked) {
                state.orientation.flipHorizontal()
            }
            controlButton("trapezoid.and.line.horizontal",
                          help: helpText("Flip Vertical", shortcut: .flipVertical),
                          disabled: !state.isVisible || state.isLocked) {
                state.orientation.flipVertical()
            }
            controlButton("rotate.right",
                          help: helpText("Rotate 90°", shortcut: .rotateGuide),
                          disabled: !state.isVisible || state.isLocked) {
                state.orientation.rotate90()
            }
            controlButton(state.isLocked ? "lock.fill" : "lock",
                          help: helpText(
                              state.isLocked ? "Unlock Overlay" : "Lock (click-through)",
                              shortcut: .toggleLock
                          ),
                          accessibility: state.isLocked ? "Unlock Overlay" : "Lock Overlay",
                          disabled: !state.isVisible) {
                state.isLocked.toggle()
            }
            Spacer()
            controlButton("gearshape", help: "Settings") {
                openSettings()
            }
            controlButton("power", help: "Quit Golden Ratio") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    /// Shared icon button for the control row. `accessibility` defaults to
    /// `help`; `disabled` defaults to always-enabled (used by Quit).
    private func controlButton(
        _ symbol: String,
        help: String,
        accessibility: String? = nil,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 30, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(disabled)
        .help(help)
        .accessibilityLabel(accessibility ?? help)
    }
}
