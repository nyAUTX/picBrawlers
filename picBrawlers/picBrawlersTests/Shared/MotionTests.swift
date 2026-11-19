import SwiftUI
import Testing
@testable import picBrawlers

@Suite("Motion")
struct MotionTests {
    @Test func presetsUseAppleSpringValues() {
        #expect(Motion.standard == .spring(duration: 0.4, bounce: 0))
        #expect(Motion.momentum == .spring(duration: 0.4, bounce: 0.2))
        #expect(Motion.sheet == .spring(duration: 0.3, bounce: 0.2))
        #expect(Motion.press == .easeOut(duration: 0.1))
    }

    @Test(arguments: [Motion.standard, Motion.momentum, Motion.sheet, Motion.press])
    func reduceMotionReplacesEveryPresetWithACrossFade(animation: Animation) {
        #expect(Motion.animation(animation, reduceMotion: true) == Motion.reducedMotionFallback)
        #expect(Motion.reducedMotionFallback == .easeInOut(duration: 0.2))
    }

    @Test(arguments: [Motion.standard, Motion.momentum, Motion.sheet, Motion.press])
    func animationIsUnchangedWithoutReduceMotion(animation: Animation) {
        #expect(Motion.animation(animation, reduceMotion: false) == animation)
    }

    @Test func pressedButtonsShrinkSlightly() {
        #expect(PressFeedback.scale(isPressed: true, reduceMotion: false) == 0.97)
        #expect(PressFeedback.scale(isPressed: false, reduceMotion: false) == 1)
        #expect(PressFeedback.opacity(isPressed: true, reduceMotion: false) == 1)
    }

    @Test func withReduceMotionPressedButtonsDimInsteadOfShrinking() {
        #expect(PressFeedback.scale(isPressed: true, reduceMotion: true) == 1)
        #expect(PressFeedback.opacity(isPressed: true, reduceMotion: true) == 0.7)
        #expect(PressFeedback.opacity(isPressed: false, reduceMotion: true) == 1)
    }
}
