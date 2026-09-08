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

    /// A tab's label and its screen title differ where the longer title reads better,
    /// so they are paired explicitly rather than assumed equal.
    func testEachTabRendersItsScreen() {
        let tabs = [
            (label: "In season", title: "In season"),
            (label: "Field guide", title: "Field guide"),
            (label: "Match", title: "Match a photo"),
            (label: "Safety", title: "Safety")
        ]

        for tab in tabs {
            let button = app.tabBars.buttons[tab.label]
            XCTAssertTrue(button.waitForExistence(timeout: Self.existenceTimeout), "Missing tab: \(tab.label)")
            button.tap()

            XCTAssertTrue(
                app.navigationBars[tab.title].waitForExistence(timeout: Self.existenceTimeout),
                "Tapping \(tab.label) did not show “\(tab.title)”"
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

    func testMatchTabIsReachableAndStatesItIsNotIdentification() {
        app.tabBars.buttons["Match"].tap()

        XCTAssertTrue(
            app.staticTexts["This does not identify anything"].waitForExistence(timeout: Self.existenceTimeout),
            "Match screen must lead with the fact that it is not an identification"
        )
        XCTAssertTrue(
            app.buttons.containing(.staticText, identifier: "Choose a photo").firstMatch
                .waitForExistence(timeout: Self.existenceTimeout),
            "No way to pick a photo on the Match tab"
        )
    }

    /// With almost no catalogue photos, matching is meaningless — the screen has to say so
    /// rather than rank one species against nothing.
    func testMatchTabWarnsWhenThereAreTooFewPhotos() {
        app.tabBars.buttons["Match"].tap()

        XCTAssertTrue(
            app.staticTexts["Not enough photos yet"].waitForExistence(timeout: Self.existenceTimeout),
            "Thin-coverage warning missing — it should appear until enough entries have photos"
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
