import Foundation
import Observation
import OSLog

/// Makes a new card: pick a photo, name it, choose a category, then generate.
@Observable
final class CardCreatorViewModel {
    enum PhotoState: Equatable {
        case none
        case loading
        case loaded(Data)
        case failed(AppError)
    }

    /// The named steps shown while a card is being made.
    enum Stage: CaseIterable, Equatable {
        case analyzingPhoto
        case rollingStats
        case inventingMoves

        var title: String {
            switch self {
            case .analyzingPhoto: String(localized: "Foto wird analysiert …")
            case .rollingStats: String(localized: "Werte werden ausgewürfelt …")
            case .inventingMoves: String(localized: "Angriff wird erfunden …")
            }
        }
    }

    enum Phase: Equatable {
        case editing
        case generating(Stage)
        case created(FighterCard)
        case failed(AppError)
    }

    var name = "" {
        didSet { if !name.isEmpty { hasTypedName = true } }
    }
    private(set) var category: CardCategory?
    private(set) var photo: PhotoState = .none
    private(set) var phase: Phase = .editing
    private(set) var creationTask: Task<Void, Never>?

    private var hasTypedName = false
    private var pendingPhoto: Data?
    private var random: AnyRandomNumberGenerator
    private let repository: any CardRepository
    private let generator: any CardGenerationService
    private let photoProcessor: any PhotoProcessing
    private let playerID: String
    private let now: () -> Date
    private let makeID: () -> UUID

    private static let logger = Logger(subsystem: "at.fhooe.picBrawlers", category: "CardCreator")

    init(
        repository: any CardRepository,
        generator: any CardGenerationService,
        photoProcessor: any PhotoProcessing,
        playerID: String,
        initialPhoto: Data? = nil,
        random: any RandomNumberGenerator = SystemRandomNumberGenerator(),
        now: @escaping () -> Date = Date.init,
        makeID: @escaping () -> UUID = UUID.init
    ) {
        self.repository = repository
        self.generator = generator
        self.photoProcessor = photoProcessor
        self.playerID = playerID
        self.pendingPhoto = initialPhoto
        self.random = AnyRandomNumberGenerator(random)
        self.now = now
        self.makeID = makeID
    }

    // MARK: Form

    /// Inline validation while typing. An empty name only counts as a mistake once something was typed.
    var nameMessage: String? {
        switch CardName.issue(for: name) {
        case .tooLong: String(localized: "Höchstens \(CardName.maxLength) Zeichen.")
        case .empty where hasTypedName: String(localized: "Gib der Karte einen Namen.")
        default: nil
        }
    }

    var isGenerating: Bool {
        if case .generating = phase { return true }
        return false
    }

    var canCreate: Bool {
        guard case .loaded = photo, category != nil, CardName.issue(for: name) == nil else { return false }
        return phase == .editing
    }

    func selectCategory(_ category: CardCategory) {
        self.category = category
    }

    // MARK: Photo

    /// Loads a photo handed over when the creator was opened (by an intent, for example).
    func start() async {
        guard let pendingPhoto else { return }
        self.pendingPhoto = nil
        await loadPhoto { pendingPhoto }
    }

    /// Loads and prepares a photo. `load` returns the photo's data, e.g. from a `PhotosPickerItem`.
    func loadPhoto(_ load: @escaping () async throws -> Data?) async {
        photo = .loading
        do {
            guard let data = try await load() else { throw PhotoProcessingError.unreadable }
            photo = .loaded(try await photoProcessor.prepare(data))
        } catch {
            Self.logger.error("Photo could not be loaded: \(String(describing: error), privacy: .public)")
            photo = .failed(AppError(title: String(localized: "Foto konnte nicht geladen werden"), error: error))
        }
    }

    // MARK: Creating

    func createCard() {
        guard canCreate, case .loaded(let imageData) = photo, let category else { return }
        let name = CardName.normalized(name)
        creationTask = Task { await create(name: name, category: category, imageData: imageData) }
    }

    /// Stops the generation. Nothing is saved, and the form keeps what the player entered.
    func cancelCreation() {
        creationTask?.cancel()
        phase = .editing
    }

    /// After a failed generation: back to the form, with everything the player entered.
    func backToEditing() {
        phase = .editing
    }

    private func create(name: String, category: CardCategory, imageData: Data) async {
        do {
            phase = .generating(.analyzingPhoto)
            let analysis = try await generator.analyze(photo: imageData)
            try Task.checkCancellation()

            phase = .generating(.rollingStats)
            let id = makeID()
            let createdAt = now()

            phase = .generating(.inventingMoves)
            var text = try await generator.inventText(for: CardGenerationRequest(name: name, category: category, analysis: analysis))
            try Task.checkCancellation()
            if text.photoDescription.isEmpty { text.photoDescription = analysis.description }

            let card = CardFactory.makeCard(
                id: id, name: name, category: category, text: text,
                imageData: imageData, playerID: playerID, createdAt: createdAt, using: &random
            )
            try repository.save(card)
            phase = .created(card)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failed(AppError(title: String(localized: "Karte konnte nicht erstellt werden"), error: error))
        }
    }
}
