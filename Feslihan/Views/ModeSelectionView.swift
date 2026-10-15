import SwiftUI
import SwiftData
import ClerkKit
import ClerkKitUI

enum AppMode: String, CaseIterable {
    case mealPrep
    case whatToEat
    case browse
    case pantry
    case shoppingList
}

struct ModeSelectionView: View {
    @State private var selectedMode: AppMode?
    @State private var cardsVisible = false
    @State private var showAddRecipe = false
    @State private var showPaywall = false
    @State private var showMealPrepWizard = false
    @State private var showAccountSheet = false
    @State private var showInboxSheet = false
    @State private var pendingShareCount = 0
    @State private var notificationRecipe: Recipe?
    @State private var pantryCount = 0
    @State private var shoppingCount = 0
    @State private var recipeCount = 0
    @State private var latestPlan: SavedPlanItem?
    @State private var showPantryGate = false
    @State private var pendingMode: AppMode?
    @State private var showOnboarding = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject var subscription: SubscriptionService
    @Environment(\.modelContext) private var modelContext

    private let minPantryCount = 30

    /// Turkish greeting that adapts to the time of day.
    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Günaydın,"
        case 12..<18: return "İyi günler,"
        case 18..<22: return "İyi akşamlar,"
        default: return "İyi geceler,"
        }
    }

    private func goBack() {
        withAnimation(.spring(response: 0.2)) {
            selectedMode = nil
        }
        Task { await refreshPantryCount() }
    }

    private func refreshPantryCount() async {
        guard let userId = Clerk.shared.user?.id else { return }
        let items = await APIService.fetchPantry(userId: userId)
        pantryCount = items.count
        let shoppingItems = await APIService.fetchShoppingList(userId: userId)
        shoppingCount = shoppingItems.filter { !$0.is_checked }.count
        latestPlan = await APIService.fetchMealPlans(userId: userId).first
    }

    private func refreshCounts() async {
        await refreshPantryCount()
        let descriptor = FetchDescriptor<Recipe>()
        recipeCount = (try? modelContext.fetchCount(descriptor)) ?? 0
        await refreshSocialCounts()
    }

    private func refreshSocialCounts() async {
        pendingShareCount = await APIService.fetchSocialMe()?.pending_share_count ?? 0
    }

    private func navigateOrGate(_ mode: AppMode) {
        if pantryCount < minPantryCount {
            pendingMode = mode
            showPantryGate = true
        } else {
            withAnimation(.spring(response: 0.2)) {
                selectedMode = mode
            }
        }
    }

    var body: some View {
        Group {
        if let mode = selectedMode {
            Group {
                switch mode {
                case .browse:
                    ContentView(onBack: goBack)
                case .mealPrep:
                    SavedMealPlansView(
                        onBack: goBack,
                        onCreateNew: {
                            withAnimation(.spring(response: 0.2)) {
                                selectedMode = nil
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.spring(response: 0.2)) {
                                    showMealPrepWizard = true
                                }
                            }
                        }
                    )
                case .whatToEat:
                    WhatToEatView(onBack: goBack)
                case .pantry:
                    PantryView(onBack: goBack)
                case .shoppingList:
                    ShoppingListView(onBack: goBack)
                }
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
        } else {
            ZStack {
                DS.cream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Wordmark + avatar
                        HStack {
                            HStack(spacing: 7) {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(DS.ember)
                                Text("Feslihan")
                                    .font(.system(size: 17, weight: .semibold, design: .serif))
                                    .foregroundStyle(DS.ink)
                            }

                            Spacer()

                            // Inbox: recipes friends sent me, with unread badge
                            Button { showInboxSheet = true } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "tray")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(DS.ink)
                                        .frame(width: 34, height: 34)
                                        .background(DS.sand)
                                        .clipShape(Circle())

                                    if pendingShareCount > 0 {
                                        Text("\(min(pendingShareCount, 9))")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(DS.flour)
                                            .frame(width: 16, height: 16)
                                            .background(DS.tomato)
                                            .clipShape(Circle())
                                            .offset(x: 4, y: -4)
                                    }
                                }
                            }
                            .accessibilityLabel("Benimle Paylaşılanlar")
                            .accessibilityIdentifier("home.inboxButton")
                            .padding(.trailing, 10)

                            Button { showAccountSheet = true } label: {
                                if let url = Clerk.shared.user?.imageUrl,
                                   let imageURL = URL(string: url) {
                                    AsyncImage(url: imageURL) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        avatarPlaceholder
                                    }
                                    .frame(width: 34, height: 34)
                                    .clipShape(Circle())
                                } else {
                                    avatarPlaceholder
                                }
                            }
                            .accessibilityLabel("Hesabım")
                            .accessibilityIdentifier("home.accountButton")
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 8)

                        // Greeting
                        VStack(alignment: .leading, spacing: 6) {
                            Text(greeting)
                                .font(.handwritten())
                                .foregroundStyle(DS.smoke)

                            Text(Clerk.shared.user?.firstName.map { "Merhaba,\n\($0)" } ?? "Merhaba")
                                .font(.system(size: 38, weight: .semibold, design: .serif))
                                .foregroundStyle(DS.ink)
                                .lineSpacing(2)
                        }
                        .accessibilityElement(children: .combine)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22)
                        .padding(.top, 30)
                        .padding(.bottom, 22)

                        // First-run prompt leading the user to add recipes
                        if recipeCount == 0 {
                            AddRecipePrompt { showAddRecipe = true }
                                .padding(.horizontal, 22)
                                .padding(.bottom, 16)
                        }

                        // Editorial mode list
                        VStack(spacing: 0) {
                            Button {
                                if subscription.currentPlan.canMealPrep {
                                    navigateOrGate(.mealPrep)
                                } else {
                                    showPaywall = true
                                }
                            } label: {
                                FeaturedModeCard(plan: latestPlan)
                            }
                            .buttonStyle(.plain)
                            .opacity(cardsVisible ? 1 : 0)
                            .offset(y: cardsVisible ? 0 : 20)
                            .accessibilityIdentifier("home.mode.mealPrep")

                            ModeRow(
                                number: "02",
                                icon: "wand.and.stars",
                                tint: DS.tomato,
                                title: "Ne Yesem?",
                                subtitle: "Sana özel tarif önerileri keşfet"
                            )
                            .opacity(cardsVisible ? 1 : 0)
                            .offset(y: cardsVisible ? 0 : 20)
                            .onTapGesture {
                                navigateOrGate(.whatToEat)
                            }
                            .accessibilityIdentifier("home.mode.whatToEat")

                            ModeRow(
                                number: "03",
                                icon: "book.closed",
                                tint: DS.honeyInk,
                                title: "Tariflerim",
                                subtitle: "Kaydettiğin tüm tarifler"
                            )
                            .opacity(cardsVisible ? 1 : 0)
                            .offset(y: cardsVisible ? 0 : 20)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.2)) {
                                    selectedMode = .browse
                                }
                            }
                            .accessibilityIdentifier("home.mode.browse")

                            // Mutfak section
                            Text("MUTFAK")
                                .font(.eyebrow())
                                .tracking(1.6)
                                .foregroundStyle(DS.dust)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 26)

                            HStack(spacing: 0) {
                                UtilCell(
                                    icon: "cabinet",
                                    title: "Kilerim",
                                    count: "\(pantryCount)",
                                    unit: "malzeme",
                                    tint: DS.eggplant,
                                    first: true
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.2)) {
                                        selectedMode = .pantry
                                    }
                                }
                                .accessibilityIdentifier("home.mode.pantry")

                                Rectangle()
                                    .fill(DS.stone)
                                    .frame(width: 1)

                                UtilCell(
                                    icon: "basket",
                                    title: "Alışveriş",
                                    count: "\(shoppingCount)",
                                    unit: "eksik ürün",
                                    tint: DS.tomato,
                                    first: false
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.2)) {
                                        selectedMode = .shoppingList
                                    }
                                }
                                .accessibilityIdentifier("home.mode.shoppingList")
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 60)
                    }
                }
            }
            .sheet(isPresented: $showAddRecipe) {
                AddRecipeView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .fullScreenCover(isPresented: $showMealPrepWizard) {
                MealPrepView(onBack: { showMealPrepWizard = false })
            }
            .sheet(isPresented: $showInboxSheet, onDismiss: {
                Task { await refreshSocialCounts() }
            }) {
                SharedInboxView(onChange: {
                    Task { await refreshSocialCounts() }
                })
            }
            .sheet(isPresented: $showAccountSheet) {
                AccountSheet(onNavigate: { mode in
                    showAccountSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.spring(response: 0.2)) {
                            selectedMode = mode
                        }
                    }
                })
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.2).delay(0.05)) {
                    cardsVisible = true
                }
                if !hasCompletedOnboarding {
                    showOnboarding = true
                }
                #if DEBUG
                // UI-test hook: the hero card ignores synthesized taps in the
                // simulator, so tests can enter meal prep via launch argument.
                if ProcessInfo.processInfo.arguments.contains("-e2eStartMealPrep") {
                    selectedMode = .mealPrep
                }
                #endif
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(onComplete: {
                    hasCompletedOnboarding = true
                    showOnboarding = false
                    Task { await refreshCounts() }
                })
            }
            .task {
                await refreshPantryCount()
                // Check local first, then backend
                let descriptor = FetchDescriptor<Recipe>()
                recipeCount = (try? modelContext.fetchCount(descriptor)) ?? 0
                if recipeCount == 0, let userId = Clerk.shared.user?.id {
                    let remote = await APIService.fetchUserRecipes(userId: userId)
                    recipeCount = remote.count
                }
                await refreshSocialCounts()
            }
            .fullScreenCover(isPresented: $showPantryGate) {
                PantryGateView(
                    currentCount: pantryCount,
                    minCount: minPantryCount,
                    onDone: {
                        showPantryGate = false
                        Task {
                            await refreshPantryCount()
                            if let mode = pendingMode, pantryCount >= minPantryCount {
                                withAnimation(.spring(response: 0.2)) {
                                    selectedMode = mode
                                }
                            }
                            pendingMode = nil
                        }
                    }
                )
            }
        }
        }
        // Daily-suggestion notification tap → open the suggested recipe.
        .task { openPendingNotificationRecipe() }
        .onReceive(NotificationCenter.default.publisher(for: .feslihanOpenRecipe)) { _ in
            openPendingNotificationRecipe()
        }
        .sheet(item: $notificationRecipe) { recipe in
            NavigationStack { RecipeDetailView(recipe: recipe) }
        }
    }

    /// Fetches and presents the recipe stashed by a notification tap.
    /// Deleted/re-synced recipes just no-op.
    private func openPendingNotificationRecipe() {
        guard let id = NotificationService.shared.consumePendingRecipeId() else { return }
        let descriptor = FetchDescriptor<Recipe>(predicate: #Predicate { $0.id == id })
        guard let recipe = try? modelContext.fetch(descriptor).first else { return }

        // The app may foreground with another sheet up (account, inbox) or a
        // mode open; a second sheet can't present over them, so clear first
        // and present after the dismiss animation settles.
        showAccountSheet = false
        showInboxSheet = false
        withAnimation(.spring(response: 0.2)) { selectedMode = nil }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            notificationRecipe = recipe
        }
    }

    private var avatarPlaceholder: some View {
        Text(String(Clerk.shared.user?.firstName?.prefix(1) ?? "N"))
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(DS.flour)
            .frame(width: 34, height: 34)
            .background(DS.ink)
            .clipShape(Circle())
    }
}

