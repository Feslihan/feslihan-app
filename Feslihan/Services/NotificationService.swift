import Foundation
import UserNotifications
import SwiftData
import ClerkKit

extension Notification.Name {
    /// Posted when the user taps a daily-suggestion notification while the
    /// app is running; ModeSelectionView listens and opens the recipe.
    static let feslihanOpenRecipe = Notification.Name("feslihanOpenRecipe")
}

/// Schedules the daily "Yarın ne pişirsem?" local notifications: the next 7
/// days are planned and (re)scheduled every launch while the feature is on.
/// Pure client-side — no APNs, no backend.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    // MARK: - Keys & constants

    static let enabledKey = "dailySuggestionEnabled"
    /// Minutes after midnight; 1200 = 20:00.
    static let minutesKey = "dailySuggestionMinutes"
    static let defaultMinutes = 20 * 60
    private static let historyKey = "dailySuggestionHistory"
    static let pendingRecipeKey = "pendingNotificationRecipeId"
    private static let idPrefix = "feslihan.dailySuggestion."
    private static let historyDays = 14

    private let defaults = UserDefaults.standard

    var isEnabled: Bool { defaults.bool(forKey: Self.enabledKey) }

    var fireMinutes: Int {
        let stored = defaults.integer(forKey: Self.minutesKey)
        return stored > 0 ? stored : Self.defaultMinutes
    }

    // MARK: - Permission

    func requestAuthorization() async -> Bool {
        let granted = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
        return granted ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: - Scheduling

    /// Launch entry point: refresh the 7-day window if the feature is on.
    @MainActor
    func refreshIfEnabled(context: ModelContext) async {
        guard isEnabled else { return }

        let recipes = (try? context.fetch(FetchDescriptor<Recipe>())) ?? []
        guard !recipes.isEmpty else { return }

        // Pantry is a nice-to-have ranking signal — offline just means
        // coverage scores of 0, suggestions still get scheduled.
        var pantryNames: Set<String> = []
        if let userId = Clerk.shared.user?.id {
            pantryNames = Set(await APIService.fetchPantry(userId: userId).map(\.ingredient_name))
        }

        let candidates = recipes.map { recipe in
            RecipeCandidate(
                id: recipe.id,
                title: recipe.title,
                isFavorite: recipe.isFavorite,
                cuisine: recipe.cuisine,
                tags: recipe.tags,
                cookingTimeMinutes: recipe.cookingTimeMinutes,
                ingredientBaseNames: recipe.ingredients.map { $0.baseName ?? $0.name }
            )
        }
        await rescheduleAll(candidates: candidates, pantryNames: pantryNames)
    }

    func rescheduleAll(candidates: [RecipeCandidate], pantryNames: Set<String>) async {
        let calendar = Calendar.current
        let center = UNUserNotificationCenter.current()

        guard let startDate = calendar.date(
            byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())
        ) else { return }

        let history = prunedHistory(calendar: calendar)
        let recentIds = Set(history.values.compactMap(UUID.init))

        let plan = MealSuggestionPlanner.plan(
            candidates: candidates,
            pantryNames: pantryNames,
            recentIds: recentIds,
            startDate: startDate,
            days: 7,
            calendar: calendar
        )
        guard !plan.isEmpty else { return }

        // Replace the existing window: stable per-date identifiers make this
        // idempotent across launches.
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(Self.idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        let hour = fireMinutes / 60
        let minute = fireMinutes % 60
        var newHistory = history

        for suggestion in plan {
            let content = UNMutableNotificationContent()
            content.title = suggestion.title
            content.body = suggestion.body
            content.sound = .default
            content.userInfo = ["recipeId": suggestion.recipeId.uuidString]

            let dateKey = Self.dateKey(for: suggestion.date, calendar: calendar)
            let trigger = Self.trigger(for: suggestion, hour: hour, minute: minute, calendar: calendar)
            try? await center.add(UNNotificationRequest(
                identifier: Self.idPrefix + dateKey,
                content: content,
                trigger: trigger
            ))
            newHistory[dateKey] = suggestion.recipeId.uuidString
        }

        defaults.set(newHistory, forKey: Self.historyKey)
        #if DEBUG
        print("[Notifications] Scheduled \(plan.count) daily suggestions at \(hour):\(String(format: "%02d", minute))")
        #endif
    }

    func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(Self.idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Delegate (foreground display + tap handling)

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let recipeId = response.notification.request.content.userInfo["recipeId"] as? String else { return }
        defaults.set(recipeId, forKey: Self.pendingRecipeKey)
        // Delay the in-app signal until the background→foreground transition
        // settles: mutating UI state mid-transition trips UIKit's snapshot
        // assertion (SIGABRT in _updateStateRestorationArchiveForBackgroundEvent).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            NotificationCenter.default.post(name: .feslihanOpenRecipe, object: nil)
        }
    }

    /// Reads and clears the recipe id stashed by a notification tap.
    func consumePendingRecipeId() -> UUID? {
        guard let stored = defaults.string(forKey: Self.pendingRecipeKey) else { return nil }
        defaults.removeObject(forKey: Self.pendingRecipeKey)
        return UUID(uuidString: stored)
    }

    // MARK: - Helpers

    private static func trigger(
        for suggestion: DailySuggestion,
        hour: Int, minute: Int,
        calendar: Calendar
    ) -> UNNotificationTrigger {
        #if DEBUG
        // UI-test / manual-verification hook: fire the first suggestion ~30s
        // after scheduling instead of waiting for 20:00 tomorrow.
        if ProcessInfo.processInfo.arguments.contains("-notifTestFireSoon"),
           calendar.isDate(suggestion.date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: Date()) ?? suggestion.date) {
            return UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)
        }
        #endif
        var components = calendar.dateComponents([.year, .month, .day], from: suggestion.date)
        components.hour = hour
        components.minute = minute
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    private static func dateKey(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// History from the last 14 days, dropping older entries.
    private func prunedHistory(calendar: Calendar) -> [String: String] {
        let stored = defaults.dictionary(forKey: Self.historyKey) as? [String: String] ?? [:]
        guard let cutoff = calendar.date(byAdding: .day, value: -Self.historyDays, to: Date()) else { return stored }
        let cutoffKey = Self.dateKey(for: cutoff, calendar: calendar)
        // Keys are zero-padded ISO dates, so string comparison is date order.
        return stored.filter { $0.key >= cutoffKey }
    }
}
