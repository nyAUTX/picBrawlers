import Foundation

extension MatchEvent {
    /// The event as a German sentence for the turn log and VoiceOver. Nil for events the player
    /// doesn't need to read (the start of a turn).
    func text(names: [UUID: FighterCard], playerNames: [MatchSide: String] = [:]) -> String? {
        func name(_ ref: FighterRef) -> String { names[ref.cardID]?.name ?? String(localized: "Karte") }
        switch self {
        case let .hit(ref, _, healthLost, absorbed):
            if absorbed > 0 {
                return String(localized: "\(name(ref)) verliert \(healthLost) Leben, der Schild fängt \(absorbed) ab")
            }
            return String(localized: "\(name(ref)) verliert \(healthLost) Leben")
        case let .healed(ref, amount):
            return String(localized: "\(name(ref)) bekommt \(amount) Leben zurück")
        case let .shielded(ref, amount):
            return String(localized: "\(name(ref)) bekommt einen Schild für \(amount) Schaden")
        case let .buffed(ref, bonus):
            return String(localized: "\(name(ref)) trifft beim nächsten Mal \(bonus) stärker")
        case let .taunting(ref):
            return String(localized: "\(name(ref)) zieht alle Angriffe auf sich")
        case let .poisoned(ref, damage, turns):
            return String(localized: "\(name(ref)) verliert \(turns) Züge lang je \(damage) Leben")
        case let .crumpled(ref):
            return String(localized: "\(name(ref)) ist zerknittert")
        case let .turnSkipped(side):
            return String(localized: "Zeit abgelaufen: \(playerNames[side] ?? "") setzt aus")
        case .turnStarted, .matchEnded:
            return nil
        }
    }
}
