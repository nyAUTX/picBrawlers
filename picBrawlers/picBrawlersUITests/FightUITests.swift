import XCTest

/// The pass-and-play test fight is only in debug builds, which is what UI tests run.
final class FightUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func openTestFight() -> XCUIApplication {
        let app = XCUIApplication.forUITesting()
        app.launch()
        app.tabBars.buttons["Kämpfe"].tap()
        let start = app.navigationBars["Kämpfe"].buttons["Testkampf"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        XCTAssertTrue(app.staticTexts["Gib das Handy an Spieler 1"].waitForExistence(timeout: 2))
        return app
    }

    @MainActor
    private func card(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
    }

    @MainActor
    private func playFirstTurn(_ app: XCUIApplication, startingFromHandover: Bool = true) {
        if startingFromHandover { app.buttons["Los geht's"].tap() }
        XCTAssertTrue(app.staticTexts["Aktion 1 von 2"].waitForExistence(timeout: 2))

        card("Kevin", in: app).tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Angriff: '")).firstMatch.tap()
        card("Linienbus", in: app).tap()

        card("Oma Gerti", in: app).tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Angriff: '")).firstMatch.tap()
        card("Linienbus", in: app).tap()

        app.buttons["Zug ausführen"].tap()
    }

    @MainActor
    func testATurnPlaysBothActionsThenHandsThePhoneOver() throws {
        let app = openTestFight()
        playFirstTurn(app)

        // Kevin (42) and Oma Gerti (15) both hit the bus: 160 − 57.
        XCTAssertTrue(card("Linienbus", in: app).label.contains("103 von 160 Leben"))
        let weiter = app.buttons["Weiter"]
        XCTAssertTrue(weiter.exists)
        weiter.tap()
        XCTAssertTrue(app.staticTexts["Gib das Handy an Spieler 2"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testResigningEndsTheFight() throws {
        let app = openTestFight()
        app.buttons["Los geht's"].tap()
        app.navigationBars["Kampf"].buttons["Aufgeben"].tap()
        app.sheets.buttons["Aufgeben"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Spieler 2 gewinnt"].waitForExistence(timeout: 2))
        app.buttons["Bügeln"].tap()
        app.navigationBars["Kampf"].buttons["Fertig"].tap()
        XCTAssertTrue(app.navigationBars["Kämpfe"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testTheFightPassesTheAccessibilityAudit() throws {
        let app = openTestFight()
        try app.performAccessibilityAudit()

        app.buttons["Los geht's"].tap()
        card("Kevin", in: app).tap()
        try app.performAccessibilityAudit()

        app.buttons["Abbrechen"].tap()
        playFirstTurn(app, startingFromHandover: false)
        try app.performAccessibilityAudit()
    }
}
