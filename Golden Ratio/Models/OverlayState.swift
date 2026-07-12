import SwiftUI
import Observation

nonisolated enum GuideColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case gold, white, black, red, blue, green

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .gold: Color(red: 1.00, green: 0.72, blue: 0.00)
        case .white: .white
        case .black: .black
        case .red: Color(red: 0.96, green: 0.26, blue: 0.21)
        case .blue: Color(red: 0.04, green: 0.52, blue: 1.00)
        case .green: Color(red: 0.20, green: 0.78, blue: 0.35)
        }
    }

    var displayName: String { rawValue.capitalized }
}

/// Single source of truth shared by the menu panel and the overlay window.
@MainActor
@Observable
final class OverlayState {
    var type: OverlayType { didSet { save() } }
    var color: GuideColor { didSet { save() } }
    var orientation: Orientation { didSet { save() } }
    var isVisible: Bool { didSet { save() } }
    /// Not persisted as `true`: a relaunch always starts unlocked so the user
    /// is never stranded with an untouchable overlay.
    var isLocked: Bool = false

    private let defaults: UserDefaults
    private static let key = "overlayState.v1"

    private struct Snapshot: Codable {
        var type: OverlayType
        var color: GuideColor
        var orientation: Orientation
        var isVisible: Bool
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            type = snap.type
            color = snap.color
            orientation = snap.orientation
            isVisible = snap.isVisible
        } else {
            type = .thirds
            color = .gold
            orientation = .identity
            isVisible = false
        }
    }

    private func save() {
        let snap = Snapshot(type: type, color: color, orientation: orientation, isVisible: isVisible)
        if let data = try? JSONEncoder().encode(snap) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
