import XCTest

/// Günlük yemek önerisi bildirimi: ayarlardan açma, iOS izin diyaloğu,
/// bildirimin yanması (DEBUG -notifTestFireSoon ile ~30 sn) ve bildirime
/// dokununca tarif detayının açılması.
final class A15_NotificationSettingsTests: FeslihanUITestCase {

    func testEnableFireAndTapOpensRecipe() throws {
        // Relaunch with the DEBUG hook so tomorrow's notification fires ~30s
        // after scheduling instead of at 20:00.
        app.terminate()
        app.launchArguments.append("-notifTestFireSoon")
        app.launch()
        ensureSignedInAtHome()

        // Visit Tariflerim first: on a fresh install the local SwiftData
        // store is empty until the list syncs from the backend, and the
        // scheduler needs local recipes to plan from.
        openMode(id: "home.mode.browse", fallbackLabel: "Tariflerim")
        assertExists(app.staticTexts["Tüm Tarifler"], timeout: 20, "Recipe list did not load")
        XCTAssertTrue(app.staticTexts["Mercimek Çorbası"].waitForExistence(timeout: 30),
                      "Recipes did not sync into the local store")
        goBackHome()

        // Home → account sheet → Ayarlar
        tap(id: "home.accountButton", fallbackLabel: "Hesabım")
        let settingsRow = app.staticTexts["Ayarlar"]
        assertExists(settingsRow, timeout: 10, "Ayarlar row missing in account sheet")
        settingsRow.tap()

        // Toggle the feature on; expect the iOS permission alert (springboard).
        let toggle = app.switches.firstMatch
        assertExists(toggle, timeout: 10, "Notification toggle missing in Ayarlar")
        toggle.tap()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"].exists
            ? springboard.buttons["Allow"]
            : springboard.buttons["İzin Ver"]
        if allow.waitForExistence(timeout: 6) {
            allow.tap()
        }

        // Time row appears once enabled (scheduling happened in onChange).
        XCTAssertTrue(byId("settings.notificationsTimePicker").waitForExistence(timeout: 10),
                      "Time picker row did not appear after enabling")
        snap("01-settings-notifications-on")

        // Background the app; the fire-soon trigger lands within ~40s.
        XCUIDevice.shared.press(.home)
        // Banners surface as a custom BannerNotification element type —
        // query by identifier across all types, not otherElements.
        let banner = springboard.descendants(matching: .any)
            .matching(identifier: "NotificationShortLookView").firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 60),
                      "Daily suggestion banner did not appear on springboard")
        snapSpringboard(springboard, "02-notification-banner")

        // Tap the banner → app foregrounds → recipe detail sheet opens.
        banner.tap()
        XCTAssertTrue(app.buttons["Malzemeler"].waitForExistence(timeout: 20),
                      "Recipe detail did not open from the notification tap")
        snap("03-recipe-from-notification")
    }

    private func snap(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func snapSpringboard(_ springboard: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: springboard.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
