import CoreGraphics

/// How far the crumple shader may push the card face. It grows with the card, but stops at a cap so a
/// full-width card still reads: name, stats and attack must stay legible on a crumpled card.
nonisolated enum CrumpleWarp {
    /// Share of the card width a small card is warped by.
    static let relativeStrength = 0.055
    /// The largest offset in points, whatever the card size.
    static let maximumStrength = 10.0

    static func strength(forCardWidth width: CGFloat) -> Double {
        min(Double(width) * relativeStrength, maximumStrength)
    }
}
