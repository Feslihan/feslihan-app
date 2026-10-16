import XCTest

/// Klasörler: oluşturma, tarif taşıma, klasörden çıkarma ve klasör silme —
/// hepsi backend folders API'sine gerçek çağrılar.
final class A11_FoldersTests: FeslihanUITestCase {

    private let folderName = "E2E Klasör"
    private let recipeTitle = "Mercimek Çorbası"

    override func setUpWithError() throws {
        try super.setUpWithError()
        ensureSignedInAtHome()
        openMode(id: "home.mode.browse", fallbackLabel: "Tariflerim")
        assertExists(app.staticTexts["Tüm Tarifler"], timeout: 20, "Recipe list did not load")
    }

    /// Full folder lifecycle in one ordered scenario to avoid cross-test
    /// state: create → move recipe in → verify contents → move out →
    /// delete folder.
    func test01_folderLifecycle() {
        // ── Create ──
        // Entry point differs depending on whether folders already exist.
        if app.staticTexts["Klasörlerim"].exists {
            app.staticTexts["Yeni Klasör"].tap()
        } else {
            let createEntry = app.buttons["Klasör Oluştur"]
            if createEntry.waitForExistence(timeout: 5) {
                createEntry.tap()
            } else {
                app.staticTexts["Yeni Klasör"].tap()
            }
        }

        let nameField = app.textFields["Klasör adı"]
        assertExists(nameField, timeout: 10, "Create-folder alert did not appear")
        nameField.tap()
        nameField.typeText(folderName)
        app.buttons["Oluştur"].tap()

        XCTAssertTrue(app.staticTexts[folderName].waitForExistence(timeout: 15),
                      "New folder card did not appear")

        // ── Move a recipe into the folder (context menu on the card) ──
        let cell = app.staticTexts[recipeTitle]
        if !cell.exists { app.swipeUp() }
        assertExists(cell, "Recipe cell missing")
        cell.press(forDuration: 1.2)

        let moveMenu = app.buttons["Klasöre Taşı"]
        assertExists(moveMenu, timeout: 5, "'Klasöre Taşı' menu missing")
        moveMenu.tap()
        let target = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", folderName)).firstMatch
        assertExists(target, timeout: 5, "Folder entry missing in move menu")
        target.tap()

        // ── Open the folder and verify contents ──
        if app.staticTexts[folderName].exists == false { app.swipeDown() }
        app.staticTexts[folderName].firstMatch.tap()
        XCTAssertTrue(app.staticTexts[recipeTitle].waitForExistence(timeout: 15),
                      "Moved recipe not visible inside the folder")

        // ── Move it back out ──
        app.staticTexts[recipeTitle].press(forDuration: 1.2)
        let removeFromFolder = app.buttons["Klasörden Çıkar"]
        assertExists(removeFromFolder, timeout: 5, "'Klasörden Çıkar' menu item missing")
        removeFromFolder.tap()
        waitForDisappearance(of: app.staticTexts[recipeTitle], timeout: 15)

        // ── Back to the main list, delete the folder ──
        app.buttons["backButton"].tap()
        assertExists(app.staticTexts["Tüm Tarifler"], timeout: 10, "Did not return to the main list")

        let folderCard = app.staticTexts[folderName]
        assertExists(folderCard, timeout: 10, "Folder card missing before delete")
        folderCard.press(forDuration: 1.2)
        let deleteFolder = app.buttons["Klasörü Sil"]
        assertExists(deleteFolder, timeout: 5, "'Klasörü Sil' menu item missing")
        deleteFolder.tap()
        waitForDisappearance(of: app.staticTexts[folderName], timeout: 15)
    }
}
