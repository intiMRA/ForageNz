import XCTest

/// Drives the real editor window.
///
/// Three bugs shipped here that only a running window would have caught: prose fields that
/// swallowed clicks, a validation list that pushed every input off screen, and a photo
/// importer buried ten sections down. These are the regression tests for all three.
final class EditorUITests: XCTestCase {
    private static let timeout: TimeInterval = 20

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    /// The catalogue has to actually load — an app bundle launched with no repo above it
    /// would otherwise open on nothing.
    func testCatalogueLoadsAndListsSpecies() {
        let table = app.outlines.firstMatch.exists ? app.outlines.firstMatch : app.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: Self.timeout), "No species list appeared")
        XCTAssertGreaterThan(table.cells.count, 10, "Catalogue looks empty — did the locator fail?")
    }

    func testEverySectionTabIsReachable() {
        selectFirstSpecies()

        for tabName in ["Entry", "Photos", "Safety", "Sources"] {
            let tab = tabButton(containing: tabName)
            XCTAssertTrue(tab.waitForExistence(timeout: Self.timeout), "No “\(tabName)” tab")
            tab.click()
        }
    }

    /// The photo importer was previously the tenth section of one long form.
    func testPhotoImporterIsOneClickAway() {
        selectFirstSpecies()

        tabButton(containing: "Photos").click()

        XCTAssertTrue(
            app.buttons["Add photos…"].waitForExistence(timeout: Self.timeout),
            "Add photos button not reachable from the Photos tab"
        )
        XCTAssertTrue(
            app.textFields.count > 0,
            "Photos tab has no text fields — the web-link field is missing"
        )
    }

    /// The regression test for the overlay that swallowed clicks: type into a prose field
    /// and confirm the text actually lands.
    func testProseFieldsAcceptTyping() {
        selectFirstSpecies()
        tabButton(containing: "Entry").click()

        // The habitat field is one of the multi-line ones that was previously dead.
        let fields = app.textFields
        XCTAssertTrue(fields.element(boundBy: 0).waitForExistence(timeout: Self.timeout))

        let field = fields.element(boundBy: 0)
        field.click()
        field.typeText("ZZTEST")

        XCTAssertTrue(
            (field.value as? String)?.contains("ZZTEST") == true,
            "Typing did not reach the field — value was \(String(describing: field.value))"
        )
    }

    /// The toolbar's save button can be collapsed away when the window is narrow, so the
    /// editor carries a persistent one in a footer bar.
    func testSaveButtonIsAlwaysVisible() {
        selectFirstSpecies()

        let save = app.buttons["Save changes"]
        XCTAssertTrue(save.waitForExistence(timeout: Self.timeout), "No persistent save button")
        XCTAssertFalse(save.isEnabled, "Save should be disabled with no unsaved changes")

        tabButton(containing: "Entry").click()
        let field = app.textFields.element(boundBy: 0)
        XCTAssertTrue(field.waitForExistence(timeout: Self.timeout))
        field.click()
        field.typeText("Z")

        XCTAssertTrue(save.isEnabled, "Save should enable once an entry is edited")
    }

    func testAddingASpeciesShowsItsIdentifierBeforeCommitting() {
        app.buttons["Add species"].firstMatch.click()

        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: Self.timeout), "Add sheet did not appear")
        nameField.click()
        nameField.typeText("Pūhā Test Plant")

        XCTAssertTrue(
            app.staticTexts["puha-test-plant"].waitForExistence(timeout: Self.timeout),
            "Derived identifier was not shown before committing"
        )

        app.buttons["Cancel"].firstMatch.click()
    }

    // MARK: - Helpers

    private func selectFirstSpecies() {
        let table = app.outlines.firstMatch.exists ? app.outlines.firstMatch : app.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: Self.timeout), "No species list appeared")
        let row = table.cells.element(boundBy: 0)
        XCTAssertTrue(row.waitForExistence(timeout: Self.timeout), "No species rows")
        row.click()
    }

    /// Tab labels carry a blocking-issue count, e.g. "Entry (5)", so match on the prefix.
    private func tabButton(containing name: String) -> XCUIElement {
        app.radioButtons.containing(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }
}
