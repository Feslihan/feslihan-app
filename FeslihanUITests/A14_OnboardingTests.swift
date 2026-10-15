import XCTest

/// İlk kullanım onboarding'i. Normal koşuda onboarding yalnızca ilk girişte
/// göründüğünden, bu suite `-hasCompletedOnboarding NO` launch argümanıyla
/// (NSUserDefaults argument domain, AppStorage'ı geçersiz kılar) akışı zorlar.
///
/// Not: Argument domain yazmaları da geçersiz kıldığı için "Başla"nın akışı
/// bitirmesi bu modda gözlemlenemez; adımların kendisi ve CTA'ları doğrulanır.
final class A14_OnboardingTests: FeslihanUITestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["FESLIHAN_API_URL"] = TestEnv.apiURL
        app.launchArguments += ["-hasCompletedOnboarding", "NO"]
        app.launch()

        if app.buttons["auth.signInButton"].waitForExistence(timeout: 6) {
            performClerkSignIn()
        }
    }

    /// Both onboarding steps render with their CTAs; the primary buttons open
    /// the add-recipe sheet and the pantry bubble sheet respectively.
    func test01_onboardingStepsAndCTAs() {
        let skip = app.buttons["onboarding.skipButton"]
        XCTAssertTrue(skip.waitForExistence(timeout: 20),
                      "Onboarding did not appear despite -hasCompletedOnboarding NO")

        // Step 1 — add recipe.
        assertExists(app.staticTexts["Önce tariflerini ekle"], timeout: 10, "Step 1 title missing")
        tap(id: "onboarding.primaryButton", fallbackLabel: "Tarif Ekle")
        assertExists(app.staticTexts["Yeni Tarif"], timeout: 10, "Add-recipe sheet did not open from onboarding")
        // Close the sheet — dismissing advances to step 2 (onDismiss: advance).
        let close = app.navigationBars.buttons.firstMatch
        if close.exists && close.isHittable { close.tap() } else { app.swipeDown(velocity: .fast) }

        // Step 2 — fill pantry.
        assertExists(app.staticTexts["Sonra kilerini doldur"], timeout: 10, "Step 2 title missing")
        tap(id: "onboarding.primaryButton", fallbackLabel: "Malzeme Ekle")
        assertExists(app.staticTexts["Evinde ne var?"], timeout: 15, "Bubble sheet did not open from onboarding")
    }
}
