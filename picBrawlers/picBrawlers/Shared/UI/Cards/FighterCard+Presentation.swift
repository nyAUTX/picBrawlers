import Foundation

nonisolated extension FighterCard {
    /// The card as one VoiceOver sentence, e.g.
    /// "Oma Gerti, Tank, 150 Leben, 15 Schaden, Angriff: Gulaschkanone, Spezialfähigkeit: Kittelschürze".
    func accessibilityLabel(isCrumpled: Bool) -> String {
        var parts = [
            name,
            category.title,
            String(localized: "\(stats.health) Leben"),
            String(localized: "\(stats.damage) Schaden"),
            String(localized: "Angriff: \(attack.name)"),
            String(localized: "Spezialfähigkeit: \(special.name)"),
        ]
        if !photoDescription.isEmpty { parts.append(String(localized: "Foto: \(photoDescription)")) }
        if isCrumpled { parts.append(String(localized: "zerknittert")) }
        return parts.joined(separator: ", ")
    }
}

nonisolated extension SpecialEffect {
    /// What the effect does, in the player's words.
    var title: String {
        switch self {
        case .heal: String(localized: "Heilt")
        case .shield: String(localized: "Schützt")
        case .buff: String(localized: "Stärkt")
        case .burst: String(localized: "Großer Treffer")
        case .dot: String(localized: "Schaden über Zeit")
        case .taunt: String(localized: "Zieht Angriffe an")
        }
    }

    var systemImage: String {
        switch self {
        case .heal: "bandage.fill"
        case .shield: "shield.lefthalf.filled"
        case .buff: "arrow.up.circle.fill"
        case .burst: "burst.fill"
        case .dot: "timer"
        case .taunt: "megaphone.fill"
        }
    }
}

nonisolated extension CardCategory {
    /// One line on what the category is good at, shown when picking it.
    var summary: String {
        switch self {
        case .tank: String(localized: "Viel Leben, wenig Schaden. Schützt sich und zieht Angriffe an.")
        case .damageDealer: String(localized: "Wenig Leben, viel Schaden. Teilt harte Treffer aus.")
        case .support: String(localized: "Mittleres Leben. Heilt, schützt oder stärkt andere Karten.")
        }
    }
}
