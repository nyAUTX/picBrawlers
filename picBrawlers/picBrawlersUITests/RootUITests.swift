import XCTest

final class RootUITests: XCTestCase {
    private let tabs = ["Sammlung", "Kämpfe", "Tauschen"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAllTabsShowTheirEmptyState() throws {
        let app = XCUIApplication()
        app.launch()

        for tab in tabs {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Tab \(tab) fehlt")
            button.tap()
            XCTAssertTrue(app.navigationBars[tab].waitForExistence(timeout: 2), "Titel \(tab) fehlt")
        }
    }

    @MainActor
    func testEveryTabPassesTheAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launch()

        for tab in tabs {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.tap()
            // Audit only once the tab switch has settled, otherwise text caught mid-transition is flagged.
            XCTAssertTrue(app.navigationBars[tab].waitForExistence(timeout: 2))
            try app.performAccessibilityAudit()
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
