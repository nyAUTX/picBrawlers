import XCTest

/// The effects screen is only in debug builds, which is what UI tests run.
final class LineupUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func openEffects() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Kämpfe"].tap()
        let effects = app.navigationBars["Kämpfe"].buttons["Effekte"]
        XCTAssertTrue(effects.waitForExistence(timeout: 5))
        effects.tap()
        XCTAssertTrue(app.navigationBars["Effekte"].waitForExistence(timeout: 2))
        return app
    }

    @MainActor
    func testAHitCrumplesACardAndIroningFlattensIt() throws {
        let app = openEffects()
        let oma = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Oma Gerti'")).firstMatch
        XCTAssertTrue(oma.waitForExistence(timeout: 2))
        XCTAssertFalse(oma.label.hasSuffix("zerknittert"))

        app.buttons["Treffer"].tap()
        XCTAssertTrue(oma.label.hasSuffix("zerknittert"))

        app.buttons["Bügeln"].tap()
        let flat = NSPredicate(format: "NOT (label ENDSWITH 'zerknittert')")
        expectation(for: flat, evaluatedWith: oma)
        waitForExpectations(timeout: 6)
    }

    @MainActor
    func testEffectsScreenPassesTheAccessibilityAudit() throws {
        let app = openEffects()
        try auditIgnoringCardFaces(app)
        app.buttons["Treffer"].tap()
        try auditIgnoringCardFaces(app)
    }

    /// Cards are printed objects: the face keeps its playing-card proportions and VoiceOver reads the whole
    /// card as one sentence. The audit still inspects the text printed on the face, so three kinds of issue
    /// are expected there and only there: a fixed text size (larger text sizes get larger cards instead),
    /// text the card scales down to fit, and lower contrast on a crumpled card, which is meant to look knocked out.
    @MainActor
    private func auditIgnoringCardFaces(_ app: XCUIApplication) throws {
        let cards = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS ' Leben, '"))
            .allElementsBoundByIndex
            .map { $0.frame.insetBy(dx: -24, dy: -24) }
        XCTAssertEqual(cards.count, 3)
        let expectedOnCardFaces: [XCUIAccessibilityAuditType] = [.dynamicType, .textClipped, .contrast]
        try app.performAccessibilityAudit { issue in
            guard expectedOnCardFaces.contains(issue.auditType), let element = issue.element else { return false }
            let frame = element.frame
            return cards.contains { $0.contains(frame) }
        }
    }
}
