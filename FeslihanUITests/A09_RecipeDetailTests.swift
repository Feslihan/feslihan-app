import XCTest

/// Tarif detayı: favorilere ekleme/çıkarma, porsiyon çarpanı, besin sekmesi,
/// "pişirdim" yorumu (ekle + sil) ve Plana Ekle sayfası.
final class A09_RecipeDetailTests: FeslihanUITestCase {

    private let recipeTitle = "Mercimek Çorbası"

    override func setUpWithError() throws {
        try super.setUpWithError()
        ensureSignedInAtHome()
        openMode(id: "home.mode.browse", fallbackLabel: "Tariflerim")
        assertExists(app.staticTexts["Tüm Tarifler"], timeout: 20, "Recipe list did not load")
    }

    private func openDetail() {
        openRecipeDetail(title: recipeTitle)
    }

    /// Favorite round-trip: heart on → Beğendiklerim lists it → unfavorite
    /// from the list → empty again. Exercises PUT …/favorite both ways.
    func test01_favoriteAndUnfavorite() {
        openDetail()

        let heart = byId("detail.favoriteButton")
        assertExists(heart, "Favorite button missing")
        heart.tap()

        // Back to the list, open Beğendiklerim.
        tapBack()
        assertExists(app.staticTexts["Tüm Tarifler"], timeout: 10, "Did not return to list")
        app.swipeDown()
        app.staticTexts["Beğendiklerim"].tap()

        let favorited = app.staticTexts[recipeTitle]
        XCTAssertTrue(favorited.waitForExistence(timeout: 15),
                      "Favorited recipe missing from Beğendiklerim")

        // Unfavorite via the context menu.
        favorited.press(forDuration: 1.2)
        let unfav = app.buttons["Beğenmekten Vazgeç"]
        assertExists(unfav, timeout: 5, "'Beğenmekten Vazgeç' menu item missing")
        unfav.tap()
        waitForDisappearance(of: app.staticTexts[recipeTitle], timeout: 15)
    }

    /// Porsiyon multiplier scales the servings indicator (6 kişilik seed
    /// recipe → 12 at 2x).
    func test02_servingMultiplierScales() {
        openDetail()

        assertExists(app.staticTexts["Porsiyon"], timeout: 10, "Multiplier row missing")
        app.buttons["2x"].tap()
        XCTAssertTrue(app.staticTexts["12"].waitForExistence(timeout: 5),
                      "Servings did not scale to 12 at 2x")
        app.buttons["1x"].tap()
    }

    /// Besin tab renders calories and macro bars from seeded nutrition data.
    func test03_nutritionTabShowsMacros() {
        openDetail()

        app.buttons["Besin"].tap()
        assertExists(app.staticTexts["toplam kcal"], timeout: 10, "Calories header missing on Besin tab")
        assertExists(app.staticTexts["Protein"], timeout: 5, "Protein bar missing")
        assertExists(app.staticTexts["Karbonhidrat"], timeout: 5, "Carbs bar missing")
    }

    /// Review lifecycle: "Bu tarifi pişirdim" → 5 stars + comment → Gönder →
    /// inline review shown → Düzenle → "Denediklerimden Kaldır". Exercises
    /// POST and DELETE on reviews.
    func test04_submitAndDeleteReview() {
        openDetail()

        tap(id: "detail.reviewButton", fallbackLabel: "Bu tarifi pişirdim")
        assertExists(app.staticTexts["Afiyet olsun!"], timeout: 10, "Review sheet did not open")

        byId("review.star.5").tap()
        let submit = byId("review.submitButton")
        XCTAssertTrue(submit.isEnabled, "Gönder should enable after rating")
        submit.tap()

        // Inline review replaces the button in the bottom bar.
        assertExists(app.buttons["Düzenle"], timeout: 15, "Inline review did not appear after submit")

        // Delete it again.
        app.buttons["Düzenle"].tap()
        assertExists(app.staticTexts["Afiyet olsun!"], timeout: 10, "Review sheet did not reopen")
        let delete = app.buttons["Denediklerimden Kaldır"]
        assertExists(delete, timeout: 5, "Delete-review button missing")
        delete.tap()
        XCTAssertTrue(byId("detail.reviewButton").waitForExistence(timeout: 15),
                      "Review was not removed (pişirdim button missing)")
    }

    /// Plana Ekle sheet opens from the toolbar and lists saved plans (or the
    /// no-plans empty state).
    func test05_addToPlanSheetOpens() {
        openDetail()

        let sheetTitle = app.descendants(matching: .any)["Plana Ekle"].firstMatch
        let button = byId("detail.addToPlanButton")
        assertExists(button, "AddToPlan toolbar button missing")
        button.tap()
        if !sheetTitle.waitForExistence(timeout: 6) {
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 10), "AddToPlan sheet did not open")
        XCTAssertTrue(
            app.staticTexts["Plan Seç"].waitForExistence(timeout: 10)
                || app.staticTexts["Henüz kayıtlı plan yok"].waitForExistence(timeout: 5),
            "AddToPlan sheet shows neither plan list nor empty state"
        )
        app.buttons["Kapat"].tap()
    }
}
