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

    /// Collection chips navigate into Denediklerim/Beğendiklerim and back.
    func test03_collectionChipsNavigate() {
        assertExists(app.staticTexts["Tüm Tarifler"], timeout: 20, "Recipe list did not load")

        // Entering a collection replaces the default view (Tüm Tarifler gone,
        // "N sonuç" results header shown).
        app.staticTexts["Denediklerim"].tap()
        waitForDisappearance(of: app.staticTexts["Tüm Tarifler"], timeout: 10)
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label ENDSWITH 'sonuç'")).firstMatch
                .waitForExistence(timeout: 10),
            "Denediklerim results view did not open"
        )
        app.buttons["backButton"].tap()
        assertExists(app.staticTexts["Tüm Tarifler"], timeout: 10, "Did not return from Denediklerim")

        app.staticTexts["Beğendiklerim"].tap()
        waitForDisappearance(of: app.staticTexts["Tüm Tarifler"], timeout: 10)
        app.buttons["backButton"].tap()
        assertExists(app.staticTexts["Tüm Tarifler"], timeout: 10, "Did not return to the main list")
    }

    /// The filter sheet opens with its own title.
    func test04_filterSheetOpens() {
        assertExists(app.staticTexts["Tüm Tarifler"], timeout: 20, "Recipe list did not load")
        tap(id: "recipes.filterButton")
        assertExists(app.staticTexts["Filtrele"], timeout: 10, "Filter sheet did not open")
        app.swipeDown(velocity: .fast)
    }

    /// Opening a recipe shows the detail view with its three content tabs.
    func test05_recipeDetailShowsTabs() {
        assertExists(app.staticTexts["Tüm Tarifler"], timeout: 20, "Recipe list did not load")

        openRecipeDetail(title: "Mercimek Çorbası")

        // Detail tabs surface as buttons (the Button swallows its inner text).
        assertExists(app.buttons["Malzemeler"], timeout: 15, "Malzemeler tab missing in detail")
        assertExists(app.buttons["Yapılış"], timeout: 5, "Yapılış tab missing in detail")
        assertExists(app.buttons["Besin"], timeout: 5, "Besin tab missing in detail")

        // Ingredients tab content: a known ingredient from the seeded recipe.
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Mercimek'")).count > 0,
            "No ingredient rows visible on the Malzemeler tab"
        )

        // Switch to instructions and verify content is rendered.
        app.buttons["Yapılış"].tap()
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'tencere' OR label CONTAINS 'pişirin' OR label CONTAINS 'ekleyin'"))
                .firstMatch.waitForExistence(timeout: 10),
            "Instructions text not visible on the Yapılış tab"
        )
    }
}
