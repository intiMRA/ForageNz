import XCTest

final class ListsAndFindsUITests: XCTestCase {
    private static let existenceTimeout: TimeInterval = 5

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // In memory, so a run neither reads nor leaves the user's real lists and finds.
        app.launchArguments.append("-UserDataInMemory")
        app.launch()
    }

    func testAddingASpeciesToANewListShowsItInThatList() {
        app.tabBars.buttons["Field guide"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: Self.existenceTimeout), "Field guide has no search field")
        search.tap()
        search.typeText("dandelion")

        let bookmark = app.buttons["addToList.dandelion"]
        XCTAssertTrue(bookmark.waitForExistence(timeout: Self.existenceTimeout), "Dandelion card has no add-to-list button")
        bookmark.tap()
        app.buttons["New list…"].tap()

        let name = app.textFields["listName"]
        XCTAssertTrue(name.waitForExistence(timeout: Self.existenceTimeout), "The new-list editor did not open")
        name.tap()
        name.typeText("Wanted")
        app.buttons["saveList"].tap()

        app.tabBars.buttons["Lists"].tap()
        let list = app.buttons["list.Wanted"]
        XCTAssertTrue(list.waitForExistence(timeout: Self.existenceTimeout), "The new list is not in the Lists tab")
        list.tap()

        XCTAssertTrue(
            app.staticTexts["speciesRow.dandelion"].waitForExistence(timeout: Self.existenceTimeout),
            "Dandelion is not on the list's page"
        )
    }

    func testAListKeepsTheIconPickedForIt() {
        app.tabBars.buttons["Lists"].tap()
        app.buttons["newList"].tap()

        let name = app.textFields["listName"]
        XCTAssertTrue(name.waitForExistence(timeout: Self.existenceTimeout), "The new-list editor did not open")
        name.tap()
        name.typeText("Walks")
        app.buttons["chooseListIcon"].tap()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: Self.existenceTimeout), "The icon picker has no search field")
        search.tap()
        search.typeText("leaf")
        let leaf = app.buttons["listSymbol.leaf"]
        XCTAssertTrue(leaf.waitForExistence(timeout: Self.existenceTimeout), "The leaf icon is not in the picker")
        leaf.tap()
        app.buttons["saveList"].tap()

        let list = app.buttons["list.Walks"]
        XCTAssertTrue(list.waitForExistence(timeout: Self.existenceTimeout), "The new list is not in the Lists tab")
        list.tap()
        app.buttons["editList"].tap()

        XCTAssertTrue(
            app.buttons["removeListIcon"].waitForExistence(timeout: Self.existenceTimeout),
            "The list's icon was not kept"
        )
    }

    func testSavingAFindShowsItsCardWhichOpensTheSpecies() {
        app.tabBars.buttons["Map"].tap()
        app.buttons["addFind"].tap()
        app.buttons["chooseFindSpecies"].tap()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: Self.existenceTimeout), "The species picker has no search field")
        search.tap()
        search.typeText("dandelion")
        let dandelion = app.buttons["pickSpecies.dandelion"]
        XCTAssertTrue(dandelion.waitForExistence(timeout: Self.existenceTimeout), "Dandelion is not in the picker")
        dandelion.tap()

        let card = app.staticTexts["speciesRow.dandelion"]
        XCTAssertTrue(card.waitForExistence(timeout: Self.existenceTimeout), "The saved find has no card")
        card.tap()

        XCTAssertTrue(
            app.staticTexts["speciesDetail.scientificName"].waitForExistence(timeout: Self.existenceTimeout),
            "The find's card did not open the species page"
        )
    }
}
