import SwiftUI

/// Animation presets based on Apple's shipped spring values (see the apple-design skill in CLAUDE.md).
nonisolated enum Motion {
    /// Default for moving and repositioning: no overshoot.
    static let standard: Animation = .spring(duration: 0.4, bounce: 0)
    /// Only after a gesture that carried momentum, e.g. flinging a card.
    static let momentum: Animation = .spring(duration: 0.4, bounce: 0.2)
    /// Sheets and drawers.
    static let sheet: Animation = .spring(duration: 0.3, bounce: 0.2)
    /// Touch-down feedback on buttons and cards.
    static let press: Animation = .easeOut(duration: 0.1)
    /// Replaces every preset when Reduce Motion is on.
    static let reducedMotionFallback: Animation = .easeInOut(duration: 0.2)

    static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? reducedMotionFallback : animation
    }
}

/// How pressed controls react: shrink slightly, or dim instead when Reduce Motion is on.
nonisolated enum PressFeedback {
    static func scale(isPressed: Bool, reduceMotion: Bool) -> CGFloat {
        isPressed && !reduceMotion ? 0.97 : 1
    }

    static func opacity(isPressed: Bool, reduceMotion: Bool) -> Double {
        isPressed && reduceMotion ? 0.7 : 1
    }
}

/// Reacts on touch-down, as Apple's own controls do. Use for custom tappable content such as cards.
struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(PressFeedback.scale(isPressed: configuration.isPressed, reduceMotion: reduceMotion))
            .opacity(PressFeedback.opacity(isPressed: configuration.isPressed, reduceMotion: reduceMotion))
            .animation(Motion.animation(Motion.press, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}
