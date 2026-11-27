import Foundation
import Observation
import OSLog
import SwiftData
import UIKit

/// Builds the app's services once and hands out ViewModels. Views get it from the environment;
/// App Intents get it as an `@Dependency`.
@Observable
final class AppEnvironment {
    let router = AppRouter()
    let repository: any CardRepository
    let generator: any CardGenerationService
    let photoProcessor: any PhotoProcessing
    let playerID: String
    /// UI tests can't drive the system photo picker, so they start the creator with this photo.
    let samplePhoto: Data?

    private static let logger = Logger(subsystem: "at.fhooe.picBrawlers", category: "AppEnvironment")

    init(container: ModelContainer, indexer: any CardIndexing, playerID: String, samplePhoto: Data? = nil) {
        self.repository = IndexedCardRepository(
            base: SwiftDataCardRepository(container: container),
            indexer: indexer
        )
        self.generator = StubCardGenerationService()
        self.photoProcessor = PhotoProcessor()
        self.playerID = playerID
        self.samplePhoto = samplePhoto
    }

    /// The app as it launches. UI tests pass `-ui-testing` for an empty in-memory store, and
    /// `-sample-photo` to start the creator with a photo.
    static func launch(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppEnvironment {
        let isUITesting = arguments.contains("-ui-testing")
        let container: ModelContainer
        do {
            container = try .picBrawlers(inMemory: isUITesting)
        } catch {
            // The store can't be opened. Keep the app usable for this launch and log it.
            logger.fault("Opening the card store failed: \(String(describing: error), privacy: .public)")
            container = try! .picBrawlers(inMemory: true)
        }
        return AppEnvironment(
            container: container,
            indexer: SpotlightCardIndexer(),
            playerID: isUITesting ? "ui-test-player" : LocalPlayer.id(),
            samplePhoto: arguments.contains("-sample-photo") ? Self.makeSamplePhoto() : nil
        )
    }

    func makeCollectionViewModel() -> CollectionViewModel {
        CollectionViewModel(repository: repository)
    }

    func makeDetailViewModel(cardID: UUID) -> CardDetailViewModel {
        CardDetailViewModel(cardID: cardID, repository: repository)
    }

    func makeCreatorViewModel(photo: Data?) -> CardCreatorViewModel {
        CardCreatorViewModel(
            repository: repository,
            generator: generator,
            photoProcessor: photoProcessor,
            playerID: playerID,
            initialPhoto: photo ?? samplePhoto
        )
    }

    private static func makeSamplePhoto() -> Data {
        let size = CGSize(width: 800, height: 600)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).pngData { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let symbol = UIImage(systemName: "dog.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 360))?
                .withTintColor(.black, renderingMode: .alwaysOriginal)
            symbol?.draw(at: CGPoint(x: 180, y: 120))
        }
    }
}
