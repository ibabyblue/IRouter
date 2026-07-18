import XCTest

/// Exercises live IRouter presentation and catalog behavior through the Example app.
@MainActor
final class IRouterDemoUITests: XCTestCase {
    /// The launched Example application for the current test.
    private var app: XCUIApplication!

    /// Stops each test immediately after its first assertion failure.
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Verifies that every documented router lab is reachable from the Example catalog.
    func testCatalogExposesAllFiveLabs() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        for title in ["Stack", "Filters", "Modals", "Nested", "Routers"] {
            XCTAssertTrue(app.tabBars.buttons[title].waitForExistence(timeout: 2))
        }
    }

    /// Verifies that a child router can dismiss the sheet owned by its parent.
    func testChildRouterDismissesOwningSheet() {
        launchApp()

        app.buttons["demo.modals.openSheetA"].tap()
        let modalA = app.collectionViews["demo.modal.A"]
        XCTAssertTrue(modalA.waitForExistence(timeout: 2))

        app.buttons["demo.modal.dismissCurrent"].tap()

        XCTAssertTrue(waitForDisappearance(modalA))
        XCTAssertEqual(app.staticTexts["demo.state.modal"].label, "None")
    }

    /// Verifies that sheet-to-cover replacement never presents both modals together.
    func testSheetToCoverReplacementIsSerialized() {
        launchApp()

        app.buttons["demo.modals.openSheetA"].tap()
        let modalA = app.collectionViews["demo.modal.A"]
        XCTAssertTrue(modalA.waitForExistence(timeout: 2))

        app.buttons["demo.modals.replaceWithCoverB"].tap()

        let modalB = app.collectionViews["demo.modal.B"]
        let finalState = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate { _, _ in !modalA.exists },
            NSPredicate { _, _ in modalB.exists },
        ])
        let finalStateReached = XCTNSPredicateExpectation(
            predicate: finalState,
            object: app as Any
        )
        let overlappingState = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate { _, _ in modalA.exists },
            NSPredicate { _, _ in modalB.exists },
        ])
        let overlappingStateReached = XCTNSPredicateExpectation(
            predicate: overlappingState,
            object: app as Any
        )
        overlappingStateReached.isInverted = true
        let result = XCTWaiter.wait(
            for: [finalStateReached, overlappingStateReached],
            timeout: 2
        )

        XCTAssertEqual(result, .completed)
        XCTAssertFalse(modalA.exists)
        XCTAssertTrue(modalB.exists)
    }

    /// Verifies that rapid modal replacement presents only the latest context.
    func testRapidReplacementPresentsOnlyLatestContext() {
        launchApp()

        app.buttons["demo.modals.openSheetA"].tap()
        XCTAssertTrue(app.collectionViews["demo.modal.A"].waitForExistence(timeout: 2))

        app.buttons["demo.modals.rapidReplaceABC"].tap()

        let modalB = app.collectionViews["demo.modal.B"]
        let modalBExists = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: modalB
        )
        modalBExists.isInverted = true
        let modalC = app.collectionViews["demo.modal.C"]
        let modalCExists = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: modalC
        )
        let result = XCTWaiter.wait(
            for: [modalCExists, modalBExists],
            timeout: 2
        )

        XCTAssertEqual(result, .completed)
        XCTAssertTrue(modalC.exists)
        XCTAssertFalse(modalB.exists)
    }

    /// Verifies that interactive sheet dismissal clears router-owned modal state.
    func testInteractiveDismissalClearsRouterInspector() {
        launchApp()

        app.buttons["demo.modals.openSheetA"].tap()
        let modalA = app.collectionViews["demo.modal.A"]
        XCTAssertTrue(modalA.waitForExistence(timeout: 2))

        modalA.swipeDown(velocity: .fast)

        XCTAssertTrue(waitForDisappearance(modalA))
        XCTAssertEqual(app.staticTexts["demo.state.modal"].label, "None")
    }

    /// Verifies that selecting Router B survives reselecting the Routers tab.
    func testRouterBSelectionSurvivesRoutersTabReselection() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let routersTab = app.tabBars.buttons["Routers"]
        XCTAssertTrue(routersTab.waitForExistence(timeout: 2))
        routersTab.tap()

        let routerB = app.buttons["demo.multiple.target.routerB"]
        XCTAssertTrue(routerB.waitForExistence(timeout: 2))
        routerB.tap()

        let selectedRouter = app.staticTexts["demo.multiple.state.selected"]
        XCTAssertTrue(selectedRouter.label.contains("Router B"))
        XCTAssertTrue(app.staticTexts["Feed"].exists)

        routersTab.tap()

        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(
            app.otherElements["demo.multiple.root"]
                .waitForExistence(timeout: 2)
        )
        XCTAssertTrue(selectedRouter.label.contains("Router B"))
    }

    /// Launches the app in UI-testing mode and opens the Modals lab.
    private func launchApp() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        app.tabBars.buttons["demo.tab.modals"].tap()
    }

    /// Waits until an element no longer exists.
    ///
    /// - Parameters:
    ///   - element: The element expected to disappear.
    ///   - timeout: The maximum number of seconds to wait.
    /// - Returns: `true` when disappearance completes before the timeout.
    private func waitForDisappearance(
        _ element: XCUIElement,
        timeout: TimeInterval = 2
    ) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
