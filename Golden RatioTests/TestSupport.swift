import Foundation

/// Runs `body` with a private, empty UserDefaults suite and removes its
/// persistent domain before use and afterwards so tests don't leak plists.
/// Swift Testing has no per-test teardown for value-type suites, so cleanup
/// lives here. `nonisolated` so nonisolated test suites can call it too.
nonisolated func withFreshDefaults(_ body: (UserDefaults) -> Void) {
    let name = "GoldenRatioTests-\(UUID().uuidString)"
    let d = UserDefaults(suiteName: name)!
    d.removePersistentDomain(forName: name)
    defer { d.removePersistentDomain(forName: name) }
    body(d)
}
