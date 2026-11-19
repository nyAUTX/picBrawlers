import SwiftUI

/// A full-screen loading state with a message saying what is happening.
/// Prefer placeholders in the final layout (`.redacted(reason: .placeholder)`) where the layout is known.
struct LoadingView: View {
    var message: LocalizedStringKey = "Wird geladen …"

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    LoadingView(message: "Foto wird analysiert …")
}
