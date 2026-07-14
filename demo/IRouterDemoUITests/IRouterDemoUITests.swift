import XCTest

@MainActor
final class IRouterDemoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testChildRouterDismissesOwningSheet() {
        launchApp()

        app.buttons["demo.modals.openSheetA"].tap()
        let modalA = app.collectionViews["demo.modal.A"]
        XCTAssertTrue(modalA.waitForExistence(timeout: 2))

        app.buttons["demo.modal.dismissCurrent"].tap()

        XCTAssertTrue(waitForDisappearance(modalA))
        XCTAssertEqual(app.staticTexts["demo.state.modal"].label, "None")
    }

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

    func testInteractiveDismissalClearsRouterInspector() {
        launchApp()

        app.buttons["demo.modals.openSheetA"].tap()
        let modalA = app.collectionViews["demo.modal.A"]
        XCTAssertTrue(modalA.waitForExistence(timeout: 2))

        modalA.swipeDown(velocity: .fast)

        XCTAssertTrue(waitForDisappearance(modalA))
        XCTAssertEqual(app.staticTexts["demo.state.modal"].label, "None")
    }

    private func launchApp() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        app.tabBars.buttons["demo.tab.modals"].tap()
    }

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
