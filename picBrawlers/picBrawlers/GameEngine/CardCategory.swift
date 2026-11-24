/// A card's role in a fight. It decides the stat ranges and which special effects the card may have.
nonisolated enum CardCategory: String, CaseIterable, Codable, Sendable {
    case tank
    case damageDealer
    case support
}
