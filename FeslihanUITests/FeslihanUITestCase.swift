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

    /// Finds an element by accessibility identifier. Prefers the Button-typed
    /// match (its frame is the real tap target); falls back to any element
    /// type (SwiftUI combined elements sometimes surface as Other).
    func byId(_ identifier: String) -> XCUIElement {
        let button = app.buttons.matching(identifier: identifier).firstMatch
        if button.exists { return button }
        return app.descendants(matching: .any).matching(identifier: identifier).firstMatch
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

    /// Focuses `element`, clears any existing content, and types `text`.
    /// Clerk persists a half-finished sign-in attempt in the keychain and
    /// pre-fills the identifier on the next launch — typing without clearing
    /// concatenates onto the stale value.
    func clearAndType(_ element: XCUIElement, text: String) {
        // Tap the field body left of center — password fields keep a
        // show/hide icon at the right edge that would swallow the tap.
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.6)).tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 5)
        // Clear any stale content (Clerk persists half-finished attempts).
        app.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 100))
        app.typeText(text)
    }

    /// Waits for `element` to become enabled; returns the final state.
    @discardableResult
    func waitUntilEnabled(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.isEnabled { return true }
            usleep(300_000)
        }
        return element.exists && element.isEnabled
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

    /// Finds a Clerk input by its placeholder/label text. Clerk's custom
    /// styling masks the underlying TextField from the accessibility tree
    /// (the whole sheet exposes zero textFields); the inputs surface as
    /// StaticText placeholders instead. Tapping that element's frame focuses
    /// the real field, after which `app.typeText` reaches the first responder.
    func clerkInput(labelContains candidates: [String]) -> XCUIElement {
        let typePredicate = NSPredicate(
            format: "elementType == %d OR elementType == %d OR elementType == %d",
            XCUIElement.ElementType.staticText.rawValue,
            XCUIElement.ElementType.textField.rawValue,
            XCUIElement.ElementType.secureTextField.rawValue
        )
        let labelPredicate = NSCompoundPredicate(orPredicateWithSubpredicates:
            candidates.map { NSPredicate(format: "label CONTAINS[c] %@ OR placeholderValue CONTAINS[c] %@", $0, $0) }
        )
        return app.descendants(matching: .any)
            .matching(typePredicate)
            .matching(labelPredicate)
            .firstMatch
    }

    /// Signs in through Clerk's prebuilt AuthView. Supports both password and
    /// email-code (OTP) first factors; for Clerk dev instances the test-mode
    /// code 424242 is accepted for "+clerk_test" emails without sending email.
    func performClerkSignIn(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(TestEnv.email.isEmpty,
                       "E2E_CLERK_EMAIL is not set — pass it via TEST_RUNNER_E2E_CLERK_EMAIL",
                       file: file, line: line)

        app.buttons["auth.signInButton"].tap()

        // Email step. Clerk's Continue button stays disabled while the field
        // is empty, which doubles as our "did the text actually land" check —
        // typeText can silently no-op when the software keyboard isn't up yet.
        let emailInput = clerkInput(labelContains: ["email", "e-posta"])
        XCTAssertTrue(emailInput.waitForExistence(timeout: 20),
                      "Clerk AuthView email input did not appear", file: file, line: line)

        let continueButton = app.buttons["Continue"].exists
            ? app.buttons["Continue"]
            : app.buttons.matching(NSPredicate(format: "label IN %@", ["Devam", "Devam et", "Devam Et"])).firstMatch

        var attempts = 0
        repeat {
            clearAndType(emailInput, text: TestEnv.email)
            attempts += 1
        } while !waitUntilEnabled(continueButton, timeout: 4) && attempts < 3

        XCTAssertTrue(continueButton.isEnabled,
                      "Email text never registered in Clerk's input (Continue stayed disabled)",
                      file: file, line: line)
        tapClerkContinue(file: file, line: line)

        // Clerk surfaces validation problems inline; fail fast with the
        // actual message instead of timing out on the next step.
        let clerkError = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'invalid' OR label CONTAINS[c] 'geçersiz' OR label CONTAINS[c] 'not found' OR label CONTAINS[c] 'bulunamadı'")
        ).firstMatch
        if clerkError.waitForExistence(timeout: 3) {
            print("CLERKFAIL-HIERARCHY-BEGIN")
            print(app.debugDescription)
            print("CLERKFAIL-HIERARCHY-END")
            XCTFail("Clerk rejected the identifier: '\(clerkError.label)' — see CLERKFAIL-HIERARCHY in log",
                    file: file, line: line)
            return
        }

        // Second factor — always drive the EMAIL CODE path: its screen
        // auto-focuses the code boxes with the keyboard up, and test mode
        // accepts the fixed 424242 for +clerk_test addresses. Clerk remembers
        // the last-used factor, so a password screen may appear first; switch
        // over via "Use another method".
        let otpScreen = app.staticTexts["Check your email"]
        let passwordScreen = app.staticTexts["Enter password"]

        if !otpScreen.waitForExistence(timeout: 12) {
            XCTAssertTrue(passwordScreen.waitForExistence(timeout: 5),
                          "Clerk showed neither the email-code nor the password screen",
                          file: file, line: line)
            let useAnother = app.descendants(matching: .any).matching(
                NSPredicate(format: "label == 'Use another method'")
            ).firstMatch
            XCTAssertTrue(useAnother.waitForExistence(timeout: 5),
                          "'Use another method' link missing on password screen", file: file, line: line)
            useAnother.tap()
            let emailCodeOption = app.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS[c] 'email code' OR label CONTAINS[c] 'code to'")
            ).firstMatch
            XCTAssertTrue(emailCodeOption.waitForExistence(timeout: 10),
                          "'Email code' alternative method not offered", file: file, line: line)
            emailCodeOption.tap()
            XCTAssertTrue(otpScreen.waitForExistence(timeout: 15),
                          "Email-code screen did not appear after switching method",
                          file: file, line: line)
        }

        // Code boxes grab focus on appear; give the keyboard a beat.
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 5)
        app.typeText(TestEnv.otpCode)

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

    /// Asserts the home hub (mode selection screen) is visible, then waits
    /// for the async pantry counter to load. Tapping Haftalık Plan or Ne
    /// Yesem? while pantryCount is still 0 trips the 30-item pantry gate.
    func assertHomeHub(timeout: TimeInterval = 25, file: StaticString = #filePath, line: UInt = #line) {
        let pantryCell = byId("home.mode.pantry")
        if !pantryCell.waitForExistence(timeout: timeout) {
            XCTAssertTrue(app.staticTexts["Kilerim"].waitForExistence(timeout: 5),
                          "Home hub did not appear", file: file, line: line)
        }
        let deadline = Date().addingTimeInterval(12)
        while (firstInt(in: pantryCell.label) ?? 0) < 30 && Date() < deadline {
            usleep(500_000)
        }
    }

    /// Relaunches the app straight into the saved-plans (meal prep) screen
    /// via the DEBUG-only -e2eStartMealPrep launch argument. The hub's hero
    /// card ignores synthesized taps in the simulator (real touches work),
    /// so tests cannot reach this screen by tapping.
    func relaunchIntoMealPrep(file: StaticString = #filePath, line: UInt = #line) {
        app.terminate()
        app.launchArguments.append("-e2eStartMealPrep")
        app.launch()
        dismissOnboardingIfPresent()
        XCTAssertTrue(
            app.staticTexts["Planlarım"].waitForExistence(timeout: 25)
                || byId("mealPlans.createButton").waitForExistence(timeout: 5)
                || byId("mealPlans.emptyCreateButton").exists,
            "Saved plans screen did not open via -e2eStartMealPrep",
            file: file, line: line
        )
        app.launchArguments.removeAll { $0 == "-e2eStartMealPrep" }
    }

    /// Dismisses the 30-item pantry gate if a premature tap tripped it.
    func dismissPantryGateIfPresent() {
        let gateBack = app.buttons["pantryGate.backButton"]
        if app.staticTexts["Önce kilerini doldur!"].exists, gateBack.exists {
            gateBack.tap()
        }
    }

    /// Opens one of the five modes from the home hub.
    func openMode(id: String, fallbackLabel: String,
                  file: StaticString = #filePath, line: UInt = #line) {
        assertHomeHub(file: file, line: line)
        tap(id: id, fallbackLabel: fallbackLabel, file: file, line: line)
    }

    /// Taps the in-app back button. Uses a coordinate tap: overlay-style back
    /// buttons report isHittable == false even when perfectly tappable.
    func tapBack() {
        let back = app.buttons["backButton"].firstMatch
        if back.exists {
            back.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    /// Returns to the home hub using the in-app back button.
    func goBackHome(file: StaticString = #filePath, line: UInt = #line) {
        if app.buttons["backButton"].firstMatch.waitForExistence(timeout: 5) {
            tapBack()
        }
        assertHomeHub(file: file, line: line)
    }

    /// Opens a recipe's detail view from the currently visible recipe grid.
    /// Recipe cards are NavigationLinks with an attached contextMenu, a combo
    /// that can swallow XCUITest's synthesized tap — so this escalates:
    /// plain tap → coordinate tap → short press, verifying navigation after
    /// each attempt via the detail view's "Malzemeler" tab.
    func openRecipeDetail(title: String, file: StaticString = #filePath, line: UInt = #line) {
        let cell = app.staticTexts[title].firstMatch
        scrollTo(cell, file: file, line: line)

        // The detail view's tab bar exposes its tabs as BUTTONS (the Button
        // swallows its inner text), so query buttons — not staticTexts.
        let detailMarker = app.buttons["Malzemeler"]
        cell.tap()
        if detailMarker.waitForExistence(timeout: 6) { return }

        cell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(detailMarker.waitForExistence(timeout: 10),
                      "Detail view did not open for '\(title)'",
                      file: file, line: line)
    }

    /// Swipes up until `element` is actually on screen and tappable.
    /// `exists` alone is not enough: lazy grids report offscreen cells as
    /// existing, and tapping them lands on whatever occupies their coordinates.
    func scrollTo(_ element: XCUIElement, maxSwipes: Int = 8,
                  file: StaticString = #filePath, line: UInt = #line) {
        var swipes = 0
        while (!element.exists || !element.isHittable) && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(element.exists && element.isHittable,
                      "Element not reachable after \(maxSwipes) swipes", file: file, line: line)
    }

    /// Extracts the first integer appearing in an element's label.
    func firstInt(in label: String) -> Int? {
        let digits = label.components(separatedBy: CharacterSet.decimalDigits.inverted)
        return digits.compactMap { Int($0) }.first
    }
}
