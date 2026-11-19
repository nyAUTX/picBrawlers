import SwiftUI

/// The moments in the game that get haptic feedback. Keep this list short: haptics that fire
/// too often get ignored. See CLAUDE.md for when to use which.
nonisolated enum HapticEvent: CaseIterable, Sendable {
    case selection
    case hit
    case heavyHit
    case crumple
    case support
    case success
    case failure
    case invalidAction

    var feedback: SensoryFeedback {
        switch self {
        case .selection: .selection
        case .hit: .impact(weight: .medium)
        case .heavyHit: .impact(weight: .heavy)
        case .crumple: .impact(weight: .heavy)
        case .support: .impact(flexibility: .soft)
        case .success: .success
        case .failure: .error
        case .invalidAction: .warning
        }
    }
}

extension View {
    /// Plays the haptic for `event` whenever `trigger` changes, on the same frame as the view update.
    func haptic(_ event: HapticEvent, trigger: some Equatable) -> some View {
        sensoryFeedback(event.feedback, trigger: trigger)
    }
}
