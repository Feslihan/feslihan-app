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

    /// Searching for a nonsense term leaves the pill cloud empty.
    func test04_searchWithNoResults() {
        let search = app.textFields["pantry.searchField"]
        assertExists(search, timeout: 15, "Pantry search field missing")
        search.tap()
        search.typeText("zzzzxxx")
        // A known seeded pill must disappear from the filtered cloud.
        XCTAssertFalse(app.staticTexts["Patates"].waitForExistence(timeout: 3),
                       "No-result search still shows pills")
    }

    /// "Alışveriş Listesine Taşı": a pantry item moves to the shopping list
    /// (added there, removed here). Uses a test-added item, then cleans up.
    func test05_moveItemToShoppingList() {
        // Add a fresh item via the list picker so we never move seeded data.
        tap(id: "pantry.addMenu", fallbackLabel: "Ekle", timeout: 15)
        app.buttons["Listeden Seç"].tap()
        assertExists(app.staticTexts["Malzeme Seç"], timeout: 15, "Picker did not open")
        let rows = app.scrollViews.descendants(matching: .button)
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 15), "No picker rows")
        let name = rows.firstMatch.label.trimmingCharacters(in: .whitespacesAndNewlines)
        rows.firstMatch.tap()
        app.buttons["ingredientPicker.saveButton"].tap()

        let pill = app.staticTexts[name]
        XCTAssertTrue(pill.waitForExistence(timeout: 15), "Added item '\(name)' missing")

        // Move to shopping list via context menu.
        pill.press(forDuration: 1.2)
        let move = app.buttons["Alışveriş Listesine Taşı"]
        assertExists(move, timeout: 5, "'Alışveriş Listesine Taşı' menu item missing")
        move.tap()
        waitForDisappearance(of: pill, timeout: 15)

        // Verify it landed in the shopping list, then clean it up.
        goBackHome()
        openMode(id: "home.mode.shoppingList", fallbackLabel: "Alışveriş")
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 15),
                      "Moved item '\(name)' missing from shopping list")
        tap(id: "shopping.delete.\(name)", timeout: 10)
        waitForDisappearance(of: app.staticTexts[name], timeout: 15)
    }

    /// The bubble-game sheet opens from the add menu and can be dismissed.
    /// (Popping moving bubbles is intentionally not automated — the targets
    /// animate continuously; the list picker covers deterministic adding.)
    func test06_bubbleSheetOpensAndCloses() {
        tap(id: "pantry.addMenu", fallbackLabel: "Ekle", timeout: 15)
        let bubbleOption = app.buttons["Baloncuklardan Seç"]
        assertExists(bubbleOption, timeout: 5, "'Baloncuklardan Seç' menu item missing")
        bubbleOption.tap()

        assertExists(app.staticTexts["Evinde ne var?"], timeout: 15, "Bubble sheet did not open")
        // Devam Et disabled with nothing selected.
        let cont = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Devam Et'")).firstMatch
        if cont.waitForExistence(timeout: 5) {
            XCTAssertFalse(cont.isEnabled, "Devam Et should be disabled with no selection")
        }
        // Close via the xmark overlay button.
        let close = app.buttons.matching(NSPredicate(format: "label == 'xmark' OR label == 'Close'")).firstMatch
        if close.exists && close.isHittable { close.tap() } else { app.swipeDown(velocity: .fast) }
        assertExists(app.staticTexts["Kilerim"], timeout: 10, "Did not return to pantry")
    }
}
