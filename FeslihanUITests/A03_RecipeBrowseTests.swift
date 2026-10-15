import XCTest

/// Tariflerim: browsing the recipe collection that the backend mapped to the
/// test user (seeded platform recipes), searching, and the recipe detail view.
final class A03_RecipeBrowseTests: FeslihanUITestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        ensureSignedInAtHome()
        openMode(id: "home.mode.browse", fallbackLabel: "Tariflerim")
    }

    /// The list loads the user's recipes from the backend.
    func test01_recipeListLoadsSeededRecipes() {
        assertExists(app.staticTexts["Tüm Tarifler"], timeout: 20,
                     "Recipe list did not load (Tüm Tarifler section missing)")

        // At least one seeded platform recipe should be visible or reachable.
        let seeded = app.staticTexts["Mercimek Çorbası"]
        if !seeded.exists {
            app.swipeUp()
        }
        XCTAssertTrue(seeded.waitForExistence(timeout: 10),
                      "Seeded recipe 'Mercimek Çorbası' not found in Tariflerim")
    }

    /// Searching narrows the list to matching recipes.
    func test02_searchFiltersRecipes() {
        assertExists(app.staticTexts["Tüm Tarifler"], timeout: 20, "Recipe list did not load")

        let search = app.textFields["Tarif ara..."]
        assertExists(search, "Search field missing")
        search.tap()
        search.typeText("Mercimek")

        XCTAssertTrue(app.staticTexts["Mercimek Çorbası"].waitForExistence(timeout: 10),
                      "Search for 'Mercimek' did not surface Mercimek Çorbası")
    }

    /// Opening a recipe shows the detail view with its three content tabs.
    func test03_recipeDetailShowsTabs() {
        assertExists(app.staticTexts["Tüm Tarifler"], timeout: 20, "Recipe list did not load")

        let cell = app.staticTexts["Mercimek Çorbası"]
        if !cell.exists { app.swipeUp() }
        assertExists(cell, "Seeded recipe cell missing")
        cell.tap()

        assertExists(app.staticTexts["Malzemeler"], timeout: 15, "Malzemeler tab missing in detail")
        assertExists(app.staticTexts["Yapılış"], timeout: 5, "Yapılış tab missing in detail")
        assertExists(app.staticTexts["Besin"], timeout: 5, "Besin tab missing in detail")

        // Ingredients tab content: a known ingredient from the seeded recipe.
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Mercimek'")).count > 0,
            "No ingredient rows visible on the Malzemeler tab"
        )

        // Switch to instructions and verify content is rendered.
        app.staticTexts["Yapılış"].tap()
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'tencere' OR label CONTAINS 'pişirin' OR label CONTAINS 'ekleyin'"))
                .firstMatch.waitForExistence(timeout: 10),
            "Instructions text not visible on the Yapılış tab"
        )
    }
}
