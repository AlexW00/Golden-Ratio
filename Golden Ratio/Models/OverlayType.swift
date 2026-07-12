import Foundation

nonisolated enum OverlayType: String, Codable, CaseIterable, Identifiable, Sendable {
    case thirds
    case phiGrid
    case goldenSpiral
    case diagonals
    case harmonicArmature
    case centerCross

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .thirds: "Rule of Thirds"
        case .phiGrid: "Phi Grid"
        case .goldenSpiral: "Golden Spiral"
        case .diagonals: "Golden Diagonals"
        case .harmonicArmature: "Harmonic Armature"
        case .centerCross: "Center Cross"
        }
    }
}
