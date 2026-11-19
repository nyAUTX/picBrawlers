import Testing
@testable import picBrawlers

@Suite("ViewState")
struct ViewStateTests {
    private let error = AppError(title: "Fehler", cause: .offline)

    @Test func emptyCollectionBecomesEmptyState() {
        #expect(ViewState(collection: [Int]()) == .empty)
    }

    @Test func nonEmptyCollectionBecomesLoadedState() {
        #expect(ViewState(collection: [1, 2]) == .loaded([1, 2]))
    }

    @Test func valueIsOnlyAvailableWhenLoaded() {
        #expect(ViewState<Int>.loaded(3).value == 3)
        #expect(ViewState<Int>.loading.value == nil)
        #expect(ViewState<Int>.empty.value == nil)
        #expect(ViewState<Int>.failed(error).value == nil)
    }

    @Test func errorIsOnlyAvailableWhenFailed() {
        #expect(ViewState<Int>.failed(error).error == error)
        #expect(ViewState<Int>.loaded(3).error == nil)
        #expect(ViewState<Int>.loading.error == nil)
    }

    @Test func isLoadingOnlyWhileLoading() {
        #expect(ViewState<Int>.loading.isLoading)
        #expect(!ViewState<Int>.empty.isLoading)
        #expect(!ViewState<Int>.loaded(1).isLoading)
        #expect(!ViewState<Int>.failed(error).isLoading)
    }
}
