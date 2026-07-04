import XCTest

final class DoesTrackUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-reset-for-ui-testing"]
        app.launch()
    }

    func testCoreReplicaFlowsEndToEnd() throws {
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Good'")).firstMatch.waitForExistence(timeout: 8))

        createProtocolWithCatalogMedication()
        verifyHomeAndCustomization()
        verifyHydrationCard()
        verifyCalendarAndNotifications()
        verifyTrackerAndStacks()
        verifyPulseSurfaces()
        verifyProfileSettingsAndSync()
    }

    private func verifyHydrationCard() {
        app.buttons["Customize home"].waitAndTap()
        app.swipeUp()
        if app.buttons["Pin Hydration"].waitForExistence(timeout: 3) {
            app.buttons["Pin Hydration"].tap()
        }
        app.buttons["Close customize home"].waitAndTap()

        XCTAssertTrue(app.staticTexts["HYDRATION"].waitForExistence(timeout: 4))
        app.swipeUp()
        app.buttons["Hydration"].firstMatch.waitAndTap()
        XCTAssertTrue(app.staticTexts["8 / 100 oz"].waitForExistence(timeout: 4))
    }

    private func createProtocolWithCatalogMedication() {
        app.buttons["Add Protocol"].waitAndTap()
        XCTAssertTrue(app.staticTexts["Edit Protocol"].waitForExistence(timeout: 4))

        let nameField = app.textFields["Protocol name"]
        nameField.waitAndTap()
        nameField.typeText("TRT+")

        let searchField = app.textFields["Search medications..."]
        searchField.waitAndTap()
        searchField.typeText("Tirzepatide")
        app.staticTexts["Tirzepatide"].firstMatch.waitAndTap()

        app.buttons["Next"].waitAndTap()
        app.buttons["Schedule"].waitAndTap()
        XCTAssertTrue(app.staticTexts["Start Date"].waitForExistence(timeout: 3))
        app.buttons["Preferences"].waitAndTap()
        XCTAssertTrue(app.switches["Notifications enabled"].waitForExistence(timeout: 3))
        app.buttons["Dose"].waitAndTap()
        app.buttons["Next"].waitAndTap()

        if app.switches["Add Inventory"].firstMatch.waitForExistence(timeout: 2) {
            app.switches["Add Inventory"].firstMatch.tap()
        }

        app.buttons["Next"].waitAndTap()
        XCTAssertTrue(app.staticTexts["Protocol"].waitForExistence(timeout: 3))
        app.buttons["Save"].waitAndTap()

        XCTAssertTrue(app.staticTexts["TRT+"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["FOR YOU"].exists)
    }

    private func verifyDoseLoggingSheet() {
        app.staticTexts[nextVisibleTRTDayLabel()].firstMatch.waitAndTap()
        XCTAssertTrue(app.staticTexts["TRT+"].waitForExistence(timeout: 4))

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Log '")).firstMatch.waitAndTap()
        XCTAssertTrue(app.staticTexts["Log New Dose"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Injection Site"].waitForExistence(timeout: 3))

        app.buttons["Skip this dose"].waitAndTap()
        XCTAssertTrue(app.staticTexts["Skip this dose?"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Traveling"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].waitAndTap()

        app.buttons["Wasted dose"].waitAndTap()
        XCTAssertTrue(app.staticTexts["Wasted Dose"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Record Wasted Dose"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].waitAndTap()

        app.buttons["Advanced"].waitAndTap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Pain Level'")).firstMatch.waitForExistence(timeout: 3))

        app.buttons["Log Dose"].waitAndTap()
        XCTAssertTrue(app.staticTexts["Taken"].waitForExistence(timeout: 4))
    }

    private func nextVisibleTRTDayLabel() -> String {
        let calendar = Calendar.current
        for offset in 0...3 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: Date()) else { continue }
            let weekday = calendar.component(.weekday, from: date)
            if weekday == 2 || weekday == 5 {
                return "\(calendar.component(.day, from: date))"
            }
        }
        return "\(calendar.component(.day, from: Date()))"
    }

    private func verifyHomeAndCustomization() {
        verifyDoseLoggingSheet()
        app.buttons["Customize home"].waitAndTap()
        XCTAssertTrue(app.staticTexts["Customize home"].waitForExistence(timeout: 4))

        if app.buttons["Pin Today Doses"].waitForExistence(timeout: 2) {
            app.buttons["Pin Today Doses"].tap()
        }

        app.buttons["Close customize home"].waitAndTap()
        XCTAssertTrue(app.staticTexts["TODAY DOSES"].waitForExistence(timeout: 4))
    }

    private func verifyCalendarAndNotifications() {
        app.buttons["Open calendar"].waitAndTap()
        XCTAssertTrue(app.staticTexts["Upcoming Shots"].waitForExistence(timeout: 4))
        app.buttons["Add Dose"].waitAndTap()
        XCTAssertTrue(app.navigationBars["Add Dose"].waitForExistence(timeout: 4))
        app.buttons["Cancel"].waitAndTap()
        app.buttons["Close calendar"].waitAndTap()

        app.buttons["Open notifications"].waitAndTap()
        XCTAssertTrue(app.staticTexts["Notifications"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Daily Summary"].waitForExistence(timeout: 4))
        app.buttons["Upcoming"].waitAndTap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'due'")).firstMatch.waitForExistence(timeout: 4))

        if app.buttons["Taken"].firstMatch.waitForExistence(timeout: 2) {
            app.buttons["Taken"].firstMatch.tap()
            XCTAssertTrue(app.staticTexts["TAKEN"].waitForExistence(timeout: 3))
        }

        app.buttons["Reminders"].waitAndTap()
        XCTAssertTrue(app.staticTexts["Weekly Check-In"].waitForExistence(timeout: 3))
        app.buttons.matching(NSPredicate(format: "label IN {'Check In', 'Checked In'}")).firstMatch.waitAndTap()
        XCTAssertTrue(app.staticTexts["How are you feeling?"].waitForExistence(timeout: 4))
        app.buttons["Mood 4"].waitAndTap()
        app.buttons["Save check in"].waitAndTap()
        XCTAssertTrue(app.staticTexts["DONE"].waitForExistence(timeout: 3))
        app.buttons["Close notifications"].waitAndTap()
    }

    private func verifyTrackerAndStacks() {
        app.tabBars.buttons["Tracker"].waitAndTap()
        XCTAssertTrue(app.staticTexts["Protocol Score"].waitForExistence(timeout: 4))
        app.buttons["Show more"].waitAndTap()
        XCTAssertTrue(app.staticTexts["Optimization Stacks"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["TRT+"].waitForExistence(timeout: 3))
        app.buttons["Close optimization stacks"].waitAndTap()
    }

    private func verifyPulseSurfaces() {
        app.tabBars.buttons["Pulse"].waitAndTap()
        XCTAssertTrue(app.staticTexts["Pulse"].waitForExistence(timeout: 4))

        app.buttons["Open your latest review"].waitAndTap()
        XCTAssertTrue(app.navigationBars["Fortnightly Review"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Recommendations"].waitForExistence(timeout: 3))
        app.buttons["Done"].waitAndTap()

        app.buttons["Symptoms"].waitAndTap()
        XCTAssertTrue(app.navigationBars["Symptoms"].waitForExistence(timeout: 4))
        app.buttons["Done"].waitAndTap()

        app.buttons["Dose History"].waitAndTap()
        XCTAssertTrue(app.navigationBars["Dose History"].waitForExistence(timeout: 4))
        app.buttons["Done"].waitAndTap()

        app.buttons["Risk Factors"].waitAndTap()
        XCTAssertTrue(app.navigationBars["Risk Factors"].waitForExistence(timeout: 4))
        app.buttons["Done"].waitAndTap()

        app.buttons["PK Model"].waitAndTap()
        XCTAssertTrue(app.navigationBars["PK Model"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Citations"].waitForExistence(timeout: 4))
        app.buttons["Done"].waitAndTap()

        app.buttons["Optimize Your Stack"].waitAndTap()
        XCTAssertTrue(app.staticTexts["Optimization Stacks"].waitForExistence(timeout: 4))
        app.buttons["Close optimization stacks"].waitAndTap()

        app.buttons["How does my dose work?"].waitAndTap()
        XCTAssertTrue(app.navigationBars["How does my dose work?"].waitForExistence(timeout: 4))
        app.buttons["Done"].waitAndTap()

        let prompt = app.textFields["Ask DoesTrack..."]
        prompt.waitAndTap()
        prompt.typeText("next dose")
        app.buttons["Ask DoesTrack"].waitAndTap()
        XCTAssertTrue(app.staticTexts["Schedule Summary"].waitForExistence(timeout: 4))
    }

    private func verifyProfileSettingsAndSync() {
        app.tabBars.buttons["Profile"].waitAndTap()
        XCTAssertTrue(app.staticTexts["Profile"].waitForExistence(timeout: 4))
        app.swipeUp()
        app.buttons["App Settings"].waitAndTap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 4))

        app.buttons["Notifications"].waitAndTap()
        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 4))
        app.buttons["Done"].waitAndTap()

        app.buttons["Health Data"].waitAndTap()
        XCTAssertTrue(app.navigationBars["Health Data"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Connect & Sync"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["SYNCED METRICS"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Latest Weight"].waitForExistence(timeout: 4))
        app.buttons["Done"].waitAndTap()

        app.buttons["Medical Citations"].waitAndTap()
        XCTAssertTrue(app.navigationBars["Medical Citations"].waitForExistence(timeout: 4))
        app.buttons["Done"].waitAndTap()

        app.buttons["Data Management"].waitAndTap()
        XCTAssertTrue(app.navigationBars["Sync"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.secureTextFields["GitHub token"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Sign In"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Choose Repository"].waitForExistence(timeout: 4))
        app.swipeUp()
        app.buttons["Manual repository settings"].waitAndTap()
        XCTAssertTrue(app.textFields["Owner"].waitForExistence(timeout: 4))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["Close settings"].waitAndTap()
    }
}

private extension XCUIElement {
    func waitAndTap(timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waitForExistence(timeout: timeout), "Missing element: \(self)", file: file, line: line)
        tap()
    }
}
