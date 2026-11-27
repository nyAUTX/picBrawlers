import Foundation

/// Rolls a card's stats inside its category's ranges.
nonisolated enum StatRoller {
    static func roll(for category: CardCategory, using generator: inout some RandomNumberGenerator) -> CardStats {
        CardStats(
            health: Int.random(in: category.healthRange, using: &generator),
            damage: Int.random(in: category.damageRange, using: &generator)
        )
    }
}

/// The rules for a card's name.
nonisolated enum CardName {
    static let maxLength = 20

    enum Issue: Equatable, Sendable {
        case empty
        case tooLong
    }

    /// Trims the ends and collapses runs of whitespace into one space.
    static func normalized(_ raw: String) -> String {
        raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func issue(for raw: String) -> Issue? {
        let name = normalized(raw)
        if name.isEmpty { return .empty }
        if name.count > maxLength { return .tooLong }
        return nil
    }
}

/// Builds a new card from the player's input and the AI's text. The engine owns the numbers and
/// checks the AI's choices, so a card stays balanced whatever the AI returns.
nonisolated enum CardFactory {
    static let maxWeaknesses = 3

    static func makeCard(
        id: UUID,
        name: String,
        category: CardCategory,
        text: CardText,
        imageData: Data?,
        playerID: String,
        createdAt: Date,
        using generator: inout some RandomNumberGenerator
    ) -> FighterCard {
        var special = text.special
        if !category.allowedEffects.contains(special.effect) {
            special.effect = category.allowedEffects[0]
        }
        special.name = CardName.normalized(special.name)

        let weaknesses = text.weaknesses
            .map(CardName.normalized)
            .filter { !$0.isEmpty }
            .prefix(maxWeaknesses)

        return FighterCard(
            id: id,
            name: CardName.normalized(name),
            category: category,
            stats: StatRoller.roll(for: category, using: &generator),
            attack: FighterCard.Move(name: CardName.normalized(text.attack.name), description: text.attack.description),
            special: special,
            weaknesses: Array(weaknesses),
            photoDescription: text.photoDescription,
            imageData: imageData,
            creatorID: playerID,
            ownerID: playerID,
            createdAt: createdAt
        )
    }
}

/// A small, fast, seedable random number generator (SplitMix64). Tests use it for deterministic rolls,
/// and both phones can share a seed for fights later.
nonisolated struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Wraps any generator in a concrete type, so code can store a generator chosen at runtime
/// (seeded in tests, the system's in the app) and still pass it `inout` to the standard library.
nonisolated struct AnyRandomNumberGenerator: RandomNumberGenerator {
    private var base: any RandomNumberGenerator

    init(_ base: any RandomNumberGenerator) {
        self.base = base
    }

    mutating func next() -> UInt64 {
        base.next()
    }
}
