import Foundation
import SwiftData

/// How a card is stored. Ready for iCloud sync: every property has a default and nothing is unique,
/// which SwiftData's CloudKit sync requires. Only the repository sees this type.
@Model
final class CardRecord {
    var id: UUID = UUID()
    var name: String = ""
    var categoryRaw: String = CardCategory.tank.rawValue
    var health: Int = 0
    var damage: Int = 0
    var attackName: String = ""
    var attackDescription: String = ""
    var specialName: String = ""
    var specialDescription: String = ""
    var specialEffectRaw: String = SpecialEffect.taunt.rawValue
    var weaknesses: [String] = []
    var photoDescription: String = ""
    @Attribute(.externalStorage) var imageData: Data?
    var creatorID: String = ""
    var ownerID: String = ""
    var createdAt: Date = Date.distantPast

    init(_ card: FighterCard) {
        update(from: card)
    }

    func update(from card: FighterCard) {
        id = card.id
        name = card.name
        categoryRaw = card.category.rawValue
        health = card.stats.health
        damage = card.stats.damage
        attackName = card.attack.name
        attackDescription = card.attack.description
        specialName = card.special.name
        specialDescription = card.special.description
        specialEffectRaw = card.special.effect.rawValue
        weaknesses = card.weaknesses
        photoDescription = card.photoDescription
        imageData = card.imageData
        creatorID = card.creatorID
        ownerID = card.ownerID
        createdAt = card.createdAt
    }

    /// The stored card. Unknown raw values (from a newer app version, say) fall back to safe defaults.
    var card: FighterCard {
        let category = CardCategory(rawValue: categoryRaw) ?? .tank
        let storedEffect = SpecialEffect(rawValue: specialEffectRaw)
        let effect = storedEffect.flatMap { category.allowedEffects.contains($0) ? $0 : nil } ?? category.allowedEffects[0]
        return FighterCard(
            id: id,
            name: name,
            category: category,
            stats: CardStats(health: health, damage: damage),
            attack: FighterCard.Move(name: attackName, description: attackDescription),
            special: FighterCard.Special(name: specialName, description: specialDescription, effect: effect),
            weaknesses: weaknesses,
            photoDescription: photoDescription,
            imageData: imageData,
            creatorID: creatorID,
            ownerID: ownerID,
            createdAt: createdAt
        )
    }
}

extension ModelContainer {
    /// The app's store. iCloud sync is switched on in Phase 3; until then the store stays on the device.
    static func picBrawlers(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        return try ModelContainer(for: CardRecord.self, configurations: configuration)
    }
}