// MARK: - Plus Badge (outlined basil crown tag)

struct PlusBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown")
                .font(.system(size: 10, weight: .medium))
            Text("PLUS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
        }
        .foregroundStyle(DS.ember)
        .padding(.horizontal, 7)
        .frame(height: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(DS.ember, lineWidth: 1)
        )
    }
}

// MARK: - Featured Mode (Haftalık Plan hero block)

private struct FeaturedModeCard: View {
    /// The user's most recent saved plan; nil while loading or when none exist.
    let plan: SavedPlanItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [Color(hex: 0x36A15E), Color(hex: 0x1E7A42)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 148)
                .clipShape(RoundedRectangle(cornerRadius: DS.radius))

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("01")
                            .font(.system(size: 12, weight: .regular))
                            .monospacedDigit()
                            .foregroundStyle(.white)

                        Spacer()

                        Image(systemName: "calendar")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                    }

                    Spacer(minLength: 0)

                    if let plan {
                        Text("SON PLANIN · \(plan.timeAgo.uppercased())")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.75))

                        Text(plan.name)
                            .font(.system(size: 21, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.top, 3)

                        Text(summary(for: plan))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.top, 2)
                    } else {
                        Text("BU HAFTA")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.75))

                        Text("Ne pişireceğini planla")
                            .font(.system(size: 21, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                            .padding(.top, 3)

                        Text("Yapay zekâ ile 1 dakikada haftalık plan →")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.top, 2)
                    }
                }
                .padding(14)
            }

            HStack(spacing: 10) {
                Text("Haftalık Plan")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(DS.ink)

                PlusBadge()
            }
            .padding(.top, 14)

            Text(plan == nil
                 ? "Bir haftalık yemek planı hazırla"
                 : "Planını görüntüle veya yenisini hazırla")
                .font(.system(size: 14))
                .foregroundStyle(DS.smoke)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 18)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DS.stone).frame(height: 1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private func summary(for plan: SavedPlanItem) -> String {
        var parts: [String] = []
        if let days = plan.plan.days?.count, days > 0 { parts.append("\(days) gün") }
        if plan.totalMeals > 0 { parts.append("\(plan.totalMeals) öğün") }
        if plan.avgCalories > 0 { parts.append("~\(plan.avgCalories) kcal/gün") }
        return parts.isEmpty ? "Dokun ve planını aç" : parts.joined(separator: " · ")
    }
}

