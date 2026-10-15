import XCTest

/// Home hub: the five app modes and the live pantry/shopping counters that are
/// fetched from the backend on appear.
final class A02_HomeHubTests: FeslihanUITestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        ensureSignedInAtHome()
    }

    /// All five modes are present on the hub.
    func test01_allFiveModesVisible() {
        assertExists(app.staticTexts["Haftalık Plan"], "Haftalık Plan (meal prep) entry missing")
        assertExists(app.staticTexts["Ne Yesem?"], "Ne Yesem? entry missing")
        assertExists(app.staticTexts["Tariflerim"], "Tariflerim entry missing")
        assertExists(app.staticTexts["Kilerim"], "Kilerim entry missing")
        assertExists(app.staticTexts["Alışveriş"], "Alışveriş entry missing")
        // Meal prep is the premium feature and carries the PLUS badge.
        assertExists(app.staticTexts["PLUS"], timeout: 5, "PLUS badge missing on Haftalık Plan")
    }

    /// The pantry counter reflects the seeded test data (>= 30 items), which
    /// proves the app fetched /users/:id/pantry from the test backend with a
    /// valid Clerk token. 30 is also the gate below which most modes lock.
    func test02_pantryCountReflectsSeededBackendData() {
        let pantryCell = byId("home.mode.pantry")
        assertExists(pantryCell, timeout: 15, "Kilerim cell missing")

        // The counter loads asynchronously; poll until it is >= 30.
        let deadline = Date().addingTimeInterval(20)
        var count = firstInt(in: pantryCell.label) ?? 0
        while count < 30 && Date() < deadline {
            sleep(1)
            count = firstInt(in: pantryCell.label) ?? 0
        }
        XCTAssertGreaterThanOrEqual(
            count, 30,
            "Pantry counter shows \(count); expected >= 30 seeded items. Label: '\(pantryCell.label)'"
        )
    }

    /// The account sheet opens with profile info and navigation entries.
    func test03_accountSheetOpens() {
        tap(id: "home.accountButton", fallbackLabel: "Hesabım")
        assertExists(app.staticTexts["Hesabım"], "Account sheet title missing")
        assertExists(app.staticTexts["Ayarlar"], timeout: 5, "Settings row missing in account sheet")
        // Close the sheet.
        let close = app.buttons.matching(NSPredicate(format: "label == 'xmark' OR identifier == 'xmark'")).firstMatch
        if close.exists && close.isHittable {
            close.tap()
        } else {
            app.swipeDown(velocity: .fast)
        }
    }
}
