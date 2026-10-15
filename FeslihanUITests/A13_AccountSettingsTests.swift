import XCTest

/// Hesap sayfası ve Ayarlar: navigasyon kısayolları ve ayar bölümleri.
/// Çıkış Yap / Hesabı Sil'e DOKUNULMAZ — oturum sonraki suite'ler için gerekli.
final class A13_AccountSettingsTests: FeslihanUITestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        ensureSignedInAtHome()
    }

    /// Account sheet shortcuts navigate to Kilerim and Alışveriş Listesi.
    func test01_accountSheetNavigatesToPantry() {
        tap(id: "home.accountButton", fallbackLabel: "Hesabım")
        assertExists(app.staticTexts["Hesabım"], timeout: 10, "Account sheet did not open")

        app.staticTexts["Evindeki malzemeleri yönet"].tap()
        assertExists(app.staticTexts["Kilerim"], timeout: 15, "Pantry did not open from account sheet")
        goBackHome()
    }

    /// Settings screen renders all sections without touching destructive rows.
    func test02_settingsSectionsRender() {
        tap(id: "home.accountButton", fallbackLabel: "Hesabım")
        assertExists(app.staticTexts["Ayarlar"], timeout: 10, "Settings row missing")
        app.staticTexts["Ayarlar"].tap()

        assertExists(app.staticTexts["Abonelik"], timeout: 10, "Abonelik section missing")
        assertExists(app.staticTexts["Yasal"], timeout: 5, "Yasal section missing")
        assertExists(app.staticTexts["Destek"], timeout: 5, "Destek section missing")
        assertExists(app.staticTexts["Hesap"], timeout: 5, "Hesap section missing")
        assertExists(app.staticTexts["Çıkış Yap"], timeout: 5, "Çıkış Yap row missing")
        assertExists(app.staticTexts["Hesabı Sil"], timeout: 5, "Hesabı Sil row missing")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Sürüm'")).firstMatch.exists,
            "Version label missing"
        )
    }
}
