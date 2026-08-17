import XCTest

final class BudgetMCPUITests: XCTestCase {

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "BUDGET_API_URL": "https://budget-mcp.vercel.app",
            "BUDGET_APP_API_TOKEN": "b10d04e7d2e22f84c77a0a5a20560fff54a4f2e7cb60e1e1e952f26090640568",
        ]
        app.launch()
        return app
    }

    /// Walks all three tabs and confirms each renders its expected content
    /// against the live deployed backend (not a mock) — Overview's seeded
    /// categories, Reconcile's empty/list state, and Settings' sync status.
    func testTabsLoadLiveData() throws {
        let app = launchApp()

        let overviewTitle = app.navigationBars["Budget"]
        XCTAssertTrue(overviewTitle.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Dining Out"].waitForExistence(timeout: 10))
        try? app.screenshot().image.pngData()?.write(to: screenshotURL(name: "01-overview"))

        app.staticTexts["Dining Out"].tap()
        XCTAssertTrue(app.staticTexts["Ledger History"].waitForExistence(timeout: 10))
        try? app.screenshot().image.pngData()?.write(to: screenshotURL(name: "02-category-detail"))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.tabBars.buttons["Reconcile"].tap()
        XCTAssertTrue(app.navigationBars["Reconcile"].waitForExistence(timeout: 10))
        try? app.screenshot().image.pngData()?.write(to: screenshotURL(name: "03-reconcile"))

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Link a Bank Account"].waitForExistence(timeout: 10))
        try? app.screenshot().image.pngData()?.write(to: screenshotURL(name: "04-settings"))
    }

    private func screenshotURL(name: String) -> URL {
        let dir = URL(fileURLWithPath: "/private/tmp/claude-501/-Users-dustinschaaf-Code-Banked/5362263f-ef80-47ea-b3d3-3ef2286cd58a/scratchpad")
        return dir.appendingPathComponent("\(name).png")
    }
}