// MARK: - Add Recipe Prompt (first-run empty state)

private struct AddRecipePrompt: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(DS.ember)

                VStack(alignment: .leading, spacing: 3) {
                    Text("İlk tarifini ekle")
                        .font(.cardTitle())
                        .foregroundStyle(DS.ink)

                    Text("Defterin henüz boş — hadi başlayalım!")
                        .font(.label())
                        .foregroundStyle(DS.smoke)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.dust)
            }
            .padding(16)
            .background(DS.emberLight)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(DS.ember.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Util Cell (hairline-divided Mutfak stats)

private struct UtilCell: View {
    let icon: String
    let title: String
    let count: String
    let unit: String
    let tint: Color
    let first: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DS.ink)

                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(tint)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(count)
                    .font(.system(size: 32, weight: .medium, design: .serif))
                    .foregroundStyle(tint)
                Text(unit)
                    .font(.captionText())
                    .foregroundStyle(DS.dust)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 4)
        .padding(.leading, first ? 0 : 16)
        .padding(.trailing, first ? 16 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Account Sheet

private struct AccountSheet: View {
    let onNavigate: (AppMode) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Profile header
                VStack(spacing: 12) {
                    if let url = Clerk.shared.user?.imageUrl,
                       let imageURL = URL(string: url) {
                        AsyncImage(url: imageURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(DS.dust)
                        }
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(DS.dust)
                    }

                    if let name = Clerk.shared.user?.firstName {
                        Text(name)
                            .font(.displayTitle())
                            .foregroundStyle(DS.ink)
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 20)

                // Menu items
                VStack(spacing: 2) {
                    AccountRow(icon: "refrigerator", title: "Kilerim", subtitle: "Evindeki malzemeleri yönet") {
                        onNavigate(.pantry)
                    }

                    AccountRow(icon: "cart", title: "Alışveriş Listesi", subtitle: "Alması gerekenleri listele") {
                        onNavigate(.shoppingList)
                    }

                    NavigationLink {
                        FriendsView()
                    } label: {
                        AccountRowLabel(icon: "person.2", title: "Arkadaşlar", subtitle: "Arkadaş ekle, tarif paylaş")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("account.friendsRow")

                    NavigationLink {
                        SettingsView()
                    } label: {
                        AccountRowLabel(icon: "gearshape", title: "Ayarlar", subtitle: "Hesap ve uygulama ayarları")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)

                Spacer()

                // Clerk account management (manage account, security, sign out)
                UserButton()
                    .padding(.bottom, 32)
            }
            .background(DS.cream)
            .navigationTitle("Hesabım")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DS.ink)
                    }
                }
            }
        }
    }
}

private struct AccountRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            AccountRowLabel(icon: icon, title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)
    }
}

private struct AccountRowLabel: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(DS.ember)
                .frame(width: 44, height: 44)
                .background(DS.emberLight)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.sectionHeader())
                    .foregroundStyle(DS.ink)

                Text(subtitle)
                    .font(.label())
                    .foregroundStyle(DS.smoke)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.dust)
        }
        .padding(14)
        .background(DS.sand)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Mode Row (numbered editorial list row)

private struct ModeRow: View {
    let number: String
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.system(size: 12, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(DS.dust)
                .frame(width: 20, alignment: .leading)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(DS.ink)

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(DS.smoke)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: icon)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(tint)
                .padding(.top, 4)
        }
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DS.stone).frame(height: 1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
