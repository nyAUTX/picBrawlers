import SwiftUI

/// One card at full width, with everything the face can't fit: attack and special texts and weaknesses.
struct CardDetailView: View {
    @State private var viewModel: CardDetailViewModel
    @State private var isConfirmingDelete = false
    @Environment(\.dismiss) private var dismiss

    init(viewModel: CardDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ViewStateView(state: viewModel.state, retry: viewModel.load) { card in
            content(card)
        } empty: {
            EmptyStateView(
                title: "Karte nicht gefunden",
                systemImage: "questionmark.square.dashed",
                message: "Diese Karte gibt es nicht mehr. Vielleicht wurde sie gelöscht."
            )
        }
        .background(Color.paper)
        .navigationTitle(viewModel.state.value?.name ?? String(localized: "Karte"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let card = viewModel.state.value {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Löschen", systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
                        .confirmationDialog("Karte löschen?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                            Button("Löschen", role: .destructive) { viewModel.delete() }
                            Button("Abbrechen", role: .cancel) {}
                        } message: {
                            Text("„\(card.name)“ ist danach weg. Das lässt sich nicht rückgängig machen.")
                        }
                }
            }
        }
        .onAppear { viewModel.load() }
        .onChange(of: viewModel.isDeleted) { _, isDeleted in
            if isDeleted { dismiss() }
        }
        .errorAlert($viewModel.deleteError)
    }

    private func content(_ card: FighterCard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                FighterCardView(content: card)
                    .frame(maxWidth: 360)
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(card.accessibilityLabel(isCrumpled: false))
                    .accessibilityAddTraits(.isImage)

                MoveSection(
                    title: "Angriff",
                    systemImage: "figure.boxing",
                    name: card.attack.name,
                    detail: String(localized: "\(card.stats.damage) Schaden"),
                    description: card.attack.description
                )
                MoveSection(
                    title: "Spezialfähigkeit",
                    systemImage: card.special.effect.systemImage,
                    name: card.special.name,
                    detail: card.special.effect.title,
                    description: card.special.description
                )
                if !card.weaknesses.isEmpty {
                    WeaknessesSection(weaknesses: card.weaknesses)
                }
            }
            .padding(16)
            .padding(.bottom, 8)
        }
    }
}

private struct MoveSection: View {
    let title: LocalizedStringKey
    let systemImage: String
    let name: String
    let detail: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkMuted)
            Text(name)
                .font(.title3.bold())
                .foregroundStyle(Color.ink)
            Text(detail)
                .font(.system(.headline, design: .monospaced))
                .foregroundStyle(Color.ink)
            Text(description)
                .font(.body)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .inkPanel()
        .accessibilityElement(children: .combine)
    }
}

private struct WeaknessesSection: View {
    let weaknesses: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Schwächen", systemImage: "heart.slash.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkMuted)
            ForEach(weaknesses, id: \.self) { weakness in
                Text(weakness)
                    .font(.body)
                    .foregroundStyle(Color.ink)
            }
            Text("Nur zum Spaß, im Kampf zählen sie nicht.")
                .font(.footnote)
                .foregroundStyle(Color.inkMuted)
        }
        .inkPanel()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let environment = AppEnvironment.launch(arguments: ["-ui-testing"])
    NavigationStack {
        CardDetailView(viewModel: environment.makeDetailViewModel(cardID: UUID()))
    }
}
