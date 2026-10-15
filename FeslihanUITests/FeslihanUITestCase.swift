import XCTest

/// Configuration passed from the CI runner (xcodebuild TEST_RUNNER_* env vars).
enum TestEnv {
    /// Backend origin the app under test should talk to.
    static var apiURL: String {
        ProcessInfo.processInfo.environment["FESLIHAN_API_URL"] ?? "http://127.0.0.1:3000"
    }

    /// Clerk test-mode account. For a dev instance, an email containing
    /// "+clerk_test" signs in with the fixed OTP code 424242 and no real email.
    static var email: String {
        ProcessInfo.processInfo.environment["E2E_CLERK_EMAIL"] ?? ""
    }

    /// Password sign-in (preferred when the Clerk instance has password auth).
    static var password: String {
        ProcessInfo.processInfo.environment["E2E_CLERK_PASSWORD"] ?? ""
    }

    /// OTP fallback. 424242 is Clerk's fixed test-mode verification code.
    static var otpCode: String {
        ProcessInfo.processInfo.environment["E2E_CLERK_OTP_CODE"] ?? "424242"
    }
}

/// Base class for all Feslihan UI tests: launches the app against the test
/// backend and knows how to get from a cold launch to the signed-in home hub
/// regardless of which intermediate screens (Clerk auth sheet, splash,
/// onboarding) appear.
class FeslihanUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["FESLIHAN_API_URL"] = TestEnv.apiURL
        app.launch()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    // MARK: - Element lookup

    /// Finds an element by accessibility identifier regardless of its element
    /// type (SwiftUI combined elements sometimes surface as Other, not Button).
    func byId(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Taps the element with `identifier`, falling back to a static text with
    /// `label` when the identifier does not resolve to a hittable element.
    func tap(id identifier: String, fallbackLabel: String? = nil,
             timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        let element = byId(identifier)
        if element.waitForExistence(timeout: timeout), element.isHittable {
            element.tap()
            return
        }
        if let label = fallbackLabel {
            let text = app.staticTexts[label]
            if text.waitForExistence(timeout: 3) {
                text.tap()
                return
            }
        }
        XCTFail("Neither identifier '\(identifier)' nor label '\(fallbackLabel ?? "-")' was tappable", file: file, line: line)
    }

    @discardableResult
    func assertExists(_ element: XCUIElement, timeout: TimeInterval = 10,
                      _ message: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), message, file: file, line: line)
        return element
    }

    /// Waits for `element` to disappear.
    func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval = 10,
                              file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "Element did not disappear within \(timeout)s", file: file, line: line)
    }

    // MARK: - App flow helpers

    /// True when the signed-out landing screen is showing.
    var isOnSignedOutLanding: Bool {
        app.buttons["auth.signInButton"].exists
    }

    /// Brings the app from any post-launch state to the signed-in home hub.
    /// Handles: signed-out landing → Clerk sign-in, splash animation,
    /// first-run onboarding.
    func ensureSignedInAtHome(file: StaticString = #filePath, line: UInt = #line) {
        // Give the app a moment to settle into either the landing screen or
        // the splash/home flow.
        if app.buttons["auth.signInButton"].waitForExistence(timeout: 6) {
            performClerkSignIn(file: file, line: line)
        }
        dismissOnboardingIfPresent()
        assertHomeHub(file: file, line: line)
    }

    /// Signs in through Clerk's prebuilt AuthView. Supports both password and
    /// email-code (OTP) first factors; for Clerk dev instances the test-mode
    /// code 424242 is accepted for "+clerk_test" emails without sending email.
    func performClerkSignIn(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(TestEnv.email.isEmpty,
                       "E2E_CLERK_EMAIL is not set — pass it via TEST_RUNNER_E2E_CLERK_EMAIL",
                       file: file, line: line)

        app.buttons["auth.signInButton"].tap()

        // Clerk sheet: first input is the email (or email/username) field.
        let emailField = app.textFields.firstMatch
        XCTAssertTrue(emailField.waitForExistence(timeout: 20),
                      "Clerk AuthView email field did not appear", file: file, line: line)
        emailField.tap()
        emailField.typeText(TestEnv.email)
        tapClerkContinue(file: file, line: line)

        // Second factor: either a password secure field or an OTP code entry.
        let secureField = app.secureTextFields.firstMatch
        if !TestEnv.password.isEmpty, secureField.waitForExistence(timeout: 8) {
            secureField.tap()
            secureField.typeText(TestEnv.password)
            tapClerkContinue(file: file, line: line)
        } else {
            // OTP path. Clerk renders the code entry as one or more text fields.
            let codeField = app.textFields.firstMatch
            if codeField.waitForExistence(timeout: 8) {
                codeField.tap()
                codeField.typeText(TestEnv.otpCode)
            } else {
                // Some Clerk versions keep keyboard focus on the code boxes —
                // type blindly into the app.
                app.typeText(TestEnv.otpCode)
            }
        }

        // Successful sign-in dismisses the sheet; landing buttons disappear.
        let signedIn = NSPredicate(format: "exists == false")
        let gone = XCTNSPredicateExpectation(predicate: signedIn, object: app.buttons["auth.signInButton"])
        let result = XCTWaiter().wait(for: [gone], timeout: 30)
        XCTAssertEqual(result, .completed, "Sign-in did not complete (landing screen still visible)", file: file, line: line)
    }

    /// Taps whatever "continue" button Clerk's sheet is showing. The label
    /// depends on the ClerkKitUI version and device locale.
    private func tapClerkContinue(file: StaticString = #filePath, line: UInt = #line) {
        let candidates = ["Continue", "Devam", "Devam Et", "Devam et", "Sign in", "Giriş yap", "Giriş Yap"]
        for label in candidates {
            let button = app.buttons[label]
            if button.waitForExistence(timeout: 2), button.isHittable {
                button.tap()
                return
            }
        }
        // Fall back to the keyboard return key, which submits Clerk forms.
        if app.keyboards.buttons["return"].exists {
            app.keyboards.buttons["return"].tap()
            return
        }
        XCTFail("Could not find a continue/submit button in the Clerk auth sheet", file: file, line: line)
    }

    /// Skips the two-step first-run onboarding if it is showing.
    func dismissOnboardingIfPresent() {
        let skip = app.buttons["onboarding.skipButton"]
        // Splash runs for ~1-4s before onboarding/home appears.
        if skip.waitForExistence(timeout: 8) {
            skip.tap()
        }
    }

    /// Asserts the home hub (mode selection screen) is visible.
    func assertHomeHub(timeout: TimeInterval = 25, file: StaticString = #filePath, line: UInt = #line) {
        let pantryCell = byId("home.mode.pantry")
        if pantryCell.waitForExistence(timeout: timeout) { return }
        // Fallback: the Kilerim util cell label.
        XCTAssertTrue(app.staticTexts["Kilerim"].waitForExistence(timeout: 5),
                      "Home hub did not appear", file: file, line: line)
    }

    /// Opens one of the five modes from the home hub.
    func openMode(id: String, fallbackLabel: String,
                  file: StaticString = #filePath, line: UInt = #line) {
        assertHomeHub(file: file, line: line)
        tap(id: id, fallbackLabel: fallbackLabel, file: file, line: line)
    }

    /// Returns to the home hub using the in-app back button.
    func goBackHome(file: StaticString = #filePath, line: UInt = #line) {
        let back = app.buttons["backButton"]
        if back.waitForExistence(timeout: 5), back.isHittable {
            back.tap()
        }
        assertHomeHub(file: file, line: line)
    }

    /// Extracts the first integer appearing in an element's label.
    func firstInt(in label: String) -> Int? {
        let digits = label.components(separatedBy: CharacterSet.decimalDigits.inverted)
        return digits.compactMap { Int($0) }.first
    }
}
