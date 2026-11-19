import Foundation
import OSLog

/// Every error the player can see. It says what happened (`title`), why (`failureReason`)
/// and what to do (`recoverySuggestion`), all in German. Underlying errors are logged, never shown.
nonisolated struct AppError: LocalizedError, Equatable, Sendable {
    nonisolated enum Cause: Equatable, Sendable, CaseIterable {
        case offline
        case timedOut
        case serverUnavailable
        case unexpected
    }

    /// What happened, from the player's point of view, e.g. "Karte konnte nicht erstellt werden".
    let title: String
    let cause: Cause

    init(title: String, cause: Cause) {
        self.title = title
        self.cause = cause
    }

    /// Maps any thrown error to a cause the player can act on.
    init(title: String, error: any Error) {
        self.init(title: title, cause: Self.cause(of: error))
        if cause == .unexpected {
            Self.logger.error("\(title, privacy: .public): \(String(describing: error), privacy: .public)")
        }
    }

    var errorDescription: String? { title }

    var failureReason: String? {
        switch cause {
        case .offline: String(localized: "Keine Internetverbindung.")
        case .timedOut: String(localized: "Der Server hat zu lange nicht geantwortet.")
        case .serverUnavailable: String(localized: "Der Server ist gerade nicht erreichbar.")
        case .unexpected: String(localized: "Etwas ist unerwartet schiefgegangen.")
        }
    }

    var recoverySuggestion: String? {
        switch cause {
        case .offline: String(localized: "Prüfe deine Verbindung und versuch es noch einmal.")
        case .timedOut: String(localized: "Versuch es in ein paar Sekunden noch einmal.")
        case .serverUnavailable: String(localized: "Versuch es in ein paar Minuten noch einmal.")
        case .unexpected: String(localized: "Versuch es noch einmal. Wenn es wieder passiert, starte die App neu.")
        }
    }

    private static let logger = Logger(subsystem: "at.fhooe.picBrawlers", category: "AppError")

    private static func cause(of error: any Error) -> Cause {
        if let appError = error as? AppError { return appError.cause }
        guard let urlError = error as? URLError else { return .unexpected }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return .offline
        case .timedOut:
            return .timedOut
        case .cannotFindHost, .cannotConnectToHost, .badServerResponse:
            return .serverUnavailable
        default:
            return .unexpected
        }
    }
}
