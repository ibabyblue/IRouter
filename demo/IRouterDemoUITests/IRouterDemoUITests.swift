import XCTest

final class IRouterDemoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        app.tabBars.buttons["demo.tab.modals"].tap()
    }

    func testChildRouterDismissesOwningSheet() {
        app.buttons["demo.modals.openSheetA"].tap()
        let modalA = app.otherElements["demo.modal.A"]
        XCTAssertTrue(modalA.waitForExistence(timeout: 2))

        app.buttons["demo.modal.dismissCurrent"].tap()

        XCTAssertTrue(waitForDisappearance(modalA))
        XCTAssertEqual(app.staticTexts["demo.state.modal"].label, "None")
    }

    func testSheetToCoverReplacementIsSerialized() {
        app.buttons["demo.modals.openSheetA"].tap()
        let modalA = app.otherElements["demo.modal.A"]
        XCTAssertTrue(modalA.waitForExistence(timeout: 2))

        app.buttons["demo.modals.replaceWithCoverB"].tap()

        XCTAssertTrue(waitForDisappearance(modalA))
        XCTAssertTrue(app.otherElements["demo.modal.B"].waitForExistence(timeout: 2))
    }

    func testRapidReplacementPresentsOnlyLatestContext() {
        app.buttons["demo.modals.openSheetA"].tap()
        XCTAssertTrue(app.otherElements["demo.modal.A"].waitForExistence(timeout: 2))

        app.buttons["demo.modals.rapidReplaceABC"].tap()

        XCTAssertFalse(app.otherElements["demo.modal.B"].waitForExistence(timeout: 0.5))
        XCTAssertTrue(app.otherElements["demo.modal.C"].waitForExistence(timeout: 2))
    }

    func testInteractiveDismissalClearsRouterInspector() {
        app.buttons["demo.modals.openSheetA"].tap()
        let modalA = app.otherElements["demo.modal.A"]
        XCTAssertTrue(modalA.waitForExistence(timeout: 2))

        modalA.swipeDown(velocity: .fast)

        XCTAssertTrue(waitForDisappearance(modalA))
        XCTAssertEqual(app.staticTexts["demo.state.modal"].label, "None")
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
