import SwiftUI

/// Shown when a screen has nothing to display yet. Explains why and, if possible, offers the next step.
struct EmptyStateView: View {
    struct Action {
        let title: LocalizedStringKey
        let perform: () -> Void
    }

    let title: LocalizedStringKey
    let systemImage: String
    let message: LocalizedStringKey
    var action: Action?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let action {
                Button(action.title, action: action.perform)
                    .buttonStyle(.borderedProminent)
            }
        }
        .scrollableWhenTooTall()
    }
}

#Preview("Mit Aktion") {
    EmptyStateView(
        title: "Noch keine Karten",
        systemImage: "photo.on.rectangle.angled",
        message: "Mach aus einem Foto deine erste Kämpferkarte.",
        action: .init(title: "Karte erstellen") {}
    )
}

#Preview("Ohne Aktion") {
    EmptyStateView(
        title: "Noch keine Kämpfe",
        systemImage: "figure.boxing",
        message: "Fordere einen Freund heraus."
    )
}
