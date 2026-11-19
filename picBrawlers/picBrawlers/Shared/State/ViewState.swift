/// The state of any screen that loads data. ViewModels expose one of these; views switch over it.
nonisolated enum ViewState<Value> {
    case loading
    case empty
    case loaded(Value)
    case failed(AppError)

    var value: Value? {
        if case .loaded(let value) = self { value } else { nil }
    }

    var error: AppError? {
        if case .failed(let error) = self { error } else { nil }
    }

    var isLoading: Bool {
        if case .loading = self { true } else { false }
    }
}

nonisolated extension ViewState where Value: Collection {
    /// `.empty` for an empty collection, otherwise `.loaded`.
    init(collection: Value) {
        self = collection.isEmpty ? .empty : .loaded(collection)
    }
}

nonisolated extension ViewState: Equatable where Value: Equatable {}
