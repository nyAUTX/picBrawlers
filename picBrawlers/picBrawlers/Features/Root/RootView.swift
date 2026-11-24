import SwiftUI

/// The app's tab bar. Each tab shows an empty state until its feature is built.
struct RootView: View {
    var body: some View {
        TabView {
            Tab("Sammlung", systemImage: "rectangle.stack") {
                NavigationStack {
                    EmptyStateView(
                        title: "Noch keine Karten",
                        systemImage: "photo.on.rectangle.angled",
                        message: "Bald machst du hier aus Fotos deiner Galerie Kämpferkarten."
                    )
                    .navigationTitle("Sammlung")
                }
            }

            Tab("Kämpfe", systemImage: "figure.boxing") {
                NavigationStack {
                    EmptyStateView(
                        title: "Noch keine Kämpfe",
                        systemImage: "figure.boxing",
                        message: "Bald forderst du hier Freunde zu einem Kampf heraus."
                    )
                    .navigationTitle("Kämpfe")
                    #if DEBUG
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink {
                                LineupView()
                            } label: {
                                Label("Effekte", systemImage: "wand.and.sparkles")
                            }
                        }
                    }
                    #endif
                }
            }

            Tab("Tauschen", systemImage: "arrow.left.arrow.right") {
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
}
