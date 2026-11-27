import Foundation

/// What the AI saw in the photo.
nonisolated struct PhotoAnalysis: Hashable, Sendable {
    /// Things in the photo, e.g. "Hund", "Fußball". Used to pick fitting attacks.
    var labels: [String]
    /// A short description for VoiceOver. Empty if nothing could be described.
    var description: String
}

nonisolated struct CardGenerationRequest: Hashable, Sendable {
    var name: String
    var category: CardCategory
    var analysis: PhotoAnalysis
}

/// Writes a card's flavor text. Phase 1 uses `StubCardGenerationService`; Phase 3 adds the on-device AI.
protocol CardGenerationService: AnyObject {
    func analyze(photo: Data) async throws -> PhotoAnalysis
    func inventText(for request: CardGenerationRequest) async throws -> CardText
}
