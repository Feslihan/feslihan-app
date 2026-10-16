import SwiftUI
import SwiftData
import ClerkKit
import UserNotifications

/// Receives the APNs device-token callbacks (UIApplicationDelegate-only API)
/// and forwards the token to the backend for server→device push.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        Task {
            _ = await APIService.registerDevice(token: token, environment: environment)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[Push] remote registration failed: \(error.localizedDescription)")
    }
}

@main
struct FeslihanApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var clerk: Clerk

    init() {
        let c = Clerk.configure(publishableKey: "pk_test_d2FudGVkLWxpZ2VyLTQ3LmNsZXJrLmFjY291bnRzLmRldiQ")
        _clerk = State(initialValue: c)
        SubscriptionService.shared.configure()
        // Local-notification taps (daily meal suggestions) are handled here.
        UNUserNotificationCenter.current().delegate = NotificationService.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(clerk)
                .environmentObject(SubscriptionService.shared)
        }
        .modelContainer(for: Recipe.self)
    }
}
