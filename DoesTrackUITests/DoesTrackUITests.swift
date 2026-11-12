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

    func testNotificationPrivacySettings() throws {
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Good'")).firstMatch.waitForExistence(timeout: 8))

        app.tabBars.buttons["Profile"].waitAndTap()
        app.swipeUp()
        app.buttons["App Settings"].waitAndTap()
        app.buttons["Notifications"].waitAndTap()
        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.switches["Dose reminders"].waitForExistence(timeout: 4))
        attachScreenshot(named: "notification-settings-top")

        app.buttons["Once a day"].waitAndTap()
        XCTAssertTrue(app.staticTexts["A single reminder each day at your first dose time."].waitForExistence(timeout: 3))
        app.buttons["Every dose"].waitAndTap()

        app.swipeUp()
        app.buttons["Generic"].waitAndTap()
        XCTAssertTrue(app.textFields["Generic reminder title"].waitForExistence(timeout: 3))

        let hide = app.switches["Hide details on lock screen"]
        XCTAssertTrue(hide.waitForExistence(timeout: 3))
        hide.switches.firstMatch.tap()

        app.swipeUp()
        app.buttons["Quiet"].waitAndTap()
        let quietHours = app.switches["Quiet hours"]
        XCTAssertTrue(quietHours.waitForExistence(timeout: 3))
        quietHours.switches.firstMatch.tap()
        XCTAssertTrue(app.datePickers["From"].waitForExistence(timeout: 3) || app.staticTexts["From"].waitForExistence(timeout: 3))

        app.swipeUp()
        XCTAssertTrue(app.otherElements["Locked preview"].waitForExistence(timeout: 3) || app.staticTexts["Locked"].waitForExistence(timeout: 3))
        attachScreenshot(named: "notification-settings-discreet")
    }


    func testScreenshotTour() throws {
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Good'")).firstMatch.waitForExistence(timeout: 8))
        shot("01-home-empty")
        app.swipeUp(); shot("02-home-empty-scrolled"); app.swipeDown()
        createProtocolWithCatalogMedication()
        shot("03-home-with-protocol")
        app.swipeUp(); shot("04-home-scrolled"); app.swipeUp(); shot("05-home-scrolled2"); app.swipeDown(); app.swipeDown()
        app.buttons["Open calendar"].waitAndTap(); shot("06-calendar"); app.swipeUp(); shot("07-calendar-scrolled")
        app.buttons["Close calendar"].waitAndTap()
        app.buttons["Open notifications"].waitAndTap(); shot("08-notifications")
        app.buttons["Upcoming"].waitAndTap(); shot("09-notif-upcoming")
        app.buttons["Reminders"].waitAndTap(); shot("10-notif-reminders")
        app.buttons["Close notifications"].waitAndTap()
        app.buttons["Customize home"].waitAndTap(); shot("11-customize"); app.swipeUp(); shot("12-customize-scrolled")
        app.buttons["Close customize home"].waitAndTap()
        app.tabBars.buttons["Tracker"].waitAndTap(); sleep(1); shot("13-tracker"); app.swipeUp(); shot("14-tracker-scrolled")
        app.buttons["Open optimization stacks"].waitAndTap(); shot("15-stacks")
        app.buttons["Close optimization stacks"].waitAndTap()
        app.tabBars.buttons["Pulse"].waitAndTap(); sleep(1); shot("16-pulse"); app.swipeUp(); shot("17-pulse-scrolled")
        app.swipeDown()
        app.buttons["PK Model"].waitAndTap(); sleep(1); shot("18-pk"); app.buttons["Done"].waitAndTap()
        app.buttons["Open your latest review"].waitAndTap(); shot("19-review"); app.buttons["Done"].waitAndTap()
        app.tabBars.buttons["Profile"].waitAndTap(); sleep(1); shot("20-profile"); app.swipeUp(); shot("21-profile-scrolled")
        app.buttons["App Settings"].waitAndTap(); shot("22-settings")
        app.buttons["Notifications"].waitAndTap(); shot("23-notif-settings"); app.buttons["Done"].waitAndTap()
        app.buttons["Data Management"].waitAndTap(); shot("24-sync"); app.swipeUp(); shot("25-sync-scrolled")
    }


    func testFlowTour() throws {
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Good'")).firstMatch.waitForExistence(timeout: 8))
        shot("f00-home-empty")
        createProtocolWithCatalogMedication()
        shot("f01-home")
        app.buttons["Log unscheduled dose"].waitAndTap(); sleep(1); shot("f02-log-unscheduled")
        app.swipeUp(); shot("f03-log-unscheduled-scrolled")
        app.buttons["Log Dose"].waitAndTap(); sleep(1); shot("f04-after-log")
        app.swipeUp(); shot("f05-home-after-log-scrolled"); app.swipeDown(); app.swipeDown()
        app.buttons["Open notifications"].waitAndTap(); shot("f06-notifs-after-log"); app.buttons["Close notifications"].waitAndTap()
        app.tabBars.buttons["Tracker"].waitAndTap(); sleep(1); shot("f07-tracker-after-log")
        app.swipeUp(); shot("f08-tracker-scrolled")
        app.staticTexts["Tirzepatide"].firstMatch.tap(); sleep(1); shot("f09-med-detail"); app.swipeUp(); shot("f10-med-detail-scrolled")
        app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast); sleep(1)
        app.tabBars.buttons["Home"].tap()
        app.buttons["Open optimization stacks"].waitAndTap(); sleep(1); shot("f11-stacks")
        app.buttons["Pause TRT+"].waitAndTap(); sleep(1); shot("f12-after-pause")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Inactive'")).firstMatch.tap(); sleep(1); shot("f13-inactive")
        app.buttons["Delete TRT+"].waitAndTap(); sleep(1); shot("f14-delete-confirm")
        XCTAssertTrue(app.buttons["Delete Protocol"].waitForExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["TRT+"].exists, "Dismissing the delete dialog must keep the protocol")
        app.buttons["Resume TRT+"].waitAndTap()
        XCTAssertTrue(app.buttons["Active (1)"].waitForExistence(timeout: 4))
        app.buttons["Close optimization stacks"].waitAndTap(); sleep(1); shot("f15-home-after-resume")
    }

    func testOnboardingFlow() throws {
        relaunchShowingOnboarding()
        XCTAssertTrue(app.staticTexts["Welcome to DoesTrack"].waitForExistence(timeout: 8))
        shot("o01-welcome")
        app.buttons["Continue"].waitAndTap()

        let nameField = app.textFields["Your name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 4))
        nameField.tap()
        nameField.typeText("Sam\n")
        shot("o02-name")
        app.buttons["Look Around First"].waitAndTap()

        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Sam'")).firstMatch.waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["Add your first protocol"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Turn on reminders"].exists)
        sleep(1)
        shot("o03-home-checklist")

        // The welcome flow is shown once.
        app.terminate()
        app.launchArguments = ["-show-onboarding"]
        app.launch()
        XCTAssertTrue(app.buttons["Add Protocol"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Welcome to DoesTrack"].exists)

        // Choosing to set up a protocol lands in the editor.
        relaunchShowingOnboarding()
        app.buttons["Continue"].waitAndTap()
        app.buttons["Set Up My First Protocol"].waitAndTap()
        XCTAssertTrue(app.buttons["Next"].waitForExistence(timeout: 6))
        sleep(1)
        shot("o04-editor-after-welcome")
    }

    func testPauseOneSubstance() throws {
        // A two-substance template: Thymosin Alpha-1 + BPC-157.
        app.staticTexts["Immune Modulation Stack"].firstMatch.waitAndTap()
        for _ in 0..<5 where !app.buttons["Save"].exists {
            app.buttons["Next"].waitAndTap()
        }
        app.buttons["Save"].waitAndTap()

        app.buttons["Open optimization stacks"].waitAndTap()
        app.buttons["Expand Immune Modulation Stack"].waitAndTap()
        app.buttons["Pause BPC-157"].waitAndTap()
        app.buttons["Pause Until I Resume"].waitAndTap()

        XCTAssertTrue(app.staticTexts["1 of 2 paused"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Partly active"].exists)
        XCTAssertTrue(app.buttons["Pause Thymosin Alpha-1"].exists)
        XCTAssertTrue(app.buttons["Resume BPC-157"].exists)
        sleep(1)
        shot("p01-stacks-partly-paused")
        app.buttons["Close optimization stacks"].waitAndTap()

        // Home keeps the paused substance visible with a resume button.
        let resume = app.buttons["Resume BPC-157"]
        if !resume.waitForExistence(timeout: 4) { app.swipeUp() }
        XCTAssertTrue(resume.waitForExistence(timeout: 4))
        sleep(1)
        shot("p02-home-paused")

        // Find a day with a dose due so the protocol menu is on screen.
        app.swipeDown()
        let calendar = Calendar.current
        for offset in 0...6 where !app.buttons["Immune Modulation Stack actions"].exists {
            guard let day = calendar.date(byAdding: .day, value: offset, to: Date()) else { continue }
            app.staticTexts["\(calendar.component(.day, from: day))"].firstMatch.tap()
            _ = app.buttons["Immune Modulation Stack actions"].waitForExistence(timeout: 1.5)
        }
        XCTAssertTrue(app.buttons["Immune Modulation Stack actions"].exists)
        if app.buttons["Immune Modulation Stack actions"].exists {
            app.buttons["Immune Modulation Stack actions"].tap()
            XCTAssertTrue(app.buttons["Pause Thymosin Alpha-1"].waitForExistence(timeout: 3))
            XCTAssertFalse(app.buttons["Pause BPC-157"].exists)
            shot("p03-home-menu")
            app.buttons["Pause Thymosin Alpha-1"].tap()
            sleep(1)
            shot("p04-pause-sheet")
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'whole protocol pauses'")).firstMatch.waitForExistence(timeout: 3))
            app.swipeDown(velocity: .fast)
            sleep(1)
        }

        if !resume.waitForExistence(timeout: 2) { app.swipeUp() }
        resume.waitAndTap()
        XCTAssertTrue(app.buttons["Resume BPC-157"].waitForNonExistence(timeout: 4))
    }

    private func relaunchShowingOnboarding() {
        app.terminate()
        app.launchArguments = ["-reset-for-ui-testing", "-show-onboarding"]
        app.launch()
    }

    private func shot(_ name: String) { attachScreenshot(named: name) }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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

        app.buttons["Next"].waitAndTap()
        XCTAssertTrue(app.staticTexts["Protocol"].waitForExistence(timeout: 3))
        app.buttons["Save"].waitAndTap()

        XCTAssertTrue(app.staticTexts["TRT+"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["FOR YOU"].exists)
    }

    private func verifyDoseLoggingSheet() {
        app.staticTexts[nextVisibleTRTDayLabel()].firstMatch.waitAndTap()
        XCTAssertTrue(app.staticTexts["TRT+"].waitForExistence(timeout: 4))

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Log ' AND label != 'Log your first dose' AND label != 'Log unscheduled dose'")).firstMatch.waitAndTap()
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

    /// Weekly schedules start on the protocol's start date, which is today.
    private func nextVisibleTRTDayLabel() -> String {
        "\(Calendar.current.component(.day, from: Date()))"
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
        XCTAssertTrue(app.staticTexts["Log New Dose"].waitForExistence(timeout: 4))
        app.buttons["Close log dose"].waitAndTap()
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
