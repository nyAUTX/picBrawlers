import XCTest

/// The effects screen is only in debug builds, which is what UI tests run.
final class LineupUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func openEffects() -> XCUIApplication {
        let app = XCUIApplication.forUITesting()
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

    @MainActor
    private func auditIgnoringCardFaces(_ app: XCUIApplication) throws {
        XCTAssertEqual(app.cardFaces.count, 3)
        try app.auditIgnoringCardFaces()
    }
}
