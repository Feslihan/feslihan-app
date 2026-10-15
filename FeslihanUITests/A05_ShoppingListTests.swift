import XCTest

/// Alışveriş Listesi: adding items, checking them off, moving checked items to
/// the pantry, and deleting — the full shopping-list lifecycle against the
/// test backend.
final class A05_ShoppingListTests: FeslihanUITestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        ensureSignedInAtHome()
        openMode(id: "home.mode.shoppingList", fallbackLabel: "Alışveriş")
        assertExists(app.staticTexts["Alışveriş Listesi"], timeout: 15,
                     "Shopping list screen did not open")
    }

    /// Adds two ingredients via the list picker, checks one off, saves checked
    /// items to the pantry, and deletes the other. Exercises POST, PUT …/check,
    /// DELETE on /users/:id/shopping-list plus POST /users/:id/pantry.
    func test01_fullShoppingListLifecycle() {
        // ── Add two items via the list picker ──
        tap(id: "shopping.addMenu", timeout: 15)
        let listOption = app.buttons["Listeden Seç"]
        assertExists(listOption, timeout: 5, "'Listeden Seç' menu item missing")
        listOption.tap()

        assertExists(app.staticTexts["Malzeme Seç"], timeout: 15, "Ingredient picker did not open")

        let rows = app.scrollViews.descendants(matching: .button)
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 15), "No ingredient rows in picker")

        let first = rows.element(boundBy: 0)
        let second = rows.element(boundBy: 1)
        let name1 = first.label.trimmingCharacters(in: .whitespacesAndNewlines)
        first.tap()
        var name2: String?
        if second.exists {
            name2 = second.label.trimmingCharacters(in: .whitespacesAndNewlines)
            second.tap()
        }

        app.buttons["ingredientPicker.saveButton"].tap()

        // Items land in the "Alınacaklar" (to buy) section.
        assertExists(app.staticTexts["Alınacaklar"], timeout: 15, "Unchecked section missing after add")
        assertExists(app.staticTexts[name1], timeout: 10, "Added item '\(name1)' missing from list")

        // ── Check the first item off ──
        tap(id: "shopping.check.\(name1)", timeout: 10)
        assertExists(app.staticTexts["Alınanlar"], timeout: 15,
                     "Checked section did not appear after checking '\(name1)'")

        // ── Move checked items to the pantry ──
        let toPantry = app.buttons["Kilere Ekle"]
        assertExists(toPantry, timeout: 5, "'Kilere Ekle' button missing")
        toPantry.tap()
        waitForDisappearance(of: app.staticTexts["Alınanlar"], timeout: 20)

        // ── Delete the second item ──
        if let name2 {
            tap(id: "shopping.delete.\(name2)", timeout: 10)
            waitForDisappearance(of: app.staticTexts[name2], timeout: 15)
        }

        // ── Clean up: remove name1 from the pantry so reruns stay stable ──
        goBackHome()
        openMode(id: "home.mode.pantry", fallbackLabel: "Kilerim")
        let pill = app.staticTexts[name1]
        if pill.waitForExistence(timeout: 15) {
            pill.press(forDuration: 1.2)
            let delete = app.buttons["Sil"]
            if delete.waitForExistence(timeout: 5) {
                delete.tap()
            }
        }
    }

    /// Checking and UNchecking: an item moves to Alınanlar and back.
    func test02_toggleCheckAndUncheck() {
        // Add one item.
        tap(id: "shopping.addMenu", timeout: 15)
        app.buttons["Listeden Seç"].tap()
        assertExists(app.staticTexts["Malzeme Seç"], timeout: 15, "Picker did not open")
        let rows = app.scrollViews.descendants(matching: .button)
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 15), "No picker rows")
        let name = rows.firstMatch.label.trimmingCharacters(in: .whitespacesAndNewlines)
        rows.firstMatch.tap()
        app.buttons["ingredientPicker.saveButton"].tap()
        assertExists(app.staticTexts[name], timeout: 15, "Added item missing")

        // Check → Alınanlar section appears.
        tap(id: "shopping.check.\(name)", timeout: 10)
        assertExists(app.staticTexts["Alınanlar"], timeout: 15, "Checked section missing")

        // Uncheck → back to Alınacaklar, Alınanlar disappears.
        tap(id: "shopping.check.\(name)", timeout: 10)
        waitForDisappearance(of: app.staticTexts["Alınanlar"], timeout: 15)
        assertExists(app.staticTexts["Alınacaklar"], timeout: 5, "Unchecked section missing after uncheck")

        // Cleanup.
        tap(id: "shopping.delete.\(name)", timeout: 10)
        waitForDisappearance(of: app.staticTexts[name], timeout: 15)
    }

    /// The bubble-game add sheet opens from the plus menu and closes cleanly.
    func test03_bubbleSheetOpensAndCloses() {
        tap(id: "shopping.addMenu", timeout: 15)
        let bubbleOption = app.buttons["Baloncuklardan Seç"]
        assertExists(bubbleOption, timeout: 5, "'Baloncuklardan Seç' menu item missing")
        bubbleOption.tap()

        assertExists(app.staticTexts["Evinde ne var?"], timeout: 15, "Bubble sheet did not open")
        let close = app.buttons.matching(NSPredicate(format: "label == 'xmark' OR label == 'Close'")).firstMatch
        if close.exists && close.isHittable { close.tap() } else { app.swipeDown(velocity: .fast) }
        assertExists(app.staticTexts["Alışveriş Listesi"], timeout: 10, "Did not return to shopping list")
    }
}
