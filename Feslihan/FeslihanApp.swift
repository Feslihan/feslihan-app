import SwiftUI
import SwiftData
import ClerkKit
import UserNotifications

@main
struct FeslihanApp: App {
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
