import SwiftUI
import Testing
@testable import picBrawlers

@Suite("HapticEvent")
struct HapticEventTests {
    @Test(arguments: [
        (HapticEvent.selection, SensoryFeedback.selection),
        (.hit, .impact(weight: .medium)),
        (.heavyHit, .impact(weight: .heavy)),
        (.crumple, .impact(weight: .heavy)),
        (.support, .impact(flexibility: .soft)),
        (.success, .success),
        (.failure, .error),
        (.invalidAction, .warning),
    ])
    func mapsToSensoryFeedback(event: HapticEvent, expected: SensoryFeedback) {
        #expect(event.feedback == expected)
    }

    @Test func everyEventIsCoveredByTheMappingTest() {
        // Guards the table above: adding an event without a mapping test fails here.
        #expect(HapticEvent.allCases.count == 8)
    }
}
