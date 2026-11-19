import SwiftUI

extension View {
    /// Centers the content in the available space and lets it scroll only when it doesn't fit,
    /// e.g. at large Dynamic Type sizes. Without this, full-screen states get clipped.
    func scrollableWhenTooTall() -> some View {
        modifier(ScrollableWhenTooTall())
    }
}

private struct ScrollableWhenTooTall: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
