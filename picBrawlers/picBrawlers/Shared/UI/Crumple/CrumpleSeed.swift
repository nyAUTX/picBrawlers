import Foundation

/// Turns a card's ID into a stable shader seed, so the same card always crumples the same way
/// on every launch and every phone. (`hashValue` is randomized per launch, so it can't be used.)
nonisolated enum CrumpleSeed {
    static func seed(for id: UUID) -> Float {
        var hash: UInt32 = 2_166_136_261 // FNV-1a
        withUnsafeBytes(of: id.uuid) { bytes in
            for byte in bytes {
                hash ^= UInt32(byte)
                hash = hash &* 16_777_619
            }
        }
        return Float(hash % 997)
    }
}
