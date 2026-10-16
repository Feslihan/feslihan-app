import XCTest

/// Pişirme modu: adım adım ilerleme, geri gitme, tamamlama → yorum sayfası.
final class A10_CookingModeTests: FeslihanUITestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        ensureSignedInAtHome()
        openMode(id: "home.mode.browse", fallbackLabel: "Tariflerim")
        assertExists(app.staticTexts["Tüm Tarifler"], timeout: 20, "Recipe list did not load")

        openRecipeDetail(title: "Mercimek Çorbası")
    }

    /// Walks every step: Önceki disabled on step 1, Sonraki advances, the last
    /// step shows Tamamlandı which opens the review sheet; Atla dismisses.
    func test01_walkAllStepsAndComplete() {
        tap(id: "detail.cookButton", fallbackLabel: "Pişirmeye Başla")

        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'ADIM 1'")).firstMatch
                .waitForExistence(timeout: 10),
            "Cooking mode did not open on step 1"
        )

        let prev = app.buttons["Önceki"]
        XCTAssertFalse(prev.isEnabled, "Önceki should be disabled on the first step")

        // Advance to the end (seeded recipe has a bounded number of steps).
        let next = app.buttons["Sonraki"]
        let done = app.buttons["Tamamlandı"]
        var hops = 0
        while !done.exists && hops < 30 {
            XCTAssertTrue(next.waitForExistence(timeout: 5), "Sonraki missing before the last step")
            next.tap()
            hops += 1
        }
        XCTAssertTrue(done.exists, "Never reached the final step (Tamamlandı)")

        // Going back re-enables forward navigation.
        XCTAssertTrue(prev.isEnabled, "Önceki should be enabled past step 1")
        prev.tap()
        XCTAssertTrue(next.waitForExistence(timeout: 5), "Sonraki missing after stepping back")
        next.tap()

        // Complete → review sheet → skip.
        done.tap()
        assertExists(app.staticTexts["Afiyet olsun!"], timeout: 10, "Review sheet did not open after Tamamlandı")
        app.buttons["Atla"].tap()

        // Dismissing the sheet also closes cooking mode, back to the detail.
        assertExists(app.buttons["Malzemeler"], timeout: 10, "Did not return to recipe detail")
    }

    /// The close button exits cooking mode immediately.
    func test02_closeButtonExits() {
        tap(id: "detail.cookButton", fallbackLabel: "Pişirmeye Başla")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'ADIM'")).firstMatch
                .waitForExistence(timeout: 10),
            "Cooking mode did not open"
        )
        tap(id: "cooking.closeButton")
        assertExists(app.buttons["Malzemeler"], timeout: 10, "Close did not return to recipe detail")
    }
}
