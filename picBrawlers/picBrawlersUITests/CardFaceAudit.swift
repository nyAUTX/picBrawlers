import XCTest

extension XCUIApplication {
    /// UI tests start with an empty in-memory collection.
    static func forUITesting(samplePhoto: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + (samplePhoto ? ["-sample-photo"] : [])
        return app
    }

    /// The fighter cards on screen, found by their VoiceOver sentence.
    var cardFaces: [XCUIElement] {
        descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS ' Leben, '"))
            .allElementsBoundByIndex
    }

    /// Cards are printed objects: the face keeps its playing-card proportions and VoiceOver reads the whole
    /// card as one sentence. The audit still inspects the text printed on the face, so three kinds of issue
    /// are expected there and only there: a fixed text size (larger text sizes get larger cards instead),
    /// text the card scales down to fit, and lower contrast on a crumpled card, which is meant to look knocked out.
    /// Contrast is also not judged behind the tab bar (see below).
    @MainActor
    func auditIgnoringCardFaces() throws {
        let cards = cardFaces.map { $0.frame.insetBy(dx: -24, dy: -24) }
        let tabBar = tabBars.firstMatch.exists ? tabBars.firstMatch.frame : .null
        let expectedOnCardFaces: [XCUIAccessibilityAuditType] = [.dynamicType, .textClipped, .contrast]
        try performAccessibilityAudit { issue in
            guard let element = issue.element else { return false }
            let frame = element.frame
            // Content scrolled behind the translucent tab bar is measured against the glass. It's read
            // once scrolled up, so contrast issues there are expected; everywhere else they still fail.
            if issue.auditType == .contrast && frame.intersects(tabBar) { return true }
            guard expectedOnCardFaces.contains(issue.auditType) else { return false }
            return cards.contains { $0.contains(frame) }
        }
    }
}
