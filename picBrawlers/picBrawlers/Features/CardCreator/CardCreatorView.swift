import PhotosUI
import SwiftUI

/// Makes a new card: photo, name, category, then "Karte erstellen". Shown as a sheet.
struct CardCreatorView: View {
    @State private var viewModel: CardCreatorViewModel
    @State private var pickerItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: CardCreatorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                if case .created(let card) = viewModel.phase {
                    CreatedCardView(card: card) { dismiss() }
                        .transition(.opacity)
                } else {
                    form
                }
            }
            .animation(Motion.animation(Motion.standard, reduceMotion: reduceMotion), value: viewModel.phase)
            .navigationTitle("Neue Karte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isCreated {
                    ToolbarItem(placement: .cancellationAction) {
                        // Icon only: text buttons in bars stop growing at large text sizes.
                        Button("Abbrechen", systemImage: "xmark", role: .cancel) {
                            viewModel.cancelCreation()
                            dismiss()
                        }
                    }
                }
            }
        }
        .task { await viewModel.start() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await viewModel.loadPhoto { try await item.loadTransferable(type: Data.self) } }
        }
        .sensoryFeedback(.selection, trigger: viewModel.category)
        .sensoryFeedback(trigger: viewModel.phase) { _, phase in
            switch phase {
            case .created: HapticEvent.success.feedback
            case .failed: HapticEvent.failure.feedback
            default: nil
            }
        }
        .interactiveDismissDisabled(viewModel.isGenerating)
    }

    private var isCreated: Bool {
        if case .created = viewModel.phase { return true }
        return false
    }

    // MARK: Form

    /// A plain scroll view rather than a `Form`: every row exists up front, so nothing is recycled
    /// while text grows, and the sections can use the design system's ink panels.
    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                photoSection
                nameSection
                categorySection
                createSection
            }
            .padding(16)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.paper)
    }

    private var photoSection: some View {
        FormSection("Foto", footer: "Nur Fotos von Menschen, die zugestimmt haben.") {
            VStack(alignment: .leading, spacing: 12) {
                switch viewModel.photo {
                case .none:
                    EmptyView()
                case .loading:
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Foto wird geladen …")
                            .font(.callout)
                            .foregroundStyle(Color.inkMuted)
                    }
                    .accessibilityElement(children: .combine)
                case .loaded(let data):
                    if let image = UIImage(data: data) {
                        Color.paperSunken
                            .frame(height: 220)
                            .overlay {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            }
                            .clipped()
                            .overlay(Rectangle().strokeBorder(Color.ink, lineWidth: 3))
                            .accessibilityElement()
                            .accessibilityIgnoresInvertColors()
                            .accessibilityLabel("Gewähltes Foto")
                            .accessibilityAddTraits(.isImage)
                    }
                case .failed(let error):
                    InlineError(error: error)
                }

                let title = photoButtonTitle
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label(title, systemImage: "photo.badge.plus")
                }
                .buttonStyle(.brawl())
            }
            .inkPanel()
        }
    }

    private var photoButtonTitle: String {
        switch viewModel.photo {
        case .none, .loading: String(localized: "Foto auswählen")
        case .loaded, .failed: String(localized: "Anderes Foto wählen")
        }
    }

    private var nameSection: some View {
        FormSection("Name") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Name der Karte", text: $viewModel.name)
                    .font(.body)
                    .foregroundStyle(Color.ink)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.ink, lineWidth: 3))
                Group {
                    if let message = viewModel.nameMessage {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.dangerText)
                    } else {
                        Text("Bis zu \(CardName.maxLength) Zeichen.")
                            .foregroundStyle(Color.inkMuted)
                    }
                }
                .font(.footnote)
            }
        }
    }

    private var categorySection: some View {
        FormSection("Kategorie") {
            VStack(spacing: 0) {
                ForEach(Array(CardCategory.allCases.enumerated()), id: \.element) { index, category in
                    if index > 0 { Rectangle().fill(Color.ink).frame(height: 1) }
                    CategoryRow(category: category, isSelected: viewModel.category == category) {
                        viewModel.selectCategory(category)
                    }
                    .padding(.vertical, 8)
                }
            }
            .inkPanel()
        }
    }

    @ViewBuilder
    private var createSection: some View {
        switch viewModel.phase {
        case .generating(let stage):
            GenerationProgress(current: stage) { viewModel.cancelCreation() }
        case .failed(let error):
            VStack(alignment: .leading, spacing: 12) {
                InlineError(error: error)
                Button("Erneut versuchen") {
                    viewModel.backToEditing()
                    viewModel.createCard()
                }
                .buttonStyle(.brawl(.primary))
            }
            .inkPanel()
        case .editing, .created:
            Button("Karte erstellen") { viewModel.createCard() }
                .buttonStyle(.brawl(.primary))
                .frame(maxWidth: .infinity)
                .disabled(!viewModel.canCreate)
                .accessibilityIdentifier("createCard")
        }
    }
}

