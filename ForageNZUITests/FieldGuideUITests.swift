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

        let dandelion = app.buttons.containing(.staticText, identifier: "speciesRow.dandelion").firstMatch
        XCTAssertTrue(
            dandelion.waitForExistence(timeout: Self.existenceTimeout),
            "Dandelion row not found in the field guide"
        )
        dandelion.tap()

        let scientificName = app.staticTexts["speciesDetail.scientificName"]
        XCTAssertTrue(
            scientificName.waitForExistence(timeout: Self.existenceTimeout),
            "Species detail did not show the scientific name"
        )
        XCTAssertEqual(scientificName.label, "Taraxacum officinale")
    }

    func testSafetyTabListsSpeciesThatMustNotBeEaten() {
        app.tabBars.buttons["Safety"].tap()

        XCTAssertTrue(
            app.staticTexts["safety.poisoningHeader"].waitForExistence(timeout: Self.existenceTimeout),
            "Safety screen did not load"
        )

        let tutu = app.staticTexts["speciesRow.tutu"]
        var swipes = 0
        while !tutu.exists && swipes < Self.maxSwipesToReachDoNotEatList {
            app.swipeUp()
            swipes += 1
        }

        XCTAssertTrue(tutu.exists, "Safety screen did not list Tutu among the do-not-eat species")
    }

    /// A lookalike the catalogue has its own page for opens that page — "can be confused with
    /// hemlock" is only useful in the field if you can then look at hemlock.
    func testLookalikeCardOpensItsOwnEntry() {
        app.tabBars.buttons["Field guide"].tap()

        // The list is lazy and alphabetical; wild fennel sits well below the fold, so search
        // for it rather than assume it is rendered.
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: Self.existenceTimeout), "Field guide has no search field")
        search.tap()
        search.typeText("fennel")

        let fennel = app.buttons.containing(.staticText, identifier: "speciesRow.wild-fennel").firstMatch
        XCTAssertTrue(fennel.waitForExistence(timeout: Self.existenceTimeout), "Wild fennel row not found")
        fennel.tap()

        // Matched by identifier regardless of the element type SwiftUI exposes the link as,
        // then scrolled into view — `exists` is true for anything in the hierarchy, on screen or not.
        let hemlockCard = app.descendants(matching: .any)["lookalike.hemlock"].firstMatch
        XCTAssertTrue(hemlockCard.waitForExistence(timeout: Self.existenceTimeout), "Hemlock lookalike card is not on the wild fennel page")
        var swipes = 0
        while !hemlockCard.isHittable && swipes < Self.maxSwipesToReachDoNotEatList {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(hemlockCard.isHittable, "Could not scroll the hemlock card into view")
        hemlockCard.tap()

        let scientificName = app.staticTexts["speciesDetail.scientificName"]
        XCTAssertTrue(scientificName.waitForExistence(timeout: Self.existenceTimeout))
        XCTAssertEqual(scientificName.label, "Conium maculatum", "Tapping the card did not open hemlock's own page")
    }

    private func selectOrigin(_ name: String) {
        app.tabBars.buttons["Field guide"].tap()
        app.navigationBars.buttons["Filter"].firstMatch.tap()
        app.buttons[name].firstMatch.tap()
    }
}
