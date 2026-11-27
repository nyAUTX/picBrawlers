import Foundation
import Observation

/// Where the app is: the selected tab, the collection's navigation path and the creator sheet.
/// App Intents and the UI change it the same way.
@Observable
final class AppRouter {
    enum Tab: Hashable {
        case collection
        case fights
        case trades
    }

    /// A request to open the card creator, optionally with a photo (from Shortcuts, for example).
    struct CreatorRequest: Identifiable, Equatable {
        let id = UUID()
        let photo: Data?
    }

    var selectedTab: Tab = .collection
    var collectionPath: [UUID] = []
    var creator: CreatorRequest?

    func showCollection() {
        selectedTab = .collection
        collectionPath = []
    }

    func openCard(id: UUID) {
        creator = nil
        selectedTab = .collection
        collectionPath = [id]
    }

    func openCreator(photo: Data? = nil) {
        selectedTab = .collection
        creator = CreatorRequest(photo: photo)
    }
}
