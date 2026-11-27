import Foundation

nonisolated extension Fighter {
    /// The number a special shows on its button, or nil when it has none (taunt).
    var specialValue: Int? {
        switch effect {
        case .heal: FightRules.healAmount(damage: damage)
        case .shield: FightRules.shieldAmount(damage: damage)
        case .buff: FightRules.buffBonus(damage: damage)
        case .burst: FightRules.burstDamage(damage: damage)
        case .dot: FightRules.damageOverTimePerTurn(damage: damage)
        case .taunt: nil
        }
    }

    /// What is on the card right now, for its status line and VoiceOver.
    var statusTexts: [String] {
        var texts: [String] = []
        if shield > 0 { texts.append(String(localized: "Schild \(shield)")) }
        if isTaunting { texts.append(String(localized: "zieht Angriffe an")) }
        if buff > 0 { texts.append(String(localized: "gestärkt +\(buff)")) }
        for tick in damageOverTime {
            texts.append(String(localized: "verliert \(tick.damagePerTurn) pro Zug"))
        }
        return texts
    }

    /// The card in a fight as one VoiceOver sentence.
    func accessibilityLabel(card: FighterCard, isStake: Bool, hasActed: Bool = false) -> String {
        var parts = [card.name, category.title]
        if isCrumpled {
            parts.append(String(localized: "zerknittert"))
        } else {
            parts.append(String(localized: "\(health) von \(maxHealth) Leben"))
            parts.append(contentsOf: statusTexts)
            if !canUseSpecial { parts.append(String(localized: "Spezialfähigkeit lädt")) }
        }
        if isStake { parts.append(String(localized: "Einsatz")) }
        if hasActed { parts.append(String(localized: "hat schon eine Aktion")) }
        return parts.joined(separator: ", ")
    }
}
