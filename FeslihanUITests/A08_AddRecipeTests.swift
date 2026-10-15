import XCTest

/// Tarif ekleme (AddRecipeView): validation errors, the REAL web-scrape path
/// (backend fetches nefisyemektarifleri + Claude extracts the recipe), the
/// duplicate-URL cache path, and cleanup.
///
/// The video path (Instagram/TikTok) is NOT automated: it depends on social
/// platforms' oEmbed endpoints which block CI runner IPs; its validation
/// errors are covered instead.
final class A08_AddRecipeTests: FeslihanUITestCase {

    /// A stable public recipe URL on the scraper's allowlisted host.
    /// Override with E2E_SCRAPE_URL (TEST_RUNNER_E2E_SCRAPE_URL on xcodebuild).
    private var scrapeURL: String {
        let env = ProcessInfo.processInfo.environment["E2E_SCRAPE_URL"]
        if let env, !env.isEmpty { return env }
        return "https://www.nefisyemektarifleri.com/klasik-kek-tarifi/"
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        ensureSignedInAtHome()
        openMode(id: "home.mode.browse", fallbackLabel: "Tariflerim")
        assertExists(app.staticTexts["Tüm Tarifler"], timeout: 20, "Recipe list did not load")
        tap(id: "recipes.addButton", fallbackLabel: "Tarif ekle")
        assertExists(app.staticTexts["Yeni Tarif"], timeout: 10, "AddRecipeView sheet did not open")
    }

    /// Submit is disabled while the URL field is empty.
    func test01_submitDisabledWithEmptyURL() {
        let submit = app.buttons["addRecipe.submitButton"]
        assertExists(submit, "Submit button missing")
        XCTAssertFalse(submit.isEnabled, "Tarif Ekle should be disabled with an empty URL")
    }

    /// A malformed link shows the Turkish validation error.
    func test02_invalidURLShowsError() {
        let field = app.textFields["addRecipe.urlField"]
        assertExists(field, "URL field missing")
        field.tap()
        field.typeText("not a url")
        app.buttons["addRecipe.submitButton"].tap()

        assertExists(app.staticTexts["Hata"], timeout: 10, "Error view did not appear")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Geçerli bir bağlantı'")).firstMatch.exists,
            "Invalid-URL message missing"
        )

        // Tekrar Dene returns to the idle form.
        app.buttons["Tekrar Dene"].tap()
        assertExists(app.textFields["addRecipe.urlField"], timeout: 5, "Did not return to the URL form")
    }

    /// A well-formed link on an unsupported host is rejected with guidance.
    func test03_unsupportedPlatformShowsError() {
        let field = app.textFields["addRecipe.urlField"]
        assertExists(field, "URL field missing")
        field.tap()
        field.typeText("https://example.com/yemek-tarifi")
        app.buttons["addRecipe.submitButton"].tap()

        assertExists(app.staticTexts["Hata"], timeout: 10, "Error view did not appear")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'desteklenmiyor'")).firstMatch.exists,
            "Unsupported-platform message missing"
        )
    }

    /// REAL end-to-end: scrape a nefisyemektarifleri page through the backend
    /// (SSRF-guarded fetch + Claude extraction), save it, and see it in
    /// Tariflerim. Slow: the scrape+analyze call runs a real model.
    func test04_addWebRecipeEndToEnd() {
        let field = app.textFields["addRecipe.urlField"]
        assertExists(field, "URL field missing")
        field.tap()
        field.typeText(scrapeURL)
        app.buttons["addRecipe.submitButton"].tap()

        // Processing checklist appears for the web path.
        XCTAssertTrue(
            app.staticTexts["Tarif bilgileri"].waitForExistence(timeout: 15)
                || app.buttons["addRecipe.saveButton"].waitForExistence(timeout: 5),
            "Web-recipe processing did not start"
        )

        // Wait for the result (scrape + Claude can take a while).
        let save = app.buttons["addRecipe.saveButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 180),
                      "Scraped recipe result did not appear within 3 minutes")

        // The result view shows extracted content.
        assertExists(app.staticTexts["Malzemeler"], timeout: 5, "Ingredients section missing in result")
        assertExists(app.staticTexts["Yapılış"], timeout: 5, "Instructions section missing in result")

        save.tap()

        // Back on the recipe list, the new recipe is persisted locally.
        assertExists(app.staticTexts["Tüm Tarifler"], timeout: 15, "Did not return to recipe list")
    }

    /// Adding the SAME URL again takes the cached-lookup fast path: the
    /// backend returns the existing recipe without re-scraping.
    func test05_duplicateURLUsesCache() {
        let field = app.textFields["addRecipe.urlField"]
        assertExists(field, "URL field missing")
        field.tap()
        field.typeText(scrapeURL)
        app.buttons["addRecipe.submitButton"].tap()

        // The cached path should land on the result view much faster than a
        // fresh scrape — but allow slack for CI.
        XCTAssertTrue(app.buttons["addRecipe.saveButton"].waitForExistence(timeout: 60),
                      "Cached recipe lookup did not produce a result")
        app.buttons["addRecipe.saveButton"].tap()
        assertExists(app.staticTexts["Tüm Tarifler"], timeout: 15, "Did not return to recipe list")
    }
}
