import SwiftUI

/// The player's cards, one per row like cards held in the hand. Each opens its detail view.
struct CollectionView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: CollectionViewModel
    @Namespace private var zoom

    /// Keeps cards a hand-held size on larger phones.
    private static let maxCardWidth: CGFloat = 360

    init(viewModel: CollectionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var router = environment.router
        NavigationStack(path: $router.collectionPath) {
            ViewStateView(state: viewModel.state, retry: viewModel.load) { cards in
                cardList(cards)
            } empty: {
                EmptyStateView(
                    title: "Noch keine Karten",
                    systemImage: "photo.badge.plus",
                    message: "Mach aus einem Foto deine erste Kämpferkarte.",
                    action: .init(title: "Karte erstellen") { router.openCreator() }
                )
            }
            .background(Color.paper)
            .navigationTitle("Sammlung")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { router.openCreator() } label: {
                        Label("Karte erstellen", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                CardDetailView(viewModel: environment.makeDetailViewModel(cardID: id))
                    .navigationTransition(.zoom(sourceID: id, in: zoom))
            }
            .onAppear { viewModel.load() }
        }
        .sheet(item: $router.creator, onDismiss: viewModel.load) { request in
            CardCreatorView(viewModel: environment.makeCreatorViewModel(photo: request.photo))
        }
        .confirmationDialog(
            "Karte löschen?",
            isPresented: Binding(get: { viewModel.pendingDeletion != nil }, set: { if !$0 { viewModel.cancelDelete() } }),
            titleVisibility: .visible,
            presenting: viewModel.pendingDeletion
        ) { _ in
            Button("Löschen", role: .destructive) { viewModel.confirmDelete() }
            Button("Abbrechen", role: .cancel) { viewModel.cancelDelete() }
        } message: { card in
            Text("„\(card.name)“ ist danach weg. Das lässt sich nicht rückgängig machen.")
        }
        .errorAlert($viewModel.deleteError)
    }

    private func cardList(_ cards: [FighterCard]) -> some View {
        ScrollView {
            LazyVStack(spacing: 28) {
                ForEach(cards) { card in
                    NavigationLink(value: card.id) {
                        FighterCardView(content: card)
                    }
                    .buttonStyle(.pressable)
                    .frame(maxWidth: Self.maxCardWidth)
                    .matchedTransitionSource(id: card.id, in: zoom)
                    .contextMenu {
                        Button("Löschen", systemImage: "trash", role: .destructive) { viewModel.requestDelete(card) }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(card.accessibilityLabel(isCrumpled: false))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction(named: "Löschen") { viewModel.requestDelete(card) }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
        }
    }
}

extension View {
    /// Shows an `AppError` as an alert with its reason and suggestion. Only for errors with no better place.
    func errorAlert(_ error: Binding<AppError?>) -> some View {
        alert(
            error.wrappedValue?.title ?? "",
            isPresented: Binding(get: { error.wrappedValue != nil }, set: { if !$0 { error.wrappedValue = nil } }),
            presenting: error.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text([error.failureReason, error.recoverySuggestion].compactMap(\.self).joined(separator: " "))
        }
    }
}

#Preview {
    let environment = AppEnvironment.launch(arguments: ["-ui-testing"])
    CollectionView(viewModel: environment.makeCollectionViewModel())
        .environment(environment)
}
