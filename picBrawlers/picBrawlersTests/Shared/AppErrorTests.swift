import Foundation
import Testing
@testable import picBrawlers

@Suite("AppError")
struct AppErrorTests {
    @Test func descriptionIsTheTitle() {
        let error = AppError(title: "Karte konnte nicht erstellt werden", cause: .offline)
        #expect(error.errorDescription == "Karte konnte nicht erstellt werden")
        #expect(error.localizedDescription == "Karte konnte nicht erstellt werden")
    }

    @Test(arguments: AppError.Cause.allCases)
    func everyCauseExplainsWhyAndWhatToDo(cause: AppError.Cause) {
        let error = AppError(title: "Titel", cause: cause)
        #expect(error.failureReason?.isEmpty == false)
        #expect(error.recoverySuggestion?.isEmpty == false)
    }

    @Test func causesHaveDistinctReasons() {
        let reasons = AppError.Cause.allCases.map { AppError(title: "", cause: $0).failureReason }
        #expect(Set(reasons).count == AppError.Cause.allCases.count)
    }

    @Test(arguments: [
        (URLError.Code.notConnectedToInternet, AppError.Cause.offline),
        (.networkConnectionLost, .offline),
        (.dataNotAllowed, .offline),
        (.timedOut, .timedOut),
        (.cannotFindHost, .serverUnavailable),
        (.cannotConnectToHost, .serverUnavailable),
        (.badServerResponse, .serverUnavailable),
        (.unknown, .unexpected),
    ])
    func mapsURLErrors(code: URLError.Code, expected: AppError.Cause) {
        let error = AppError(title: "Titel", error: URLError(code))
        #expect(error.cause == expected)
        #expect(error.title == "Titel")
    }

    @Test func mapsUnknownErrorsToUnexpected() {
        struct SomethingWentWrong: Error {}
        #expect(AppError(title: "Titel", error: SomethingWentWrong()).cause == .unexpected)
    }

    @Test func wrappingAnAppErrorKeepsItsCauseAndUsesTheNewTitle() {
        let inner = AppError(title: "Innen", cause: .timedOut)
        let outer = AppError(title: "Außen", error: inner)
        #expect(outer == AppError(title: "Außen", cause: .timedOut))
    }
}
