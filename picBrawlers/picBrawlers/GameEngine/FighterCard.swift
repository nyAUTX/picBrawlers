import Foundation

/// Health and damage, rolled once when the card is created.
nonisolated struct CardStats: Hashable, Codable, Sendable {
    var health: Int
    var damage: Int
}

/// A fighter card as the game sees it. The repository stores it; the views show it.
nonisolated struct FighterCard: Identifiable, Hashable, Sendable {
    /// An attack: a name and a line of flavor text, both written by the AI.
    struct Move: Hashable, Codable, Sendable {
        var name: String
        var description: String
    }

    /// A special ability: AI-written text plus an effect from the closed list.
    struct Special: Hashable, Codable, Sendable {
        var name: String
        var description: String
        var effect: SpecialEffect
    }

    /// Stays the same when the card changes phones.
    let id: UUID
    var name: String
    var category: CardCategory
    var stats: CardStats
    var attack: Move
    var special: Special
    /// Fun facts with no effect in a fight.
    var weaknesses: [String]
    /// A short description of the photo for VoiceOver.
    var photoDescription: String
    /// The prepared photo (JPEG, at most `PhotoProcessor.maxPixelSize` on its long side).
    var imageData: Data?
    var creatorID: String
    var ownerID: String
    var createdAt: Date
}

/// The text the AI writes for a card. Everything here is flavor; numbers come from the engine.
nonisolated struct CardText: Hashable, Sendable {
    var attack: FighterCard.Move
    var special: FighterCard.Special
    var weaknesses: [String]
    var photoDescription: String
}
