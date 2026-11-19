import UIKit

/// Plays haptics from code that isn't driven by a view change (e.g. ViewModels).
/// In views, prefer the `.haptic(_:trigger:)` modifier. Tests inject a fake.
protocol HapticsService {
    func play(_ event: HapticEvent)
}

/// Plays haptics on the device with UIKit's feedback generators.
/// The system skips them automatically when the player has turned haptics off.
struct SystemHapticsService: HapticsService {
    func play(_ event: HapticEvent) {
        switch event {
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .hit:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavyHit, .crumple:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .support:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .failure:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .invalidAction:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
}
