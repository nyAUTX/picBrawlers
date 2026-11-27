import Foundation
import SwiftData
import Testing
import UIKit
@testable import picBrawlers

@Suite("SwiftData card repository")
@MainActor
struct SwiftDataCardRepositoryTests {
    private func makeRepository() throws -> SwiftDataCardRepository {
        let container = try ModelContainer.picBrawlers(inMemory: true)
        return SwiftDataCardRepository(container: container)
    }

    private let card: FighterCard = {
        var card = FighterCard.sample(createdAt: Date(timeIntervalSince1970: 10))
        card.imageData = Data([1, 2, 3])
        return card
    }()

    @Test func savedCardsComeBackUnchanged() throws {
        let repository = try makeRepository()
        try repository.save(card)
        #expect(try repository.card(id: card.id) == card)
        #expect(try repository.allCards() == [card])
    }

    @Test func listsNewestFirst() throws {
        let repository = try makeRepository()
        let newer = FighterCard.sample(name: "Kevin", createdAt: Date(timeIntervalSince1970: 20))
        try repository.save(card)
        try repository.save(newer)
        #expect(try repository.allCards().map(\.id) == [newer.id, card.id])
    }

    @Test func savingAgainUpdatesTheCard() throws {
        let repository = try makeRepository()
        try repository.save(card)
        var renamed = card
        renamed.name = "Opa Horst"
        try repository.save(renamed)
        #expect(try repository.allCards() == [renamed])
    }

    @Test func deletedCardsAreGone() throws {
        let repository = try makeRepository()
        try repository.save(card)
        try repository.delete(id: card.id)
        #expect(try repository.card(id: card.id) == nil)
        #expect(try repository.allCards().isEmpty)
    }

    @Test func aStoredRecordWithAnUnknownCategoryFallsBackInsteadOfCrashing() throws {
        let container = try ModelContainer.picBrawlers(inMemory: true)
        let record = CardRecord(card)
        record.categoryRaw = "wizard"
        record.specialEffectRaw = "teleport"
        container.mainContext.insert(record)
        let loaded = try #require(try SwiftDataCardRepository(container: container).card(id: card.id))
        #expect(loaded.category == .tank)
        #expect(loaded.special.effect == CardCategory.tank.allowedEffects[0])
    }
}

@Suite("Spotlight indexing")
@MainActor
struct IndexedCardRepositoryTests {
    @Test func savingIndexesTheCardAndDeletingRemovesIt() throws {
        let indexer = CardIndexingSpy()
        let base = InMemoryCardRepository()
        let repository = IndexedCardRepository(base: base, indexer: indexer)
        let card = FighterCard.sample()

        try repository.save(card)
        #expect(indexer.indexed == [card.id])
        #expect(base.cards[card.id] == card)

        try repository.delete(id: card.id)
        #expect(indexer.removed == [card.id])
        #expect(base.cards.isEmpty)
    }

    @Test func aFailedSaveIndexesNothing() {
        let indexer = CardIndexingSpy()
        let base = InMemoryCardRepository()
        base.failure = TestFailure()
        let repository = IndexedCardRepository(base: base, indexer: indexer)
        #expect(throws: TestFailure.self) { try repository.save(.sample()) }
        #expect(indexer.indexed.isEmpty)
    }
}

@Suite("Stub card generation")
@MainActor
struct StubCardGenerationServiceTests {
    private let request = CardGenerationRequest(
        name: "Oma Gerti", category: .support, analysis: PhotoAnalysis(labels: [], description: "")
    )

    @Test(arguments: CardCategory.allCases)
    func picksASpecialTheCategoryAllows(category: CardCategory) async throws {
        for seed in UInt64(0)..<30 {
            let service = StubCardGenerationService(random: SeededGenerator(seed: seed))
            let request = CardGenerationRequest(name: "X", category: category, analysis: PhotoAnalysis(labels: [], description: ""))
            let text = try await service.inventText(for: request)
            #expect(category.allowedEffects.contains(text.special.effect))
        }
    }

    @Test func fillsEveryText() async throws {
        let text = try await StubCardGenerationService(random: SeededGenerator(seed: 1)).inventText(for: request)
        #expect(!text.attack.name.isEmpty)
        #expect(!text.attack.description.isEmpty)
        #expect(!text.special.name.isEmpty)
        #expect(!text.special.description.isEmpty)
        #expect((1...CardFactory.maxWeaknesses).contains(text.weaknesses.count))
        #expect(Set(text.weaknesses).count == text.weaknesses.count)
    }

    @Test func theSameSeedWritesTheSameText() async throws {
        let first = try await StubCardGenerationService(random: SeededGenerator(seed: 9)).inventText(for: request)
        let second = try await StubCardGenerationService(random: SeededGenerator(seed: 9)).inventText(for: request)
        #expect(first == second)
    }

    @Test func theStubCantSeeThePhotoSoItDoesntDescribeIt() async throws {
        let analysis = try await StubCardGenerationService().analyze(photo: Data([1]))
        #expect(analysis == PhotoAnalysis(labels: [], description: ""))
    }
}

@Suite("Photo processor")
struct PhotoProcessorTests {
    private func pngData(width: Int, height: Int) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).pngData { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    @Test func shrinksLargePhotosToTheMaximumSize() async throws {
        let prepared = try await PhotoProcessor().prepare(pngData(width: 3000, height: 2000))
        let image = try #require(UIImage(data: prepared))
        #expect(max(image.size.width, image.size.height) * image.scale == CGFloat(PhotoProcessor.maxPixelSize))
    }

    @Test func keepsSmallPhotosAtTheirSize() async throws {
        let prepared = try await PhotoProcessor().prepare(pngData(width: 400, height: 300))
        let image = try #require(UIImage(data: prepared))
        #expect(image.size.width * image.scale == 400)
    }

    @Test func dataThatIsNoImageIsUnreadable() async {
        await #expect(throws: PhotoProcessingError.unreadable) {
            try await PhotoProcessor().prepare(Data("kein Bild".utf8))
        }
    }
}

@Suite("Local player")
struct LocalPlayerTests {
    @Test func createsAnIDOnceAndKeepsIt() throws {
        let defaults = try #require(UserDefaults(suiteName: "LocalPlayerTests-\(UUID().uuidString)"))
        let first = LocalPlayer.id(in: defaults)
        #expect(!first.isEmpty)
        #expect(LocalPlayer.id(in: defaults) == first)
    }
}

@Suite("Photo errors")
struct PhotoErrorMappingTests {
    @Test func anUnreadablePhotoMapsToItsCause() {
        let error = AppError(title: "Foto konnte nicht geladen werden", error: PhotoProcessingError.unreadable)
        #expect(error.cause == .photoUnreadable)
        #expect(error.failureReason == "Das Foto lässt sich nicht öffnen.")
        #expect(error.recoverySuggestion == "Wähl ein anderes Foto aus.")
    }
}