/// A titled group in the creator, with an optional note below it.
private struct FormSection<Content: View>: View {
    let title: LocalizedStringKey
    var footer: LocalizedStringKey?
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey, footer: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title)
            content
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A form section header in the design system's label style, set explicitly so it scales with Dynamic Type.
private struct SectionTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.inkMuted)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }
}

/// One category to pick: fill, icon, name and what it's good at. Selection shows a check, not only color.
private struct CategoryRow: View {
    let category: CardCategory
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 12) {
                Image(systemName: category.systemImage)
                    .font(.headline)
                    .foregroundStyle(Color.onFill)
                    .frame(width: 44, height: 44)
                    .background(category.fill, in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.ink, lineWidth: 2))
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.title)
                        .font(.headline)
                        .foregroundStyle(Color.ink)
                    Text(category.summary)
                        .font(.footnote)
                        .foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.seal.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.inkMuted)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The named stages of making a card, with the current one in progress. Can be cancelled.
private struct GenerationProgress: View {
    let current: CardCreatorViewModel.Stage
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(CardCreatorViewModel.Stage.allCases, id: \.self) { stage in
                HStack(spacing: 12) {
                    Group {
                        if stage == current {
                            ProgressView()
                        } else if isDone(stage) {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.successText)
                        } else {
                            Image(systemName: "circle").foregroundStyle(Color.inkMuted)
                        }
                    }
                    .frame(width: 24)
                    Text(stage.title)
                        .font(.callout)
                        .foregroundStyle(stage == current ? Color.ink : Color.inkMuted)
                }
                .accessibilityElement(children: .combine)
            }
            Button("Abbrechen", action: cancel)
                .buttonStyle(.brawl())
        }
        .inkPanel()
    }

    private func isDone(_ stage: CardCreatorViewModel.Stage) -> Bool {
        let stages = CardCreatorViewModel.Stage.allCases
        return stages.firstIndex(of: stage)! < stages.firstIndex(of: current)!
    }
}

/// An error right where it happened: a triangle, what happened, why and what to do.
private struct InlineError: View {
    let error: AppError

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(error.title, systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(Color.dangerText)
            Text([error.failureReason, error.recoverySuggestion].compactMap(\.self).joined(separator: " "))
                .font(.callout)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The new card, big, with a single way on.
private struct CreatedCardView: View {
    let card: FighterCard
    let done: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Label("Deine neue Karte", systemImage: "sparkles")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Color.ink)
                FighterCardView(content: card)
                    .frame(maxWidth: 360)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(card.accessibilityLabel(isCrumpled: false))
                Button("Fertig", action: done)
                    .buttonStyle(.brawl(.primary))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
        }
        .background(Color.paper)
    }
}

#Preview {
    let environment = AppEnvironment.launch(arguments: ["-ui-testing", "-sample-photo"])
    CardCreatorView(viewModel: environment.makeCreatorViewModel(photo: nil))
}
