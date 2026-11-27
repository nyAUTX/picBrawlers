import Foundation

extension FighterCard {
    /// Three example cards for previews and the effects screen.
    nonisolated static let demoLineup: [FighterCard] = [
        FighterCard(
            id: UUID(uuidString: "6F1C2B4A-0001-4000-8000-000000000001")!,
            name: "Oma Gerti", category: .tank,
            stats: CardStats(health: 150, damage: 15),
            attack: Move(name: "Gulaschkanone", description: "Feuert einen Schöpfer heißen Gulasch quer über den Tisch."),
            special: Special(name: "Kittelschürze", description: "Hält Flecken und Treffer ab.", effect: .shield),
            weaknesses: ["Spritpreis", "Rückwärts einparken"],
            photoDescription: "", imageData: nil,
            creatorID: "demo", ownerID: "demo", createdAt: Date(timeIntervalSince1970: 0)
        ),
        FighterCard(
            id: UUID(uuidString: "6F1C2B4A-0002-4000-8000-000000000002")!,
            name: "Kevin", category: .damageDealer,
            stats: CardStats(health: 80, damage: 42),
            attack: Move(name: "Fußball ins Gesicht", description: "Ein Volley aus kurzer Distanz, direkt auf die Nase."),
            special: Special(name: "Blutgrätsche", description: "Rutscht mit Anlauf in den Gegner.", effect: .burst),
            weaknesses: ["Schlagloch"],
            photoDescription: "", imageData: nil,
            creatorID: "demo", ownerID: "demo", createdAt: Date(timeIntervalSince1970: 0)
        ),
        FighterCard(
            id: UUID(uuidString: "6F1C2B4A-0003-4000-8000-000000000003")!,
            name: "Bello", category: .support,
            stats: CardStats(health: 110, damage: 20),
            attack: Move(name: "Kampfhund", description: "Bellt viel lauter, als er beißt."),
            special: Special(name: "Stoßlüften", description: "Fenster auf, frische Luft, alle sind wieder wach.", effect: .buff),
            weaknesses: ["Radfahrer", "Staubsauger"],
            photoDescription: "", imageData: nil,
            creatorID: "demo", ownerID: "demo", createdAt: Date(timeIntervalSince1970: 0)
        ),
    ]
}
