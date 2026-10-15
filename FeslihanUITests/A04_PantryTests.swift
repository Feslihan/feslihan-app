import XCTest

/// Kilerim: viewing seeded pantry items, searching, adding through the
/// ingredient list picker, and removing via the context menu — each step a
/// real round-trip to the test backend.
final class A04_PantryTests: FeslihanUITestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        ensureSignedInAtHome()
        openMode(id: "home.mode.pantry", fallbackLabel: "Kilerim")
        assertExists(app.staticTexts["Kilerim"], timeout: 15, "Pantry screen did not open")
    }

    /// The seeded pantry loads with its item-count badge and ingredient pills.
    func test01_pantryShowsSeededItems() {
        // Count badge: "<n> malzeme"
        let badge = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH 'malzeme'")).firstMatch
        assertExists(badge, timeout: 20, "Pantry item-count badge missing (pantry may be empty)")
        let count = firstInt(in: badge.label) ?? 0
        XCTAssertGreaterThanOrEqual(count, 30, "Expected >= 30 seeded pantry items, badge says '\(badge.label)'")

        // A known seeded ingredient pill is visible.
        XCTAssertTrue(app.staticTexts["Patates"].waitForExistence(timeout: 10)
                        || app.staticTexts["Un"].exists,
                      "No known seeded ingredient pill (Patates/Un) visible in pantry")
    }

    /// Searching filters the pill cloud down to matches.
    func test02_searchFiltersPantry() {
        let search = app.textFields["pantry.searchField"]
        assertExists(search, timeout: 15, "Pantry search field missing")
        search.tap()
        search.typeText("Patates")

        XCTAssertTrue(app.staticTexts["Patates"].waitForExistence(timeout: 10),
                      "Searching 'Patates' did not show the Patates pill")
        XCTAssertFalse(app.staticTexts["Un"].exists,
                       "Search filter did not hide non-matching pills")
    }

    /// Add an ingredient through the list picker, then remove it again via the
    /// pill's context menu. Exercises POST and DELETE /users/:id/pantry.
    func test03_addAndRemovePantryItem() {
        // Open the add menu and choose the list picker.
        tap(id: "pantry.addMenu", fallbackLabel: "Ekle", timeout: 15)
        let listOption = app.buttons["Listeden Seç"]
        assertExists(listOption, timeout: 5, "'Listeden Seç' menu item missing")
        listOption.tap()

        assertExists(app.staticTexts["Malzeme Seç"], timeout: 15, "Ingredient picker did not open")

        // Pick the first available ingredient (picker already excludes items
        // that are in the pantry) and remember its name.
        let firstRow = app.buttons.matching(
            NSPredicate(format: "label != 'İptal' AND label != 'Ekle (0)'")
        ).firstMatch
        let rows = app.scrollViews.descendants(matching: .button)
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 15) || firstRow.exists,
                      "No ingredient rows in picker")
        let row = rows.firstMatch.exists ? rows.firstMatch : firstRow
        let pickedName = row.label.trimmingCharacters(in: .whitespacesAndNewlines)
        row.tap()

        let save = app.buttons["ingredientPicker.saveButton"]
        assertExists(save, "Picker save button missing")
        save.tap()

        // The new pill appears after the backend round-trip.
        let newPill = app.staticTexts[pickedName]
        XCTAssertTrue(newPill.waitForExistence(timeout: 15),
                      "Added ingredient '\(pickedName)' did not appear in the pantry")

        // Remove it again via long-press context menu.
        newPill.press(forDuration: 1.2)
        let delete = app.buttons["Sil"]
        assertExists(delete, timeout: 5, "Context menu 'Sil' action missing")
        delete.tap()
        waitForDisappearance(of: newPill, timeout: 15)
    }
}
