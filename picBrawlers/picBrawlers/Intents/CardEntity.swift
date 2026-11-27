import AppIntents
import CoreSpotlight
import OSLog

/// A card as Siri, Shortcuts and Spotlight see it.
struct CardEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Karte", numericFormat: "\(placeholder: .int) Karten")
    static let defaultQuery = CardQuery()

    let id: UUID

    @Property(title: "Name")
    var name: String

    @Property(title: "Kategorie")
    var category: String

    private let systemImage: String

    init(card: FighterCard) {
        id = card.id
        systemImage = card.category.systemImage
        name = card.name
        category = card.category.title
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(category)", image: .init(systemName: systemImage))
    }
}

/// Finds cards for intents and Spotlight. The logic lives in static functions so tests can pass a repository.
struct CardQuery: EntityStringQuery {
    @Dependency private var environment: AppEnvironment

    @MainActor
    func entities(for identifiers: [CardEntity.ID]) async throws -> [CardEntity] {
        try Self.entities(for: identifiers, in: environment.repository)
    }

    @MainActor
    func entities(matching string: String) async throws -> [CardEntity] {
        try Self.entities(matching: string, in: environment.repository)
    }

    @MainActor
    func suggestedEntities() async throws -> [CardEntity] {
        try Self.suggestedEntities(in: environment.repository)
    }

    @MainActor
    static func entities(for identifiers: [UUID], in repository: any CardRepository) throws -> [CardEntity] {
        try identifiers.compactMap { try repository.card(id: $0) }.map(CardEntity.init)
    }

    @MainActor
    static func entities(matching string: String, in repository: any CardRepository) throws -> [CardEntity] {
        try repository.allCards()
            .filter { $0.name.range(of: string, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
            .map(CardEntity.init)
    }

    @MainActor
    static func suggestedEntities(in repository: any CardRepository) throws -> [CardEntity] {
        try repository.allCards().map(CardEntity.init)
    }
}

/// Adds new cards to Spotlight and removes deleted ones, and refreshes the card names Siri knows.
final class SpotlightCardIndexer: CardIndexing {
    private static let logger = Logger(subsystem: "at.fhooe.picBrawlers", category: "Spotlight")

    func index(_ card: FighterCard) {
        let entity = CardEntity(card: card)
        Task {
            do {
                try await CSSearchableIndex.default().indexAppEntities([entity])
            } catch {
                Self.logger.error("Indexing a card failed: \(String(describing: error), privacy: .public)")
            }
            PicBrawlersShortcuts.updateAppShortcutParameters()
        }
    }

    func remove(id: UUID) {
        Task {
            do {
                try await CSSearchableIndex.default().deleteAppEntities(identifiedBy: [id], ofType: CardEntity.self)
            } catch {
                Self.logger.error("Removing a card from Spotlight failed: \(String(describing: error), privacy: .public)")
            }
            PicBrawlersShortcuts.updateAppShortcutParameters()
        }
    }
}
