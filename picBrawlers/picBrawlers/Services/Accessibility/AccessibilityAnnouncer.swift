import SwiftUI

/// Speaks a short message with VoiceOver, for things that change on screen without the player's focus,
/// such as a card being crumpled.
protocol AccessibilityAnnouncing: AnyObject {
    func announce(_ message: String)
}

final class SystemAccessibilityAnnouncer: AccessibilityAnnouncing {
    func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}
