import SwiftUI

/// Shows the right view for a `ViewState`: loading, empty, error or the content.
struct ViewStateView<Value, Content: View, Empty: View>: View {
    let state: ViewState<Value>
    var loadingMessage: LocalizedStringKey = "Wird geladen …"
    var retry: (() -> Void)?
    @ViewBuilder let content: (Value) -> Content
    @ViewBuilder let empty: () -> Empty

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch state {
            case .loading:
                LoadingView(message: loadingMessage)
            case .empty:
                empty()
            case .loaded(let value):
                content(value)
            case .failed(let error):
                ErrorView(error: error, retry: retry)
            }
        }
        .animation(Motion.animation(Motion.standard, reduceMotion: reduceMotion), value: state.phase)
    }
}

private extension ViewState {
    /// Which case the state is in, ignoring its payload, so changes between cases can be animated.
    var phase: Int {
        switch self {
        case .loading: 0
        case .empty: 1
        case .loaded: 2
        case .failed: 3
        }
    }
}

#Preview("Fehler") {
    ViewStateView(
        state: ViewState<[String]>.failed(AppError(title: "Karten konnten nicht geladen werden", cause: .timedOut)),
        retry: {}
    ) { cards in
        List(cards, id: \.self) { Text($0) }
    } empty: {
        EmptyStateView(title: "Noch keine Karten", systemImage: "rectangle.stack", message: "Erstelle deine erste Karte.")
    }
}
