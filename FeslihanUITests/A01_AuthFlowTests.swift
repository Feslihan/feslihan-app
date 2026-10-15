import XCTest

/// Auth flow: signed-out landing screen and Clerk test-mode sign-in.
/// Runs first (alphabetical order) so later suites start from a signed-in
/// session persisted in the simulator keychain.
final class A01_AuthFlowTests: FeslihanUITestCase {

    /// The signed-out landing screen shows the brand hero and both auth CTAs.
    func test01_signedOutLandingShowsAuthOptions() throws {
        guard isOnSignedOutLanding else {
            throw XCTSkip("Already signed in from a previous run — landing screen not reachable")
        }

        assertExists(app.staticTexts["Feslihan"], "Brand title missing on landing screen")
        assertExists(app.staticTexts["Annenin yemek defteri, her zaman cebinde."],
                     timeout: 5, "Tagline missing on landing screen")
        assertExists(app.buttons["auth.signInButton"], timeout: 5, "Giriş Yap button missing")
        assertExists(app.buttons["auth.signUpButton"], timeout: 5, "Kayıt Ol button missing")
    }

    /// Tapping Giriş Yap opens Clerk's auth sheet.
    func test02_signInButtonOpensClerkSheet() throws {
        guard isOnSignedOutLanding else {
            throw XCTSkip("Already signed in — Clerk sheet not reachable")
        }

        app.buttons["auth.signInButton"].tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 20),
                      "Clerk AuthView did not present an email field")
        // Close the sheet again so test03 starts from the landing screen.
        app.swipeDown(velocity: .fast)
    }

    /// Full sign-in with the Clerk test account, ending on the home hub.
    /// Also exercises the /users/sync backend call (new users get the platform
    /// recipe collection mapped) and the splash → onboarding → home flow.
    func test03_signInWithTestAccountReachesHome() {
        ensureSignedInAtHome()

        // The greeting block confirms Clerk delivered a user object.
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Merhaba'")).firstMatch
                .waitForExistence(timeout: 10),
            "Greeting with user name missing after sign-in"
        )
    }
}
