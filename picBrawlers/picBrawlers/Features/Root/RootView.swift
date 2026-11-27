import SwiftUI

/// The app's tab bar. Fights and trades show an empty state until their features are built.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    #if DEBUG
    /// A pass-and-play test fight, debug builds only.
    @State private var testFight: FightViewModel?
    #endif

    var body: some View {
        @Bindable var router = environment.router
        TabView(selection: $router.selectedTab) {
            Tab("Sammlung", systemImage: "rectangle.stack.fill", value: AppRouter.Tab.collection) {
                CollectionView(viewModel: environment.makeCollectionViewModel())
            }

            Tab("Kämpfe", systemImage: "figure.boxing", value: AppRouter.Tab.fights) {
                NavigationStack {
                    EmptyStateView(
                        title: "Noch keine Kämpfe",
                        systemImage: "figure.boxing",
                        message: "Bald forderst du hier Freunde zu einem Kampf heraus."
                    )
                    .navigationTitle("Kämpfe")
                    #if DEBUG
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                testFight = environment.makeTestFightViewModel()
                            } label: {
                                Label("Testkampf", systemImage: "person.2.fill")
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink {
                                LineupView()
                            } label: {
                                Label("Effekte", systemImage: "wand.and.sparkles")
                            }
                        }
                    }
                    .fullScreenCover(item: $testFight) { fight in
                        FightView(viewModel: fight)
                    }
                    #endif
                }
            }

            Tab("Tauschen", systemImage: "arrow.left.arrow.right", value: AppRouter.Tab.trades) {
                NavigationStack {
                    EmptyStateView(
                        title: "Noch kein Tausch",
                        systemImage: "arrow.left.arrow.right",
                        message: "Bald tauschst du hier Karten mit Freunden."
                    )
                    .navigationTitle("Tauschen")
                }
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AppEnvironment.launch(arguments: ["-ui-testing"]))
}
