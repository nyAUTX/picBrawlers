import Foundation

/// What a fighter card shows. A stand-in until the real `Card` model exists.
nonisolated struct FighterCardContent: Identifiable, Equatable, Sendable {
    enum MoveKind: Equatable, Sendable {
        case attack
        case special

        var title: String {
            switch self {
            case .attack: String(localized: "Angriff")
            case .special: String(localized: "Spezialfähigkeit")
            }
        }
    }

    let id: UUID
    let name: String
    let category: CardCategory
    let health: Int
    let damage: Int
    let moveKind: MoveKind
    let moveName: String

    /// The card as one VoiceOver sentence, e.g. "Oma Gerti, Tank, 150 Leben, 15 Schaden, Angriff: Gulaschkanone".
    func accessibilityLabel(isCrumpled: Bool) -> String {
        var parts = [
            name,
            category.title,
            String(localized: "\(health) Leben"),
            String(localized: "\(damage) Schaden"),
            "\(moveKind.title): \(moveName)",
        ]
        if isCrumpled { parts.append(String(localized: "zerknittert")) }
        return parts.joined(separator: ", ")
    }
}

extension FighterCardContent {
    /// Three example cards for previews and the effects screen.
    nonisolated static let demoLineup: [FighterCardContent] = [
        FighterCardContent(
            id: UUID(uuidString: "6F1C2B4A-0001-4000-8000-000000000001")!,
            name: "Oma Gerti", category: .tank, health: 150, damage: 15,
            moveKind: .attack, moveName: "Gulaschkanone"
        ),
        FighterCardContent(
            id: UUID(uuidString: "6F1C2B4A-0002-4000-8000-000000000002")!,
            name: "Kevin", category: .damageDealer, health: 80, damage: 42,
            moveKind: .attack, moveName: "Fußball ins Gesicht"
        ),
        FighterCardContent(
            id: UUID(uuidString: "6F1C2B4A-0003-4000-8000-000000000003")!,
            name: "Bello", category: .support, health: 110, damage: 20,
            moveKind: .special, moveName: "Stoßlüften"
        ),
    ]
}
