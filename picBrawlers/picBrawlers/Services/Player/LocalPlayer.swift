import Foundation

/// The player on this phone. Until Game Center sign-in exists (Phase 4), a random ID created on first
/// launch marks the cards this player created and owns.
nonisolated enum LocalPlayer {
    private static let key = "localPlayerID"

    static func id(in defaults: UserDefaults = .standard) -> String {
        if let id = defaults.string(forKey: key) { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: key)
        return id
    }
}
