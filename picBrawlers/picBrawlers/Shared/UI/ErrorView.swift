import SwiftUI

/// A full-screen error state: what happened, why, what to do, and a retry button when retrying makes sense.
struct ErrorView: View {
    let error: AppError
    var retry: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(error.title, systemImage: "exclamationmark.triangle.fill")
        } description: {
            Text([error.failureReason, error.recoverySuggestion].compactMap(\.self).joined(separator: " "))
        } actions: {
            if let retry {
                Button("Erneut versuchen", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .scrollableWhenTooTall()
    }
}

#Preview {
    ErrorView(error: AppError(title: "Karten konnten nicht geladen werden", cause: .offline)) {}
}
