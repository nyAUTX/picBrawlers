import SwiftUI

extension View {
    /// The design system's panel: `paper-raised` ground, ink frame at `border-heavy`, hard offset shadow.
    func inkPanel(cornerRadius: CGFloat = 12) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        return self
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.paperRaised, in: shape)
            .overlay(shape.strokeBorder(Color.ink, lineWidth: 3))
            .background(shape.fill(Color.shadowInk).offset(x: 4, y: 4))
    }
}
