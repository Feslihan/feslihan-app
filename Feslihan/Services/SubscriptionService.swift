import Foundation
import RevenueCat

enum FeslihanPlan: String, CaseIterable {
    case free      // 3 new-to-catalog AI scans/month; cached saves unlimited
    case plus      // ₺79/ay — 20 scans + 2 meal plans/month
    case pro       // ₺250/ay — unlimited scans + unlimited meal plans

    // Monthly allowance of NEW-to-catalog AI scans. Saving a recipe that is
    // already in the catalog (cache hit) is free and never counts. Mirrors
    // PLAN_LIMITS in feslihan-backend/src/quota.ts — the server enforces;
    // this copy only drives UI.
    var monthlyRecipeLimit: Int? {
        switch self {
        case .free: return 3
        case .plus: return 20
        case .pro: return nil // unlimited
        }
    }

    // Monthly allowance of AI meal plan generations. Mirrors MEAL_PLAN_LIMITS
    // in feslihan-backend/src/quota.ts — the server enforces; UI only.
    var monthlyMealPlanLimit: Int? {
        switch self {
        case .free: return 0
        case .plus: return 2
        case .pro: return nil // unlimited
        }
    }

    var canMealPrep: Bool {
        self != .free
    }

    var displayName: String {
        switch self {
        case .free: return "Ücretsiz"
        case .plus: return "Feslihan+"
        case .pro: return "Feslihan Pro"
        }
    }
}

@MainActor
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    // TODO: Change back to .free when RevenueCat is fully set up
    @Published var currentPlan: FeslihanPlan = .pro
    @Published var recipesUsedThisMonth: Int = 0

    /// Becomes `true` once auth/subscription load has settled for the current
    /// session. The splash screen waits on this instead of a fixed delay.
    @Published var isReady = false

    // RevenueCat entitlement identifiers — set these in RevenueCat dashboard
    private let proEntitlement = "feslihan_pro"
    private let plusEntitlement = "feslihan_plus"

    // Usage tracking
    private let usageKey = "feslihan_recipes_used"
    private let usageMonthKey = "feslihan_usage_month"

    private init() {
        loadUsage()
    }

    func configure() {
        Purchases.configure(
            with: .builder(withAPIKey: "appl_GjwqfROjEjlzHCgtNZxwdzawSfT")
                .build()
        )
    }

    func setUser(_ userId: String) {
        Purchases.shared.logIn(userId) { _, _, _ in }
    }

    /// Restore previously purchased subscriptions and refresh the active plan.
    /// Returns `true` if the restore completed without error.
    @discardableResult
    func restorePurchases() async -> Bool {
        do {
            let info = try await Purchases.shared.restorePurchases()
            if info.entitlements[proEntitlement]?.isActive == true {
                currentPlan = .pro
            } else if info.entitlements[plusEntitlement]?.isActive == true {
                currentPlan = .plus
            } else {
                currentPlan = .free
            }
            return true
        } catch {
            return false
        }
    }

    func refreshStatus() async {
        // TODO: Remove this when RevenueCat products are live
        // Skip RevenueCat check until products are configured
        // (DEBUG = Xcode, TestFlight = no App Store receipt)
        #if DEBUG
        return
        #else
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return
        }
        #endif
        do {
            let info = try await Purchases.shared.customerInfo()
            if info.entitlements[proEntitlement]?.isActive == true {
                currentPlan = .pro
            } else if info.entitlements[plusEntitlement]?.isActive == true {
                currentPlan = .plus
            } else {
                currentPlan = .free
            }
        } catch {
            // Status refresh failed — keep the current plan.
        }
    }

    // MARK: - Quota

    var canAddRecipe: Bool {
        guard let limit = currentPlan.monthlyRecipeLimit else { return true }
        return recipesUsedThisMonth < limit
    }

    var remainingRecipes: Int? {
        guard let limit = currentPlan.monthlyRecipeLimit else { return nil }
        return max(0, limit - recipesUsedThisMonth)
    }

    func recordRecipeAdded() {
        recipesUsedThisMonth += 1
        saveUsage()
    }

    private func loadUsage() {
        let currentMonth = monthKey()
        let savedMonth = UserDefaults.standard.string(forKey: usageMonthKey)
        if savedMonth == currentMonth {
            recipesUsedThisMonth = UserDefaults.standard.integer(forKey: usageKey)
        } else {
            // New month — reset counter
            recipesUsedThisMonth = 0
            saveUsage()
        }
    }

    private func saveUsage() {
        UserDefaults.standard.set(recipesUsedThisMonth, forKey: usageKey)
        UserDefaults.standard.set(monthKey(), forKey: usageMonthKey)
    }

    private func monthKey() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM"
        return df.string(from: Date())
    }
}
