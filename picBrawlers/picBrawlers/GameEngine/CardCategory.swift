/// A card's role in a fight. It decides the stat ranges and which special effects the card may have.
nonisolated enum CardCategory: String, CaseIterable, Codable, Sendable {
    case tank
    case damageDealer
    case support

    /// First draft from the plan, to be balanced in playtests.
    var healthRange: ClosedRange<Int> {
        switch self {
        case .tank: 130...170
        case .damageDealer: 60...90
        case .support: 90...110
        }
    }

    var damageRange: ClosedRange<Int> {
        switch self {
        case .tank: 10...20
        case .damageDealer: 30...45
        case .support: 12...22
        }
    }

    /// The special effects a card of this category may have. The first one is the fallback.
    var allowedEffects: [SpecialEffect] {
        switch self {
        case .tank: [.taunt, .shield]
        case .damageDealer: [.burst, .dot]
        case .support: [.heal, .shield, .buff]
        }
    }
}

/// What a special ability does in a fight. The AI picks one from this closed list; the engine sets the numbers.
nonisolated enum SpecialEffect: String, CaseIterable, Codable, Sendable {
    case heal
    case shield
    case buff
    case burst
    case dot
    case taunt
}
