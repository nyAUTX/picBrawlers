import Foundation
import Testing
@testable import picBrawlers

@Suite("Card creator view model")
@MainActor
struct CardCreatorViewModelTests {
    private let repository = InMemoryCardRepository()
    private let generator = FakeCardGenerationService()
    private let cardID = UUID(uuidString: "00000000-0000-4000-8000-0000000000C1")!
    private let date = Date(timeIntervalSince1970: 5_000)

    private func makeViewModel(
        processor: FakePhotoProcessor = FakePhotoProcessor(),
        initialPhoto: Data? = nil
    ) -> CardCreatorViewModel {
        let cardID = cardID
        let date = date
        return CardCreatorViewModel(
            repository: repository,
            generator: generator,
            photoProcessor: processor,
            playerID: "player-1",
            initialPhoto: initialPhoto,
            random: SeededGenerator(seed: 3),
            now: { date },
            makeID: { cardID }
        )
    }

    /// A view model with a photo, a name and a category: ready to create.
    private func makeReadyViewModel() async -> CardCreatorViewModel {
        let viewModel = makeViewModel()
        await viewModel.loadPhoto { Data([1]) }
        viewModel.name = "Oma Gerti"
        viewModel.selectCategory(.tank)
        return viewModel
    }

    // MARK: Form

    @Test func startsEmptyAndCannotCreateYet() {
        let viewModel = makeViewModel()
        #expect(viewModel.photo == .none)
        #expect(viewModel.name.isEmpty)
        #expect(viewModel.category == nil)
        #expect(viewModel.phase == .editing)
        #expect(!viewModel.canCreate)
    }

    @Test func anUntouchedEmptyNameShowsNoErrorYet() {
        let viewModel = makeViewModel()
        #expect(viewModel.nameMessage == nil)
    }

    @Test func clearingTheNameAfterTypingAsksForOne() {
        let viewModel = makeViewModel()
        viewModel.name = "O"
        viewModel.name = ""
        #expect(viewModel.nameMessage == "Gib der Karte einen Namen.")
    }

    @Test func aTooLongNameIsFlaggedWhileTyping() {
        let viewModel = makeViewModel()
        viewModel.name = String(repeating: "a", count: CardName.maxLength + 1)
        #expect(viewModel.nameMessage == "Höchstens 20 Zeichen.")
    }

    @Test func aValidNameShowsNoError() {
        let viewModel = makeViewModel()
        viewModel.name = "Oma Gerti"
        #expect(viewModel.nameMessage == nil)
    }

    @Test func photoNameAndCategoryTogetherEnableCreating() async {
        let viewModel = await makeReadyViewModel()
        #expect(viewModel.canCreate)
    }

    @Test func anInvalidNameKeepsCreatingDisabled() async {
        let viewModel = await makeReadyViewModel()
        viewModel.name = "   "
        #expect(!viewModel.canCreate)
    }

    // MARK: Photo

    @Test func aPickedPhotoIsPreparedAndShown() async {
        let viewModel = makeViewModel()
        await viewModel.loadPhoto { Data([1, 2]) }
        #expect(viewModel.photo == .loaded(Data([1, 2, 0xFF])))
    }

    @Test func aPhotoThatCantBeReadShowsAnError() async {
        let viewModel = makeViewModel(processor: FakePhotoProcessor(failure: PhotoProcessingError.unreadable))
        await viewModel.loadPhoto { Data([1]) }
        #expect(viewModel.photo == .failed(AppError(title: "Foto konnte nicht geladen werden", cause: .photoUnreadable)))
        #expect(!viewModel.canCreate)
    }

    @Test func aPhotoThatLoadsAsNothingCountsAsUnreadable() async {
        let viewModel = makeViewModel()
        await viewModel.loadPhoto { nil }
        #expect(viewModel.photo == .failed(AppError(title: "Foto konnte nicht geladen werden", cause: .photoUnreadable)))
    }

