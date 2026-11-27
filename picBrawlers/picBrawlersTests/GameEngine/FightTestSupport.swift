import Foundation
@testable import picBrawlers

/// A card for fight tests. Stats default to values inside the category's ranges.
func fightCard(
    _ category: CardCategory,
    health: Int? = nil,
    damage: Int? = nil,
    effect: SpecialEffect? = nil,
    id: UUID = UUID()
) -> FighterCard {
    let defaults: CardStats = switch category {
    case .tank: CardStats(health: 150, damage: 15)
    case .damageDealer: CardStats(health: 80, damage: 40)
    case .support: CardStats(health: 100, damage: 20)
    }
    return FighterCard(
        id: id, name: "Karte", category: category,
        stats: CardStats(health: health ?? defaults.health, damage: damage ?? defaults.damage),
        attack: .init(name: "Angriff", description: ""),
        special: .init(name: "Spezial", description: "", effect: effect ?? category.allowedEffects[0]),
        weaknesses: [], photoDescription: "", imageData: nil,
        creatorID: "creator", ownerID: "owner", createdAt: Date(timeIntervalSince1970: 0)
    )
}

/// Two teams of tank, damage dealer and support. The host stakes its tank, the guest its damage dealer.
struct FightFixture {
    var hostCards: [FighterCard]
    var guestCards: [FighterCard]

    init(
        hostTank: SpecialEffect = .taunt, hostSupport: SpecialEffect = .heal, hostDealer: SpecialEffect = .burst,
        guestTank: SpecialEffect = .taunt, guestSupport: SpecialEffect = .heal, guestDealer: SpecialEffect = .burst
    ) {
        hostCards = [fightCard(.tank, effect: hostTank), fightCard(.damageDealer, effect: hostDealer), fightCard(.support, effect: hostSupport)]
        guestCards = [fightCard(.tank, effect: guestTank), fightCard(.damageDealer, effect: guestDealer), fightCard(.support, effect: guestSupport)]
    }

    var hostTank: UUID { hostCards[0].id }
    var hostDealer: UUID { hostCards[1].id }
    var hostSupport: UUID { hostCards[2].id }
    var guestTank: UUID { guestCards[0].id }
    var guestDealer: UUID { guestCards[1].id }
    var guestSupport: UUID { guestCards[2].id }

    func start(first: MatchSide = .host) throws -> MatchState {
        try MatchState.start(
            host: TeamSetup(playerID: "host", cards: hostCards, stakeID: hostTank),
            guest: TeamSetup(playerID: "guest", cards: guestCards, stakeID: guestDealer),
            firstSide: first
        )
    }
}

func host(_ id: UUID) -> FighterRef { FighterRef(side: .host, cardID: id) }
func guest(_ id: UUID) -> FighterRef { FighterRef(side: .guest, cardID: id) }

func attack(_ actor: UUID, _ target: FighterRef) -> FightAction {
    FightAction(actor: actor, move: .attack, target: target)
}

func special(_ actor: UUID, _ target: FighterRef) -> FightAction {
    FightAction(actor: actor, move: .special, target: target)
}

extension MatchState {
    /// Plays a turn and returns only the new state.
    func playing(_ actions: FightAction...) throws -> MatchState {
        try FightEngine.play(actions, in: self).state
    }

    func health(_ ref: FighterRef) -> Int? { fighter(ref)?.health }

    /// Puts a card at a given health, crumpling it at 0, to set up a situation directly.
    mutating func setHealth(_ health: Int, of ref: FighterRef) {
        update(ref) { $0.health = health }
    }

    mutating func resetSkippedTurns() {
        for side in MatchSide.allCases { self[side].skippedTurns = 0 }
    }
}
