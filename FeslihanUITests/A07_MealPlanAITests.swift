import XCTest

/// Haftalık Plan: the full premium flow — wizard, REAL Claude meal-plan
/// generation on the backend (POST /ai/meal-plan), saving the plan, and seeing
/// it in the saved-plans list. This is the slowest test in the suite; the
/// generation step waits up to 4 minutes.
final class A07_MealPlanAITests: FeslihanUITestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        ensureSignedInAtHome()
    }

    /// Opens the saved-plans screen from the hub, retrying the hero-card tap:
    /// right after returning from the wizard the hub re-renders (animations +
    /// async refreshes), which can swallow a single synthesized tap.
    private func openSavedPlans() {
        let hero = byId("home.mode.mealPrep")
        for _ in 0..<2 {
            dismissPantryGateIfPresent()
            _ = hero.waitForExistence(timeout: 15)
            if hero.exists { hero.tap() }
            if app.staticTexts["Planlarım"].waitForExistence(timeout: 5)
                || byId("mealPlans.createButton").exists
                || byId("mealPlans.emptyCreateButton").exists {
                return
            }
        }
        // The hero card ignores synthesized taps in the simulator; enter via
        // the DEBUG-only launch argument instead.
        relaunchIntoMealPrep()
    }

    func test01_generateSaveAndListAIMealPlan() {
        // The featured hero card opens the saved plans screen (the test user is
        // seeded as "pro", so no paywall, and the pantry gate is satisfied).
        openSavedPlans()

        // Saved plans screen: create a new plan from either entry point.
        let toolbarCreate = byId("mealPlans.createButton")
        let emptyCreate = byId("mealPlans.emptyCreateButton")
        XCTAssertTrue(toolbarCreate.waitForExistence(timeout: 20) || emptyCreate.waitForExistence(timeout: 5),
                      "Saved plans screen did not open (no create button)")
        if emptyCreate.exists && emptyCreate.isHittable {
            emptyCreate.tap()
        } else {
            toolbarCreate.tap()
        }

        // Method choice → AI.
        tap(id: "mealPrep.aiButton", fallbackLabel: "AI ile Oluştur", timeout: 15)

        // Step 1 — people count (default preselected).
        tapContinueStep(expectedHeadline: nil)
        // Step 2 — meals per day.
        tapContinueStep(expectedHeadline: nil)
        // Step 3 — eating style: multi-select, requires at least one choice.
        assertExists(app.staticTexts["Nasıl beslenmeyi seviyorsun?"], timeout: 10,
                     "Eating style step missing")
        app.staticTexts["Pratik"].tap()
        tapContinueStep(expectedHeadline: nil)
        // Step 4 — period.
        tapContinueStep(expectedHeadline: nil)
        // Step 5 — kids.
        tapContinueStep(expectedHeadline: nil)
        // Step 6 — prep style.
        tapContinueStep(expectedHeadline: nil)

        // Step 7 — budget → generate.
        let generate = byId("mealPrep.generateButton")
        assertExists(generate, timeout: 10, "'Planı Oluştur' button missing on budget step")
        generate.tap()

        // Real Claude call: wait for the result view. The backend allows up to
        // 120s per attempt with retries, so give it plenty of room.
        let save = byId("mealPrep.savePlanButton")
        let retry = app.buttons["Tekrar Dene"]
        let deadline = Date().addingTimeInterval(240)
        var retried = false
        while Date() < deadline {
            if save.exists { break }
            if retry.exists && !retried {
                // One retry on a transient AI failure.
                retried = true
                retry.tap()
            }
            sleep(2)
        }
        XCTAssertTrue(save.exists, "Meal plan generation did not produce a result within 4 minutes")

        // The generated plan renders day sections.
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'öğün' OR label CONTAINS 'Gün' OR label CONTAINS 'Pazartesi'"))
                .firstMatch.exists,
            "Generated plan does not show any day/meal content"
        )

        // Save the plan (POST /meal-plans with the Clerk token).
        save.tap()
        XCTAssertTrue(app.staticTexts["Kaydedildi"].waitForExistence(timeout: 20),
                      "Plan save did not confirm (Kaydedildi missing)")

        // Verify persistence with a cold start: relaunch straight into the
        // saved-plans screen, which re-fetches GET /users/:id/meal-plans.
        relaunchIntoMealPrep()
        assertExists(app.staticTexts["Planlarım"], timeout: 20,
                     "Saved plans list is empty after saving an AI plan")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'yemek planı'")).firstMatch
                .waitForExistence(timeout: 10),
            "Plan count label missing in saved plans list"
        )
    }

    /// Taps the current wizard step's continue button. Labels vary:
    /// "Devam Et", "Devam Et (N seçildi)".
    private func tapContinueStep(expectedHeadline: String?) {
        if let headline = expectedHeadline {
            assertExists(app.staticTexts[headline], timeout: 10, "Wizard step '\(headline)' missing")
        }
        let cont = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Devam Et'")).firstMatch
        XCTAssertTrue(cont.waitForExistence(timeout: 10), "Wizard continue button missing")
        cont.tap()
    }
}
