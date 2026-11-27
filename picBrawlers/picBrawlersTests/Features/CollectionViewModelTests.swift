import Foundation
import Testing
@testable import picBrawlers

@Suite("Collection view model")
@MainActor
struct CollectionViewModelTests {
    private let older = FighterCard.sample(name: "Oma Gerti", createdAt: Date(timeIntervalSince1970: 1))
    private let newer = FighterCard.sample(name: "Kevin", category: .damageDealer, createdAt: Date(timeIntervalSince1970: 2))

    @Test func startsLoading() {
        #expect(CollectionViewModel(repository: InMemoryCardRepository()).state == .loading)
    }

    @Test func noCardsIsTheEmptyState() {
        let viewModel = CollectionViewModel(repository: InMemoryCardRepository())
        viewModel.load()
        #expect(viewModel.state == .empty)
    }

    @Test func showsTheCardsNewestFirst() {
        let viewModel = CollectionViewModel(repository: InMemoryCardRepository([older, newer]))
        viewModel.load()
        #expect(viewModel.state == .loaded([newer, older]))
    }

    @Test func aFailedLoadShowsAnError() {
        let repository = InMemoryCardRepository()
        repository.failure = TestFailure()
        let viewModel = CollectionViewModel(repository: repository)
        viewModel.load()
        #expect(viewModel.state == .failed(AppError(title: "Karten konnten nicht geladen werden", cause: .unexpected)))
    }

    @Test func deletingAsksFirstAndOnlyDeletesAfterConfirming() {
        let repository = InMemoryCardRepository([older, newer])
        let viewModel = CollectionViewModel(repository: repository)
        viewModel.load()

        viewModel.requestDelete(older)
        #expect(viewModel.pendingDeletion == older)
        #expect(repository.cards.count == 2)

        viewModel.confirmDelete()
        #expect(viewModel.pendingDeletion == nil)
        #expect(repository.cards[older.id] == nil)
        #expect(viewModel.state == .loaded([newer]))
    }

    @Test func deletingTheLastCardShowsTheEmptyState() {
        let viewModel = CollectionViewModel(repository: InMemoryCardRepository([older]))
        viewModel.load()
        viewModel.requestDelete(older)
        viewModel.confirmDelete()
        #expect(viewModel.state == .empty)
    }

    @Test func cancellingTheDeletionKeepsTheCard() {
        let repository = InMemoryCardRepository([older])
        let viewModel = CollectionViewModel(repository: repository)
        viewModel.load()
        viewModel.requestDelete(older)
        viewModel.cancelDelete()
        #expect(viewModel.pendingDeletion == nil)
        #expect(repository.cards.count == 1)
    }

    @Test func aFailedDeletionKeepsTheCardAndShowsAnError() {
        let repository = InMemoryCardRepository([older])
        let viewModel = CollectionViewModel(repository: repository)
        viewModel.load()
        viewModel.requestDelete(older)
        repository.failure = TestFailure()
        viewModel.confirmDelete()
        #expect(viewModel.deleteError == AppError(title: "Karte konnte nicht gelöscht werden", cause: .unexpected))
        #expect(viewModel.state == .loaded([older]))
    }
}

@Suite("Card detail view model")
@MainActor
struct CardDetailViewModelTests {
    private let card = FighterCard.sample()

    @Test func loadsTheCard() {
        let viewModel = CardDetailViewModel(cardID: card.id, repository: InMemoryCardRepository([card]))
        #expect(viewModel.state == .loading)
        viewModel.load()
        #expect(viewModel.state == .loaded(card))
    }

    @Test func aMissingCardIsTheEmptyState() {
        let viewModel = CardDetailViewModel(cardID: UUID(), repository: InMemoryCardRepository([card]))
        viewModel.load()
        #expect(viewModel.state == .empty)
    }

    @Test func aFailedLoadShowsAnError() {
        let repository = InMemoryCardRepository([card])
        repository.failure = TestFailure()
        let viewModel = CardDetailViewModel(cardID: card.id, repository: repository)
        viewModel.load()
        #expect(viewModel.state == .failed(AppError(title: "Karte konnte nicht geladen werden", cause: .unexpected)))
    }

    @Test func deletingRemovesTheCardAndClosesTheScreen() {
        let repository = InMemoryCardRepository([card])
        let viewModel = CardDetailViewModel(cardID: card.id, repository: repository)
        viewModel.load()
        viewModel.delete()
        #expect(repository.cards.isEmpty)
        #expect(viewModel.isDeleted)
    }

    @Test func aFailedDeletionShowsAnError() {
        let repository = InMemoryCardRepository([card])
        let viewModel = CardDetailViewModel(cardID: card.id, repository: repository)
        viewModel.load()
        repository.failure = TestFailure()
        viewModel.delete()
        #expect(!viewModel.isDeleted)
        #expect(viewModel.deleteError == AppError(title: "Karte konnte nicht gelöscht werden", cause: .unexpected))
    }
}

@Suite("App router")
@MainActor
struct AppRouterTests {
    @Test func startsOnTheCollection() {
        let router = AppRouter()
        #expect(router.selectedTab == .collection)
        #expect(router.collectionPath.isEmpty)
        #expect(router.creator == nil)
    }

    @Test func openingACardShowsItInTheCollection() {
        let router = AppRouter()
        let id = UUID()
        router.selectedTab = .trades
        router.openCreator()
        router.openCard(id: id)
        #expect(router.selectedTab == .collection)
        #expect(router.collectionPath == [id])
        #expect(router.creator == nil)
    }

    @Test func showingTheCollectionPopsToItsRoot() {
        let router = AppRouter()
        router.openCard(id: UUID())
        router.selectedTab = .fights
        router.showCollection()
        #expect(router.selectedTab == .collection)
        #expect(router.collectionPath.isEmpty)
    }

    @Test func openingTheCreatorCarriesThePhoto() {
        let router = AppRouter()
        router.openCreator(photo: Data([7]))
        #expect(router.selectedTab == .collection)
        #expect(router.creator?.photo == Data([7]))
    }
}