    @Test func aPhotoHandedOverByAnIntentIsLoadedOnStart() async {
        let viewModel = makeViewModel(initialPhoto: Data([9]))
        await viewModel.start()
        #expect(viewModel.photo == .loaded(Data([9, 0xFF])))
    }

    // MARK: Creating

    @Test func creatingRunsTheStagesSavesTheCardAndShowsIt() async throws {
        let viewModel = await makeReadyViewModel()
        var phasesSeen: [CardCreatorViewModel.Phase] = []
        generator.onAnalyze = { phasesSeen.append(viewModel.phase) }
        generator.onInvent = { phasesSeen.append(viewModel.phase) }

        viewModel.createCard()
        await viewModel.creationTask?.value

        #expect(phasesSeen == [.generating(.analyzingPhoto), .generating(.inventingMoves)])
        let saved = try #require(repository.cards[cardID])
        #expect(viewModel.phase == .created(saved))
        #expect(saved.name == "Oma Gerti")
        #expect(saved.category == .tank)
        #expect(saved.attack == CardText.sample.attack)
        #expect(saved.imageData == Data([1, 0xFF]))
        #expect(saved.createdAt == date)
        #expect(saved.ownerID == "player-1")
        #expect(CardCategory.tank.healthRange.contains(saved.stats.health))
    }

    @Test func theGeneratorGetsTheNameCategoryAndPhotoAnalysis() async {
        let viewModel = await makeReadyViewModel()
        viewModel.createCard()
        await viewModel.creationTask?.value
        #expect(generator.requests == [CardGenerationRequest(name: "Oma Gerti", category: .tank, analysis: generator.analysis)])
    }

    @Test func theAIPhotoDescriptionIsUsedWhenTheTextHasNone() async throws {
        generator.text.photoDescription = ""
        let viewModel = await makeReadyViewModel()
        viewModel.createCard()
        await viewModel.creationTask?.value
        #expect(try #require(repository.cards[cardID]).photoDescription == "Frau mit Kochlöffel")
    }

    @Test func creatingIsIgnoredWhileTheFormIsIncomplete() async {
        let viewModel = makeViewModel()
        viewModel.createCard()
        await viewModel.creationTask?.value
        #expect(viewModel.phase == .editing)
        #expect(repository.cards.isEmpty)
    }

    @Test func aFailedGenerationShowsAnErrorAndKeepsTheForm() async {
        generator.failure = TestFailure()
        let viewModel = await makeReadyViewModel()
        viewModel.createCard()
        await viewModel.creationTask?.value
        #expect(viewModel.phase == .failed(AppError(title: "Karte konnte nicht erstellt werden", cause: .unexpected)))
        #expect(repository.cards.isEmpty)
        #expect(viewModel.name == "Oma Gerti")

        viewModel.backToEditing()
        #expect(viewModel.phase == .editing)
        #expect(viewModel.canCreate)
    }

    @Test func aFailedSaveShowsAnError() async {
        repository.failure = TestFailure()
        let viewModel = await makeReadyViewModel()
        viewModel.createCard()
        await viewModel.creationTask?.value
        #expect(viewModel.phase == .failed(AppError(title: "Karte konnte nicht erstellt werden", cause: .unexpected)))
    }

    @Test func cancellingStopsTheGenerationAndSavesNothing() async {
        generator.holdsInvent = true
        let viewModel = await makeReadyViewModel()
        viewModel.createCard()
        while !generator.isHeld { await Task.yield() }

        viewModel.cancelCreation()
        #expect(viewModel.phase == .editing)
        generator.release()
        await viewModel.creationTask?.value

        #expect(viewModel.phase == .editing)
        #expect(repository.cards.isEmpty)
    }

    @Test func theFormStaysEditableWhileGenerating() async {
        generator.holdsInvent = true
        let viewModel = await makeReadyViewModel()
        viewModel.createCard()
        while !generator.isHeld { await Task.yield() }

        viewModel.name = "Opa Horst"
        #expect(viewModel.name == "Opa Horst")
        #expect(!viewModel.canCreate, "A second card can't start while one is being made")

        generator.release()
        await viewModel.creationTask?.value
    }
}
