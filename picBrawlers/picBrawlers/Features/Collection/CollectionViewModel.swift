import Foundation
import Observation

/// The player's own cards.
@Observable
final class CollectionViewModel {
    private(set) var state: ViewState<[FighterCard]> = .loading
    /// The card waiting for the player to confirm its deletion.
    private(set) var pendingDeletion: FighterCard?
    var deleteError: AppError?

    private let repository: any CardRepository

    init(repository: any CardRepository) {
        self.repository = repository
    }

    func load() {
        do {
            state = ViewState(collection: try repository.allCards())
        } catch {
            state = .failed(AppError(title: String(localized: "Karten konnten nicht geladen werden"), error: error))
        }
    }

    func requestDelete(_ card: FighterCard) {
        pendingDeletion = card
    }

    func cancelDelete() {
        pendingDeletion = nil
    }

    func confirmDelete() {
        guard let card = pendingDeletion else { return }
        pendingDeletion = nil
        do {
            try repository.delete(id: card.id)
            load()
        } catch {
            deleteError = AppError(title: String(localized: "Karte konnte nicht gelöscht werden"), error: error)
        }
    }
}
