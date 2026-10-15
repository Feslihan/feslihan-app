import XCTest

/// Manuel plan: sihirbazın "Manuel Oluştur" yolu — plan adı, gün sayısı, güne
/// öğün/tarif ekleme, kaydetme, kayıtlı planı açma (sekmeler) ve silme.
/// AI çağrısı YOK; saf CRUD akışı.
final class A12_ManualMealPlanTests: FeslihanUITestCase {

    /// Unique per run so leftovers from interrupted earlier runs never
    /// produce multiple matches.
    private let planName = "E2E-" + String(UUID().uuidString.prefix(6))

    override func setUpWithError() throws {
        try super.setUpWithError()
        ensureSignedInAtHome()
    }

    /// Hero-card tap with launch-argument fallback (see A07.openSavedPlans).
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
        relaunchIntoMealPrep()
    }

    func test01_createManualPlanSaveOpenDelete() {
        // Saved plans screen → create.
        openSavedPlans()
        let toolbarCreate = byId("mealPlans.createButton")
        let emptyCreate = byId("mealPlans.emptyCreateButton")
        XCTAssertTrue(toolbarCreate.waitForExistence(timeout: 20) || emptyCreate.exists,
                      "Saved plans screen did not open")
        (emptyCreate.exists && emptyCreate.isHittable ? emptyCreate : toolbarCreate).tap()

        // Method choice → Manuel.
        let manual = app.staticTexts["Manuel Oluştur"]
        assertExists(manual, timeout: 15, "'Manuel Oluştur' option missing")
        manual.tap()
        assertExists(app.staticTexts["Manuel Plan"], timeout: 15, "Manual builder did not open")

        // Plan adı.
        let nameField = app.textFields["örn. Bu Haftanın Planı"]
        assertExists(nameField, timeout: 10, "Plan name field missing")
        nameField.tap()
        nameField.typeText(planName)
        // Dismiss the keyboard so the controls below are tappable. The return
        // key's label is locale-dependent ("Geç" on the Turkish keyboard).
        let returnKey = app.keyboards.buttons.matching(
            NSPredicate(format: "label IN %@", ["return", "Return", "Geç", "Done", "Bitti", "done", "Git"])
        ).firstMatch
        if returnKey.exists { returnKey.tap() } else if app.keyboards.firstMatch.exists { app.swipeDown() }

        // 1 günlük plan — tek kart, deterministik. (1 günlük planda gün adı
        // "Bugün" olur; "Pazartesi" yalnızca 2-7 günlük planlarda görünür.)
        let oneDay = app.buttons["1 Gün"]
        scrollTo(oneDay)
        oneDay.tap()

        // Günü aç ve öğün ekle.
        let day = app.staticTexts["Bugün"]
        assertExists(day, timeout: 10, "Day card missing")
        scrollTo(day, maxSwipes: 3)
        day.tap()
        let addMeal = app.buttons["Öğün Ekle"]
        assertExists(addMeal, timeout: 5, "'Öğün Ekle' button missing")
        addMeal.tap()

        // MealEditSheet: ana tarif seç.
        assertExists(app.staticTexts["Ana Tarif"], timeout: 10, "Meal edit sheet did not open")
        app.staticTexts["Tarif seç…"].tap()
        assertExists(app.staticTexts["Tarif Seç"], timeout: 10, "Recipe picker did not open")

        // Narrow the searchable list, then pick the seeded recipe. Fall back
        // to scrolling if the search field isn't exposed.
        let pick = app.staticTexts["Mercimek Çorbası"].firstMatch
        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText("Mercimek")
        }
        var swipes = 0
        while !pick.exists && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        assertExists(pick, "Seeded recipe missing from picker")
        pick.tap()

        // Kaydet — DİKKAT: gün kartındaki buton da sheet'teki kaydet butonu da
        // "Öğün Ekle" etiketli; sheet'inki hiyerarşide sonda olduğundan son
        // eşleşeni al.
        let mealButtons = app.buttons.matching(NSPredicate(format: "label == 'Öğün Ekle'"))
        assertExists(mealButtons.firstMatch, timeout: 10, "Meal save button missing")
        let saveMeal = mealButtons.element(boundBy: mealButtons.count - 1)
        XCTAssertTrue(saveMeal.isEnabled, "Meal save should enable after picking a recipe")
        saveMeal.tap()

        // Özet pill'leri ve kaydet butonu görünür.
        assertExists(app.staticTexts["Tarif"], timeout: 10, "Summary pills missing after adding a meal")
        let savePlan = app.buttons["Planı Kaydet"]
        assertExists(savePlan, timeout: 10, "'Planı Kaydet' missing")
        savePlan.tap()
        assertExists(app.staticTexts["Kaydedildi"], timeout: 20, "Plan save did not confirm")

        // Kalıcılığı soğuk başlangıçla doğrula: relaunch doğrudan plan
        // listesine girer ve backend'den taze çeker.
        relaunchIntoMealPrep()
        assertExists(app.staticTexts["Planlarım"], timeout: 20, "Saved plans list did not load")
        assertExists(app.staticTexts[planName].firstMatch, timeout: 10, "Manual plan missing from the list")

        // Planı aç: detay sayfası iki sekmeli.
        app.staticTexts[planName].firstMatch.tap()
        // Detay sekmeleri Button olarak expose olur (Button iç metni yutar).
        assertExists(app.buttons["Yemek Planı"], timeout: 15, "Plan detail tab missing")
        assertExists(app.buttons["Alışveriş Listesi"], timeout: 5, "Shopping tab missing")
        app.buttons["Alışveriş Listesi"].tap()
        // Malzeme listesi tarifin malzemelerinden türetilir.
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'malzeme'")).firstMatch
                .waitForExistence(timeout: 10)
                || app.staticTexts["Alışveriş listesi boş"].exists,
            "Shopping tab rendered neither items nor empty state"
        )
        app.buttons["Kapat"].tap()

        // Temizlik: planı sil.
        // Long-press context menu — the proven-reliable deletion path.
        let card = app.staticTexts[planName].firstMatch
        assertExists(card, timeout: 10, "Plan card missing before delete")
        card.press(forDuration: 1.2)
        let delete = app.buttons["Sil"].firstMatch
        assertExists(delete, timeout: 5, "Sil context-menu item missing")
        delete.tap()
        waitForDisappearance(of: app.staticTexts[planName].firstMatch, timeout: 15)
    }
}
