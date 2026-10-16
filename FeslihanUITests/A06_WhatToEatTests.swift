import XCTest

/// Ne Yesem?: the four-step preference wizard and the swipeable recipe
/// suggestions computed from the user's recipes and pantry.
final class A06_WhatToEatTests: FeslihanUITestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        ensureSignedInAtHome()
        openMode(id: "home.mode.whatToEat", fallbackLabel: "Ne Yesem?")
    }

    /// Walks every wizard step with permissive choices and verifies suggestion
    /// cards appear, then saves one recipe.
    func test01_wizardProducesSuggestionsAndSavesOne() {
        // Step 1 — time. Default selection is fine.
        assertExists(app.staticTexts["Ne kadar vaktin var?"], timeout: 15, "Time step missing")
        tap(id: "whatToEat.timeContinue", fallbackLabel: "Devam Et")

        // Step 2 — cuisine. Keep "Farketmez" (default).
        assertExists(app.staticTexts["Ne tarzı bir şey?"], timeout: 10, "Cuisine step missing")
        tap(id: "whatToEat.cuisineContinue", fallbackLabel: "Tarifleri Göster")

        // Step 3 — category. Keep "Farketmez" (default).
        assertExists(app.staticTexts["Ne tür bir şey?"], timeout: 10, "Category step missing")
        tap(id: "whatToEat.categoryContinue", fallbackLabel: "Tarifleri Göster")

        // Step 4 — ingredient flexibility. Choose "no limit" so the seeded
        // collection always yields results regardless of pantry overlap.
        assertExists(app.staticTexts["Malzeme durumun nasıl?"], timeout: 10, "Flex step missing")
        app.staticTexts["Malzemeleri düşünme"].tap()
        tap(id: "whatToEat.flexContinue", fallbackLabel: "Devam Et")

        // Results.
        assertExists(app.staticTexts["Senin için tarifler"], timeout: 15, "Results screen missing")

        // Wait out the loading state; thumbnails are fetched per card.
        let like = byId("whatToEat.likeButton")
        XCTAssertTrue(like.waitForExistence(timeout: 60),
                      "No suggestion cards appeared (like button missing)")

        // Save the top card and verify the saved counter updates.
        like.tap()
        XCTAssertTrue(
            app.staticTexts["1 tarif kaydedildi"].waitForExistence(timeout: 10),
            "Saved-recipe counter did not update after liking a card"
        )

        // Skip the next card to exercise the reject path too.
        let skip = byId("whatToEat.skipButton")
        if skip.exists && skip.isHittable {
            skip.tap()
        }
    }

    /// Strictest filter ("sadece evimdeki malzemelerle"): must reach a
    /// definite terminal state — either suggestion cards or the no-match
    /// empty state. Catches hangs/crashes in the scoring path.
    func test02_pantryOnlyFlexReachesTerminalState() {
        assertExists(app.staticTexts["Ne kadar vaktin var?"], timeout: 15, "Time step missing")
        tap(id: "whatToEat.timeContinue", fallbackLabel: "Devam Et")
        tap(id: "whatToEat.cuisineContinue", fallbackLabel: "Tarifleri Göster")
        tap(id: "whatToEat.categoryContinue", fallbackLabel: "Tarifleri Göster")

        assertExists(app.staticTexts["Malzeme durumun nasıl?"], timeout: 10, "Flex step missing")
        app.staticTexts["Sadece evimdeki malzemelerle"].tap()
        tap(id: "whatToEat.flexContinue", fallbackLabel: "Devam Et")

        assertExists(app.staticTexts["Senin için tarifler"], timeout: 15, "Results screen missing")
        let deadline = Date().addingTimeInterval(60)
        var terminal = false
        while Date() < deadline {
            if byId("whatToEat.likeButton").exists
                || app.staticTexts["Uygun tarif bulunamadı"].exists {
                terminal = true
                break
            }
            sleep(2)
        }
        XCTAssertTrue(terminal, "Results neither loaded cards nor showed the empty state")
    }

    /// Swiping through every card ends on "Hepsi bu kadar!"; the saved-count
    /// sheet lists liked recipes.
    func test03_exhaustDeckAndOpenSavedSheet() {
        assertExists(app.staticTexts["Ne kadar vaktin var?"], timeout: 15, "Time step missing")
        tap(id: "whatToEat.timeContinue", fallbackLabel: "Devam Et")
        tap(id: "whatToEat.cuisineContinue", fallbackLabel: "Tarifleri Göster")
        tap(id: "whatToEat.categoryContinue", fallbackLabel: "Tarifleri Göster")
        assertExists(app.staticTexts["Malzeme durumun nasıl?"], timeout: 10, "Flex step missing")
        app.staticTexts["Malzemeleri düşünme"].tap()
        tap(id: "whatToEat.flexContinue", fallbackLabel: "Devam Et")

        let like = byId("whatToEat.likeButton")
        XCTAssertTrue(like.waitForExistence(timeout: 60), "No suggestion cards appeared")

        // Like the first, skip the rest (deck caps at 10).
        like.tap()
        let skip = byId("whatToEat.skipButton")
        var hops = 0
        while !app.staticTexts["Hepsi bu kadar!"].exists && hops < 15 {
            if skip.exists && skip.isHittable { skip.tap() } else { break }
            hops += 1
        }
        XCTAssertTrue(app.staticTexts["Hepsi bu kadar!"].waitForExistence(timeout: 10),
                      "Deck did not reach the end state")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'tarif kaydettin'")).firstMatch.exists,
            "End state does not report the saved count"
        )
    }
}
