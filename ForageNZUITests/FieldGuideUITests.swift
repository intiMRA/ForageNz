import XCTest

final class FieldGuideUITests: XCTestCase {
    private static let existenceTimeout: TimeInterval = 5
    private static let maxSwipesToReachDoNotEatList = 6

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testEachTabRendersItsScreen() {
        for tab in ["In season", "Field guide", "Safety"] {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: Self.existenceTimeout), "Missing tab: \(tab)")
            button.tap()

            XCTAssertTrue(
                app.navigationBars[tab].waitForExistence(timeout: Self.existenceTimeout),
                "Tapping \(tab) did not show its screen"
            )
        }
    }

    func testFilteringByNativeOriginShowsItsHarvestGuidance() {
        selectOrigin("Native")

        let guidance = app.staticTexts["originHarvestGuidance"]
        XCTAssertTrue(
            guidance.waitForExistence(timeout: Self.existenceTimeout),
            "Origin filter did not surface harvest guidance"
        )
        XCTAssertTrue(
            guidance.label.contains("sparingly"),
            "Expected native guidance to advise sparing harvest, got: \(guidance.label)"
        )
    }

    func testFilteringByWeedShowsDifferentGuidance() {
        selectOrigin("Weed / pest")

        let guidance = app.staticTexts["originHarvestGuidance"]
        XCTAssertTrue(
            guidance.waitForExistence(timeout: Self.existenceTimeout),
            "Origin filter did not surface harvest guidance"
        )
        XCTAssertTrue(
            guidance.label.contains("as much as you like"),
            "Expected pest guidance to encourage harvesting, got: \(guidance.label)"
        )
    }

    func testOpeningASpeciesShowsItsDetail() {
        app.tabBars.buttons["Field guide"].tap()

        let dandelion = app.buttons.containing(.staticText, identifier: "Dandelion").firstMatch
        XCTAssertTrue(
            dandelion.waitForExistence(timeout: Self.existenceTimeout),
            "Dandelion row not found in the field guide"
        )
        dandelion.tap()

        XCTAssertTrue(
            app.staticTexts["Taraxacum officinale"].waitForExistence(timeout: Self.existenceTimeout),
            "Species detail did not show the scientific name"
        )
    }

    func testSafetyTabListsSpeciesThatMustNotBeEaten() {
        app.tabBars.buttons["Safety"].tap()

        XCTAssertTrue(
            app.staticTexts["If you suspect poisoning"].waitForExistence(timeout: Self.existenceTimeout),
            "Safety screen did not load"
        )

        let tutu = app.staticTexts["Tutu"]
        var swipes = 0
        while !tutu.exists && swipes < Self.maxSwipesToReachDoNotEatList {
            app.swipeUp()
            swipes += 1
        }

        XCTAssertTrue(tutu.exists, "Safety screen did not list Tutu among the do-not-eat species")
    }

    private func selectOrigin(_ name: String) {
        app.tabBars.buttons["Field guide"].tap()
        app.navigationBars.buttons["Filter"].firstMatch.tap()
        app.buttons[name].firstMatch.tap()
    }
}
