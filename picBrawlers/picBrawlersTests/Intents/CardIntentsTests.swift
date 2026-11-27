import Foundation
import Testing
@testable import picBrawlers

@Suite("Card entity and query")
@MainActor
struct CardQueryTests {
    private let oma = FighterCard.sample(name: "Oma Gerti", createdAt: Date(timeIntervalSince1970: 1))
    private let kevin = FighterCard.sample(name: "Kevin", category: .damageDealer, createdAt: Date(timeIntervalSince1970: 2))

    @Test func anEntityCarriesTheCardsIDNameAndCategory() {
        let entity = CardEntity(card: kevin)
        #expect(entity.id == kevin.id)
        #expect(entity.name == "Kevin")
        #expect(entity.category == "Damage Dealer")
    }

    @Test func findsEntitiesByIDAndSkipsMissingOnes() throws {
        let repository = InMemoryCardRepository([oma, kevin])
        let entities = try CardQuery.entities(for: [kevin.id, UUID()], in: repository)
        #expect(entities.map(\.id) == [kevin.id])
    }

    @Test func suggestsAllCardsNewestFirst() throws {
        let repository = InMemoryCardRepository([oma, kevin])
        #expect(try CardQuery.suggestedEntities(in: repository).map(\.id) == [kevin.id, oma.id])
    }

    @Test func searchesNamesIgnoringCaseAndAccents() throws {
        let repository = InMemoryCardRepository([oma, kevin])
        #expect(try CardQuery.entities(matching: "gerti", in: repository).map(\.id) == [oma.id])
        #expect(try CardQuery.entities(matching: "KÉV", in: repository).map(\.id) == [kevin.id])
        #expect(try CardQuery.entities(matching: "Bello", in: repository).isEmpty)
    }
}

@Suite("Card intents")
@MainActor
struct CardIntentsTests {
    @Test func openCardShowsTheCard() {
        let router = AppRouter()
        let card = FighterCard.sample()
        OpenCardIntent.open(CardEntity(card: card), with: router)
        #expect(router.collectionPath == [card.id])
    }

    @Test func showCollectionShowsTheCollection() {
        let router = AppRouter()
        router.selectedTab = .fights
        ShowCollectionIntent.show(with: router)
        #expect(router.selectedTab == .collection)
    }

    @Test func createCardOpensTheCreatorWithThePhoto() {
        let router = AppRouter()
        CreateCardIntent.openCreator(photo: Data([4, 2]), with: router)
        #expect(router.creator?.photo == Data([4, 2]))
    }

    @Test func createCardWithoutAPhotoOpensAnEmptyCreator() {
        let router = AppRouter()
        CreateCardIntent.openCreator(photo: nil, with: router)
        #expect(router.creator != nil)
        #expect(router.creator?.photo == nil)
    }

    @Test func offersAShortcutForEachMainAction() {
        #expect(PicBrawlersShortcuts.appShortcuts.count == 3)
    }
}
