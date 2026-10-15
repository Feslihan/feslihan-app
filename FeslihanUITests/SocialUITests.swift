import XCTest

/// Social features: share inbox, friend code, friend lookup.
final class SocialUITests: FeslihanUITestCase {
    private func snap(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Home header shows the inbox tray; opening it shows the empty state.
    func testShareInboxEmptyState() throws {
        ensureSignedInAtHome()
        snap("01-home-with-inbox-icon")

        tap(id: "home.inboxButton", fallbackLabel: "Benimle Paylaşılanlar")
        assertExists(app.staticTexts["Paylaşılan tarif yok"], timeout: 15,
                     "Share inbox empty state did not appear")
        snap("02-inbox-empty")
    }

    /// Friends screen: the backend generates a FES- friend code, and looking
    /// up our own email resolves to the "Bu sensin" (self) state.
    func testFriendCodeAndSelfLookup() throws {
        ensureSignedInAtHome()

        tap(id: "home.accountButton", fallbackLabel: "Hesabım")
        tap(id: "account.friendsRow", fallbackLabel: "Arkadaşlar")

        // The code loads async from GET /social/me (and is generated into the
        // DB on first visit) — wait for the FES- prefix to replace "•••••••".
        let codeLabel = byId("friends.codeLabel")
        assertExists(codeLabel, timeout: 15, "Friend code label did not appear")
        let hasCode = NSPredicate(format: "label CONTAINS 'FES-'")
        let loaded = XCTNSPredicateExpectation(predicate: hasCode, object: codeLabel)
        XCTAssertEqual(XCTWaiter().wait(for: [loaded], timeout: 20), .completed,
                       "Friend code never loaded (label: '\(codeLabel.label)')")
        snap("03-friends-code")

        // Look up our own account by email → relationship "self".
        let field = app.textFields["friends.searchField"]
        assertExists(field, timeout: 10, "Friend search field missing")
        field.tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 5)
        app.typeText(TestEnv.email)
        tap(id: "friends.lookupButton")

        assertExists(app.staticTexts["Bu sensin"], timeout: 15,
                     "Self-lookup did not resolve to 'Bu sensin'")
        snap("04-friends-self-lookup")
    }

    /// Recipe detail shows the public "Yorumlar" board and the send button.
    func testRecipeDetailHasReviewsBoardAndSendButton() throws {
        ensureSignedInAtHome()
        openMode(id: "home.mode.browse", fallbackLabel: "Tariflerim")
        assertExists(app.staticTexts["Tüm Tarifler"], timeout: 20, "Recipe list did not load")
        openRecipeDetail(title: "Mercimek Çorbası")

        // Send button appears once the backend recipe id resolves.
        let send = byId("detail.sendButton")
        assertExists(send, timeout: 15, "Send (paperplane) button missing on detail")

        // Scroll to the public reviews board.
        let reviewsHeader = app.staticTexts["Yorumlar"]
        scrollTo(reviewsHeader)
        snap("05-detail-reviews-board")
    }
}
