import XCTest

/// Creating, opening and deleting a card. The system photo picker runs outside the app and can't be
/// driven reliably, so these tests start the creator with a sample photo (`-sample-photo`).
final class CardCreationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func openCreator() -> XCUIApplication {
        let app = XCUIApplication.forUITesting(samplePhoto: true)
        app.launch()
        app.buttons["Karte erstellen"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Neue Karte"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.images["Gewähltes Foto"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func fillIn(_ app: XCUIApplication, name: String) {
        let field = app.textFields["Name der Karte"]
        field.tap()
        field.typeText(name + "\n")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tank'")).firstMatch.tap()
    }

    /// The create button is below the fold.
    @MainActor
    private func createButton(_ app: XCUIApplication) -> XCUIElement {
        let button = app.buttons["createCard"]
        let form = app.scrollViews.firstMatch
        var swipes = 0
        while !(button.exists && button.isHittable) && swipes < 5 {
            form.swipeUp()
            swipes += 1
        }
        return button
    }

    @MainActor
    func testCreateOpenAndDeleteACard() throws {
        let app = openCreator()
        fillIn(app, name: "Oma Gerti")
        createButton(app).tap()

        XCTAssertTrue(app.staticTexts["Deine neue Karte"].waitForExistence(timeout: 5))
        app.buttons["Fertig"].tap()

        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Oma Gerti, Tank, '")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.navigationBars["Oma Gerti"].waitForExistence(timeout: 5))

        app.navigationBars["Oma Gerti"].buttons["Löschen"].tap()
        let confirm = app.buttons.matching(NSPredicate(format: "label == 'Löschen'")).allElementsBoundByIndex.last
        XCTAssertNotNil(confirm)
        confirm?.tap()

        XCTAssertTrue(app.staticTexts["Noch keine Karten"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCreatingNeedsANameAndACategory() throws {
        let app = openCreator()
        let field = app.textFields["Name der Karte"]
        field.tap()
        field.typeText(String(repeating: "a", count: 21) + "\n")
        XCTAssertTrue(app.staticTexts["Höchstens 20 Zeichen."].waitForExistence(timeout: 2))
        XCTAssertFalse(createButton(app).isEnabled)
    }

    @MainActor
    func testCreatorAndNewCardPassTheAccessibilityAudit() throws {
        let app = openCreator()
        try app.performAccessibilityAudit()

        fillIn(app, name: "Bello")
        createButton(app).tap()
        XCTAssertTrue(app.staticTexts["Deine neue Karte"].waitForExistence(timeout: 5))
        try app.auditIgnoringCardFaces()

        app.buttons["Fertig"].tap()
        XCTAssertTrue(app.navigationBars["Sammlung"].waitForExistence(timeout: 5))
        try app.auditIgnoringCardFaces()

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Bello, '")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Bello"].waitForExistence(timeout: 5))
        try app.auditIgnoringCardFaces()
    }
}
