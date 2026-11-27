import CryptoKit
import Foundation

/// The two players of a match. The host sent the invite, so both phones agree on who is who.
nonisolated enum MatchSide: String, CaseIterable, Codable, Sendable {
    case host
    case guest

    var opponent: MatchSide { self == .host ? .guest : .host }
}

/// Points at one card in a match.
nonisolated struct FighterRef: Hashable, Codable, Sendable {
    var side: MatchSide
    var cardID: UUID
}

/// Damage that ticks at the start of the victim's turns.
nonisolated struct DamageOverTime: Hashable, Codable, Sendable {
    /// The card that applied it. A second application by the same card refreshes it instead of stacking.
    var sourceID: UUID
    var damagePerTurn: Int
    var turnsLeft: Int
}

/// A card's state during a fight. Only what the rules need: no texts, no photo.
nonisolated struct Fighter: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let category: CardCategory
    let effect: SpecialEffect
    let maxHealth: Int
    let damage: Int
    var health: Int
    /// Absorbs damage before health. Lasts until the start of its owner's next turn.
    var shield = 0
    /// Added to this card's next attack or burst, then used up.
    var buff = 0
    /// Attacks must target this card. Lasts until the start of its owner's next turn.
    var isTaunting = false
    var damageOverTime: [DamageOverTime] = []
    /// Own turns still to start before the special can be used again.
    var specialReadyIn = 0

    init(card: FighterCard) {
        id = card.id
        category = card.category
        effect = card.special.effect
        maxHealth = card.stats.health
        damage = card.stats.damage
        health = card.stats.health
    }

    var isCrumpled: Bool { health == 0 }
    var canUseSpecial: Bool { specialReadyIn == 0 }

    /// Back to fresh: full health and no effects.
    func ironed() -> Fighter {
        var fresh = self
        fresh.health = maxHealth
        fresh.clearEffects()
        fresh.specialReadyIn = 0
        return fresh
    }

    mutating func clearEffects() {
        shield = 0
        buff = 0
        isTaunting = false
        damageOverTime = []
    }
}

/// One player's side of a match.
nonisolated struct Team: Hashable, Codable, Sendable {
    let playerID: String
    var fighters: [Fighter]
    /// The card the winner takes if this team loses.
    let stakeID: UUID
    var skippedTurns = 0

    var standing: [Fighter] { fighters.filter { !$0.isCrumpled } }
    var isDefeated: Bool { standing.isEmpty }
}

/// What a player brings to a match.
nonisolated struct TeamSetup: Sendable {
    var playerID: String
    var cards: [FighterCard]
    var stakeID: UUID
}

nonisolated enum MatchSetupError: Error, Equatable, Sendable {
    case wrongTeamSize(MatchSide)
    case stakeNotInTeam(MatchSide)
    /// Stats outside the category's ranges or an effect the category may not have.
    case invalidCard(UUID)
    case duplicateCard(UUID)
}

nonisolated enum WinReason: String, Codable, Sendable {
    case knockout
    case resignation
    case timeouts
}

nonisolated struct MatchOutcome: Hashable, Codable, Sendable {
    var winner: MatchSide
    var reason: WinReason
}

/// What happens after a match: the loser's staked card goes to the winner.
nonisolated struct MatchResult: Hashable, Sendable {
    var winner: MatchSide
    var reason: WinReason
    var stakedCardID: UUID
    var fromPlayerID: String
    var toPlayerID: String
}

/// The whole state of a match. Both phones hold one and change it only through `FightEngine`.
nonisolated struct MatchState: Hashable, Codable, Sendable {
    var host: Team
    var guest: Team
    /// Counts every turn of both players, starting at 1.
    var turn = 1
    var activeSide: MatchSide
    var outcome: MatchOutcome?

    /// Checks both teams and sets up turn 1. Cards from the other phone are untrusted, so everything is validated.
    static func start(host: TeamSetup, guest: TeamSetup, firstSide: MatchSide) throws(MatchSetupError) -> MatchState {
        var seen = Set<UUID>()
        for (side, setup) in [(MatchSide.host, host), (.guest, guest)] {
            guard setup.cards.count == FightRules.teamSize else { throw .wrongTeamSize(side) }
            guard setup.cards.contains(where: { $0.id == setup.stakeID }) else { throw .stakeNotInTeam(side) }
            for card in setup.cards {
                guard seen.insert(card.id).inserted else { throw .duplicateCard(card.id) }
                guard isValid(card) else { throw .invalidCard(card.id) }
            }
        }
        return MatchState(host: team(from: host), guest: team(from: guest), activeSide: firstSide)
    }

    private static func isValid(_ card: FighterCard) -> Bool {
        card.category.healthRange.contains(card.stats.health)
            && card.category.damageRange.contains(card.stats.damage)
            && card.category.allowedEffects.contains(card.special.effect)
    }

    private static func team(from setup: TeamSetup) -> Team {
        Team(playerID: setup.playerID, fighters: setup.cards.map { Fighter(card: $0) }, stakeID: setup.stakeID)
    }

    subscript(side: MatchSide) -> Team {
        get { side == .host ? host : guest }
        set { if side == .host { host = newValue } else { guest = newValue } }
    }

    func fighter(_ ref: FighterRef) -> Fighter? {
        self[ref.side].fighters.first { $0.id == ref.cardID }
    }

    /// Where a card of this match is, or nil if it isn't in the match.
    func ref(of cardID: UUID) -> FighterRef? {
        MatchSide.allCases
            .first { side in self[side].fighters.contains { $0.id == cardID } }
            .map { FighterRef(side: $0, cardID: cardID) }
    }

    mutating func update(_ ref: FighterRef, _ change: (inout Fighter) -> Void) {
        guard let index = self[ref.side].fighters.firstIndex(where: { $0.id == ref.cardID }) else { return }
        change(&self[ref.side].fighters[index])
    }

    /// How many cards must act this turn: 2, or 1 when only one is still standing.
    var requiredActionCount: Int {
        min(FightRules.actionsPerTurn, self[activeSide].standing.count)
    }

    var isOver: Bool { outcome != nil }

    var result: MatchResult? {
        guard let outcome else { return nil }
        let loser = self[outcome.winner.opponent]
        return MatchResult(
            winner: outcome.winner, reason: outcome.reason, stakedCardID: loser.stakeID,
            fromPlayerID: loser.playerID, toPlayerID: self[outcome.winner].playerID
        )
    }

    /// Every card back to fresh, for the ironing after the fight.
    func ironed() -> MatchState {
        var state = self
        for side in MatchSide.allCases {
            state[side].fighters = state[side].fighters.map { $0.ironed() }
        }
        return state
    }

    /// SHA-256 of the canonical encoding, as hex. Two phones compare it after every turn to catch desyncs or tampering.
    var stateHash: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        // Encoding plain structs of ints, strings, bools and arrays cannot fail.
        let data = (try? encoder.encode(self)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
