/// Every number in a fight. The AI only picks an effect type; the values come from here and the card's stats.
/// First draft, to be balanced in playtests. Integer math only, so both phones always compute the same result.
nonisolated enum FightRules {
    static let teamSize = 3
    /// How many different cards act in one turn (fewer if fewer are still standing).
    static let actionsPerTurn = 2
    static let turnDuration: Duration = .seconds(30)
    /// For VoiceOver and Switch Control users, who need longer to move through the board.
    static let assistedTurnDuration: Duration = .seconds(60)
    /// Timed-out turns in a row that count as a loss.
    static let maxSkippedTurnsInARow = 3
    /// Own turns a card must wait after using its special before it can use it again.
    static let specialCooldownTurns = 1

    static func healAmount(damage: Int) -> Int { damage * 2 }
    static func shieldAmount(damage: Int) -> Int { damage * 2 }
    static func buffBonus(damage: Int) -> Int { damage }
    static func burstDamage(damage: Int) -> Int { damage * 2 }
    static func damageOverTimePerTurn(damage: Int) -> Int { max(1, damage / 2) }
    /// The victim's turns on which damage over time ticks.
    static let damageOverTimeTurns = 3
    /// How much less damage a taunting card takes.
    static let tauntDamageReductionPercent = 30

    static func reducedByTaunt(_ amount: Int) -> Int {
        amount * (100 - tauntDamageReductionPercent) / 100
    }
}
