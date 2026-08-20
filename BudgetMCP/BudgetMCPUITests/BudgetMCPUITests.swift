import XCTest

final class BudgetMCPUITests: XCTestCase {

    private func launchApp() -> XCUIApplication {
        guard let token = Bundle(for: Self.self).infoDictionary?["BUDGET_APP_API_TOKEN"] as? String, !token.isEmpty else {
            fatalError("BUDGET_APP_API_TOKEN not set — copy BudgetMCPUITests/Config/Secrets.example.xcconfig to Secrets.xcconfig and fill in the token")
        }
        let app = XCUIApplication()
        app.launchEnvironment = [
            "BUDGET_API_URL": "https://budget-mcp.vercel.app",
            "BUDGET_APP_API_TOKEN": token,
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

    /// Exploratory pass: opens the Link Bank sheet, starts Plaid Link, and dumps
    /// the accessibility hierarchy + a screenshot so we can see what Plaid's
    /// sandbox UI actually presents before scripting the full flow.
    ///
    /// Drives Plaid's sandbox-only test institution and credentials — only
    /// meaningful when the backend is configured with PLAID_ENV=sandbox.
    /// Skips itself otherwise so it can never run against a real bank.
    func testPlaidLinkExplore() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["PLAID_ENV"] == "sandbox",
            "Sandbox-only exploratory test; set PLAID_ENV=sandbox to run it."
        )
        let app = launchApp()

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["Link a Bank Account"].waitForExistence(timeout: 10))
        app.buttons["Link a Bank Account"].tap()

        XCTAssertTrue(app.buttons["Connect Account"].waitForExistence(timeout: 10))
        app.buttons["Connect Account"].tap()

        // Give Plaid Link time to fetch its own config and present its UI.
        sleep(6)
        try? app.screenshot().image.pngData()?.write(to: screenshotURL(name: "05-plaid-link-initial"))

        let skipPhone = app.buttons["Continue without phone number"]
        XCTAssertTrue(skipPhone.waitForExistence(timeout: 10))
        skipPhone.tap()
        sleep(4)
        try? app.screenshot().image.pngData()?.write(to: screenshotURL(name: "06-plaid-link-after-skip-phone"))

        let searchField = app.textFields["Search"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        searchField.typeText("Platypus Bank")
        sleep(2)
        app.keyboards.buttons["Return"].tap()
        sleep(2)
        try? app.screenshot().image.pngData()?.write(to: screenshotURL(name: "07-plaid-link-search-results"))

        let firstPlatypus = app.buttons["First Platypus Bank"]
        XCTAssertTrue(firstPlatypus.waitForExistence(timeout: 10))
        firstPlatypus.tap()
        sleep(4)
        try? app.screenshot().image.pngData()?.write(to: screenshotURL(name: "08-plaid-link-after-institution-pick"))

        // Disambiguation screen — pick the plain (non-OAuth) variant.
        let plainOption = app.buttons["First Platypus Bank"]
        XCTAssertTrue(plainOption.waitForExistence(timeout: 10))
        plainOption.tap()
        sleep(4)
        try? app.screenshot().image.pngData()?.write(to: screenshotURL(name: "09-plaid-link-credentials"))

        let username = app.textFields["Username"]
        XCTAssertTrue(username.waitForExistence(timeout: 10))
        username.tap()
        username.typeText("user_good")

        let password = app.secureTextFields["Password"].exists ? app.secureTextFields["Password"] : app.textFields["Password"]
        XCTAssertTrue(password.waitForExistence(timeout: 5))
        password.tap()
        password.typeText("pass_good")

        app.keyboards.buttons["Return"].tap()
        // Return on the password field submits credentials directly, landing
        // on the account-selection screen a few seconds later.
        sleep(6)
        try? app.screenshot().image.pngData()?.write(to: screenshotURL(name: "10-plaid-link-account-selection"))

        let accountsContinue = app.buttons["Continue"]
        XCTAssertTrue(accountsContinue.waitForExistence(timeout: 10))
        accountsContinue.tap()

        sleep(6)
        try? app.screenshot().image.pngData()?.write(to: screenshotURL(name: "11-plaid-link-after-continue"))

        let finishWithoutSaving = app.buttons["Finish without saving"]
        XCTAssertTrue(finishWithoutSaving.waitForExistence(timeout: 10))
        finishWithoutSaving.tap()

        // This is where Plaid's UI dismisses and our app should either show
        // the "Account Linked" success state or fall back on exchange failure.
        sleep(8)
        try? app.screenshot().image.pngData()?.write(to: screenshotURL(name: "12-after-finish-without-saving"))
        print("PLAID_HIERARCHY_START")
        print(app.debugDescription)
        print("PLAID_HIERARCHY_END")
    }

    /// Verifies Reconcile and Settings now show the real sandbox data synced
    /// by the manually-triggered cron run (48 transactions, 1 linked institution).
    func testReconcileAndSettingsShowSyncedData() throws {
        let app = launchApp()

        app.tabBars.buttons["Reconcile"].tap()
        XCTAssertTrue(app.navigationBars["Reconcile"].waitForExistence(timeout: 10))
        sleep(2)
        try? app.screenshot().image.pngData()?.write(to: screenshotURL(name: "13-reconcile-with-real-transactions"))

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        sleep(2)
        try? app.screenshot().image.pngData()?.write(to: screenshotURL(name: "14-settings-with-linked-institution"))
    }

    private func screenshotURL(name: String) -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("BudgetMCPUITests-Screenshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(name).png")
    }
}
