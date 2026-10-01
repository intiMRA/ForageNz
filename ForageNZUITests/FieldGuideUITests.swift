import XCTest

final class FieldGuideUITests: XCTestCase {
    private static let existenceTimeout: TimeInterval = 5

    /// Swipe ceilings are a backstop against an infinite loop, not a measurement of how far
    /// anything sits down the screen. Both scrolling helpers stop as soon as the view stops
    /// moving, so these only have to be larger than any real screen — a count tuned to the
    /// catalogue's current size is a test that goes red the next time an entry ships.
    private static let maxSwipes = 40

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
        let dandelion = fieldGuideRow("dandelion", searchingFor: "dandelion")
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

        // The list is lazy, so an unrendered row is absent from the hierarchy rather than
        // merely offscreen — `exists` only becomes true once it has been scrolled to. Tutu
        // sorts late among the do-not-eat species and that section sits below the poisoning
        // panel, the location section and seven ground rules, so it takes real scrolling.
        let tutu = app.staticTexts["speciesRow.tutu"]
        XCTAssertTrue(
            scrollDownUntil({ tutu.exists }),
            "Safety screen did not list Tutu among the do-not-eat species"
        )
    }

    /// A lookalike the catalogue has its own page for opens that page — "can be confused with
    /// hemlock" is only useful in the field if you can then look at hemlock.
    func testLookalikeCardOpensItsOwnEntry() {
        let fennel = fieldGuideRow("wild-fennel", searchingFor: "fennel")
        XCTAssertTrue(fennel.waitForExistence(timeout: Self.existenceTimeout), "Wild fennel row not found")
        fennel.tap()

        // Matched by identifier regardless of the element type SwiftUI exposes the link as,
        // then scrolled into view — `exists` is true for anything in the hierarchy, on screen or not.
        let hemlockCard = app.descendants(matching: .any)["lookalike.hemlock"].firstMatch
        XCTAssertTrue(hemlockCard.waitForExistence(timeout: Self.existenceTimeout), "Hemlock lookalike card is not on the wild fennel page")
        XCTAssertTrue(
            scrollDownUntil({ hemlockCard.isHittable }),
            "Could not scroll the hemlock card into view"
        )
        hemlockCard.tap()

        let scientificName = app.staticTexts["speciesDetail.scientificName"]
        XCTAssertTrue(scientificName.waitForExistence(timeout: Self.existenceTimeout))
        XCTAssertEqual(scientificName.label, "Conium maculatum", "Tapping the card did not open hemlock's own page")
    }

    /// Opens the Field guide and searches for a row rather than assuming it is rendered.
    ///
    /// The list is lazy and alphabetical, so whether any given row is on screen at launch is a
    /// function of how many entries sort above it — which changes every time an entry ships.
    /// Searching is the only locator that does not rot as the catalogue grows.
    private func fieldGuideRow(_ speciesID: String, searchingFor term: String) -> XCUIElement {
        app.tabBars.buttons["Field guide"].tap()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: Self.existenceTimeout), "Field guide has no search field")
        search.tap()
        search.typeText(term)

        return app.buttons.containing(.staticText, identifier: "speciesRow.\(speciesID)").firstMatch
    }

    /// Swipes up until `condition` holds or the view stops moving, and reports whether it held.
    ///
    /// The stopping rule is the screen's own end rather than a swipe count, so a caller never
    /// has to know how far down something sits. That matters most on screens whose length
    /// tracks the catalogue: a fixed count is correct only until the next entry ships.
    private func scrollDownUntil(_ condition: () -> Bool) -> Bool {
        var swipes = 0
        while !condition() && swipes < Self.maxSwipes {
            let before = scrollSignature()
            app.swipeUp()
            swipes += 1
            if scrollSignature() == before { break }
        }
        return condition()
    }

    /// Where the visible content currently sits. Compared before and after a swipe to tell
    /// "there is more below" from "this is the bottom". The first and last rendered labels are
    /// enough — both move on any successful scroll — and reading two frames keeps the check
    /// cheap enough to run on every iteration. Static text is used because it is the one
    /// element type both a `List` and a detail `ScrollView` are certain to contain.
    private func scrollSignature() -> [CGRect] {
        let labels = app.staticTexts.allElementsBoundByIndex
        guard let first = labels.first, let last = labels.last else { return [] }
        return [first.frame, last.frame]
    }

    private func selectOrigin(_ name: String) {
        app.tabBars.buttons["Field guide"].tap()
        app.navigationBars.buttons["Filter"].firstMatch.tap()
        app.buttons[name].firstMatch.tap()
    }
}
