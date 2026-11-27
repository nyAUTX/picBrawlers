import Foundation
@testable import picBrawlers

struct TestFailure: Error, Equatable {}

/// A repository kept in a dictionary. Set `failure` to make every call throw.
@MainActor
final class InMemoryCardRepository: CardRepository {
    private(set) var cards: [UUID: FighterCard]
    var failure: (any Error)?

    init(_ cards: [FighterCard] = []) {
        self.cards = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
    }

    func allCards() throws -> [FighterCard] {
        if let failure { throw failure }
        return cards.values.sorted { $0.createdAt > $1.createdAt }
    }

    func card(id: UUID) throws -> FighterCard? {
        if let failure { throw failure }
        return cards[id]
    }

    func save(_ card: FighterCard) throws {
        if let failure { throw failure }
        cards[card.id] = card
    }

    func delete(id: UUID) throws {
        if let failure { throw failure }
        cards[id] = nil
    }
}

/// Returns fixed text. It can throw, or hold the call until the test releases it.
@MainActor
final class FakeCardGenerationService: CardGenerationService {
    var analysis = PhotoAnalysis(labels: ["Kochlöffel"], description: "Frau mit Kochlöffel")
    var text = CardText.sample
    var failure: (any Error)?
    /// Called inside `analyze` and `inventText`, so tests can look at the screen state mid-generation.
    var onAnalyze: () -> Void = {}
    var onInvent: () -> Void = {}
    private(set) var requests: [CardGenerationRequest] = []

    private var gate: CheckedContinuation<Void, Never>?
    var holdsInvent = false

    func analyze(photo: Data) async throws -> PhotoAnalysis {
        onAnalyze()
        if let failure { throw failure }
        return analysis
    }

    func inventText(for request: CardGenerationRequest) async throws -> CardText {
        requests.append(request)
        onInvent()
        if holdsInvent {
            await withCheckedContinuation { gate = $0 }
        }
        if let failure { throw failure }
        return text
    }

    var isHeld: Bool { gate != nil }

    func release() {
        gate?.resume()
        gate = nil
    }
}

/// Passes the photo through, or throws.
struct FakePhotoProcessor: PhotoProcessing {
    var failure: (any Error)?

    func prepare(_ data: Data) async throws -> Data {
        if let failure { throw failure }
        return data + [0xFF]
    }
}

@MainActor
final class CardIndexingSpy: CardIndexing {
    private(set) var indexed: [UUID] = []
    private(set) var removed: [UUID] = []
    func index(_ card: FighterCard) { indexed.append(card.id) }
    func remove(id: UUID) { removed.append(id) }
}

extension CardText {
    static let sample = CardText(
        attack: .init(name: "Gulaschkanone", description: "Feuert einen Schöpfer heißen Gulasch."),
        special: .init(name: "Kittelschürze", description: "Hält Flecken und Treffer ab.", effect: .shield),
        weaknesses: ["Spritpreis", "Schlagloch"],
        photoDescription: "Frau mit Kochlöffel"
    )
}

extension FighterCard {
    static func sample(
        id: UUID = UUID(),
        name: String = "Oma Gerti",
        category: CardCategory = .tank,
        createdAt: Date = Date(timeIntervalSince1970: 0)
    ) -> FighterCard {
        FighterCard(
            id: id, name: name, category: category,
            stats: CardStats(health: 150, damage: 15),
            attack: CardText.sample.attack, special: CardText.sample.special,
            weaknesses: CardText.sample.weaknesses, photoDescription: CardText.sample.photoDescription,
            imageData: nil, creatorID: "player-1", ownerID: "player-1", createdAt: createdAt
        )
    }
}
