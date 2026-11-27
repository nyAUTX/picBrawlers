import Foundation
import SwiftData

/// Stores the player's own cards. ViewModels use this instead of SwiftData.
protocol CardRepository: AnyObject {
    /// All cards, newest first.
    func allCards() throws -> [FighterCard]
    func card(id: UUID) throws -> FighterCard?
    /// Inserts the card, or updates it if a card with its ID exists.
    func save(_ card: FighterCard) throws
    func delete(id: UUID) throws
}

final class SwiftDataCardRepository: CardRepository {
    /// Held strongly: a context whose container is gone traps on the next fetch.
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer) {
        self.container = container
    }

    func allCards() throws -> [FighterCard] {
        let descriptor = FetchDescriptor<CardRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor).map(\.card)
    }

    func card(id: UUID) throws -> FighterCard? {
        try record(id: id)?.card
    }

    func save(_ card: FighterCard) throws {
        if let record = try record(id: card.id) {
            record.update(from: card)
        } else {
            context.insert(CardRecord(card))
        }
        try context.save()
    }

    func delete(id: UUID) throws {
        guard let record = try record(id: id) else { return }
        context.delete(record)
        try context.save()
    }

    private func record(id: UUID) throws -> CardRecord? {
        var descriptor = FetchDescriptor<CardRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

/// Keeps Spotlight in step with the collection.
protocol CardIndexing: AnyObject {
    func index(_ card: FighterCard)
    func remove(id: UUID)
}

/// Wraps a repository and updates the Spotlight index after every successful change.
final class IndexedCardRepository: CardRepository {
    private let base: any CardRepository
    private let indexer: any CardIndexing

    init(base: any CardRepository, indexer: any CardIndexing) {
        self.base = base
        self.indexer = indexer
    }

    func allCards() throws -> [FighterCard] { try base.allCards() }
    func card(id: UUID) throws -> FighterCard? { try base.card(id: id) }

    func save(_ card: FighterCard) throws {
        try base.save(card)
        indexer.index(card)
    }

    func delete(id: UUID) throws {
        try base.delete(id: id)
        indexer.remove(id: id)
    }
}
