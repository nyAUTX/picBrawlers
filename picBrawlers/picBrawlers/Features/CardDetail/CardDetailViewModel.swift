import Foundation
import Observation

/// One card, opened from the collection, Spotlight or Siri.
@Observable
final class CardDetailViewModel {
    let cardID: UUID
    private(set) var state: ViewState<FighterCard> = .loading
    private(set) var isDeleted = false
    var deleteError: AppError?

    private let repository: any CardRepository

    init(cardID: UUID, repository: any CardRepository) {
        self.cardID = cardID
        self.repository = repository
    }

    func load() {
        do {
            state = try repository.card(id: cardID).map(ViewState.loaded) ?? .empty
        } catch {
            state = .failed(AppError(title: String(localized: "Karte konnte nicht geladen werden"), error: error))
        }
    }

    func delete() {
        do {
            try repository.delete(id: cardID)
            isDeleted = true
        } catch {
            deleteError = AppError(title: String(localized: "Karte konnte nicht gelöscht werden"), error: error)
        }
    }
}
