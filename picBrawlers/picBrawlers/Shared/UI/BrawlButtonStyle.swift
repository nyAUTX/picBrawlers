import SwiftUI

/// The design system's push button: ink frame, flat fill, hard shadow. On touch-down it slides into its shadow.
struct BrawlButtonStyle: ButtonStyle {
    enum Kind {
        /// The one thing this screen is for (`brawl` fill). At most one per screen.
        case primary
        /// A second filled action that commits something (`volt` fill).
        case volt
        /// Everything else (`paperRaised`).
        case plain
    }

    var kind: Kind = .plain

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && !reduceMotion
        let shape = RoundedRectangle(cornerRadius: 4)
        configuration.label
            .font(.headline.bold())
            .multilineTextAlignment(.center)
            .foregroundStyle(foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minWidth: 44, minHeight: 44)
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(Color.ink, lineWidth: 3))
            // A disabled button lies flat on the paper: no shadow to push into.
            .background(shape.fill(Color.shadowInk).offset(x: pressed ? 1 : 4, y: pressed ? 1 : 4).opacity(isEnabled ? 1 : 0))
            .offset(x: pressed ? 3 : 0, y: pressed ? 3 : 0)
            .scaleEffect(PressFeedback.scale(isPressed: configuration.isPressed, reduceMotion: reduceMotion))
            .opacity(PressFeedback.opacity(isPressed: configuration.isPressed, reduceMotion: reduceMotion))
            .animation(Motion.animation(Motion.press, reduceMotion: reduceMotion), value: configuration.isPressed)
            .contentShape(shape)
    }

    private var foreground: Color {
        if !isEnabled { return .inkMuted }
        return kind == .plain ? .ink : .onFill
    }

    /// Disabled buttons use `paper-sunken`, as the design system says.
    private var fill: Color {
        guard isEnabled else { return .paperSunken }
        return switch kind {
        case .primary: .brawl
        case .volt: .volt
        case .plain: .paperRaised
        }
    }
}

extension ButtonStyle where Self == BrawlButtonStyle {
    static func brawl(_ kind: BrawlButtonStyle.Kind = .plain) -> BrawlButtonStyle { BrawlButtonStyle(kind: kind) }
}
