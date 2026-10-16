import SwiftUI
import SwiftData
import ClerkKit

struct AddRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var subscription: SubscriptionService
    @State private var showPaywall = false

    @State private var urlText = ""
    @State private var fetchedCaption: String?
    @State private var captionError: String?
    @State private var isFetchingCaption = false
    @State private var processingState: ProcessingState = .idle
    @State private var processedRecipe: ProcessedRecipe?
    @State private var errorMessage: String?
    /// True when the recipe came from the catalog (no AI call, no credit).
    @State private var wasCached = false
    /// Scan credits left this month per the server; nil = unknown or unlimited.
    @State private var quotaRemaining: Int?

    enum ProcessingState {
        case idle
        /// New-to-catalog link: ask before spending a scan credit.
        case confirmScan
        case fetchingCaption
        case analyzingRecipe
        case done
        case error
    }

    private var canProcess: Bool {
        !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                switch processingState {
                case .idle:
                    idleView
                case .confirmScan:
                    confirmScanView
                case .fetchingCaption, .analyzingRecipe:
                    processingView
                case .done:
                    if let recipe = processedRecipe {
                        resultView(recipe)
                    }
                case .error:
                    errorView
                }
            }
            .navigationTitle("Yeni Tarif")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DS.ink)
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(contextMessage: "Bu ay ücretsiz tarama hakkın doldu. Hazır tarifleri eklemek her zaman ücretsiz — bu tarif ise Feslihan için yeni.")
            }
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        ZStack {
            DS.cream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tarif Ekle")
                            .font(.system(size: 26, weight: .semibold, design: .serif))
                            .foregroundStyle(DS.ink)

                        Text("Bir video veya tarif linki yapıştır, tarifi senin için çıkaralım.")
                            .font(.bodyText())
                            .foregroundStyle(DS.smoke)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // URL input + paste button
                    HStack(spacing: 8) {
                        TextField("Link yapıştır…", text: $urlText)
                            .accessibilityIdentifier("addRecipe.urlField")
                            .textContentType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.bodyText())
                            .padding(.horizontal, 14)
                            .frame(height: 46)
                            .background(DS.cream)
                            .clipShape(RoundedRectangle(cornerRadius: DS.radius))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.radius)
                                    .stroke(DS.stone, lineWidth: 1)
                            )

                        Button {
                            if let clip = UIPasteboard.general.string {
                                urlText = clip
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 14))
                                Text("Yapıştır")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(DS.ink)
                            .padding(.horizontal, 16)
                            .frame(height: 46)
                            .background(DS.cream)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.radius)
                                    .stroke(DS.ink, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: DS.radius))
                        }
                    }
                    .padding(.horizontal, 20)

                    // Platform icons
                    HStack(spacing: 10) {
                        Text("Desteklenen:")
                            .font(.captionText())
                            .foregroundStyle(DS.dust)

                        ForEach(["♪", "◎", "𝕏"], id: \.self) { glyph in
                            Text(glyph)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(DS.smoke)
                                .frame(width: 36, height: 36)
                                .background(DS.sand)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        Image(systemName: "fork.knife")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DS.smoke)
                            .frame(width: 36, height: 36)
                            .background(DS.sand)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.horizontal, 20)

                    Button(action: processAll) {
                        Text("Tarif Ekle")
                            .font(.buttonFont())
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(canProcess ? DS.ember : DS.sand)
                            .foregroundStyle(canProcess ? DS.flour : DS.dust)
                            .clipShape(RoundedRectangle(cornerRadius: DS.radius))
                    }
                    .accessibilityIdentifier("addRecipe.submitButton")
                    .disabled(!canProcess)
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Confirm Scan View

    /// Shown when the link is new to the catalog: scanning it runs AI and
    /// spends one of the month's scan credits, so ask before starting.
    private var confirmScanView: some View {
        ZStack {
            DS.cream.ignoresSafeArea()

            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tarif Ekle")
                        .font(.system(size: 26, weight: .semibold, design: .serif))
                        .foregroundStyle(DS.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 14) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(DS.ember)

                    Text("Yeni bir tarif!")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .foregroundStyle(DS.ink)

                    Text("Bunu Feslihan'a ilk sen ekliyorsun. Taramak 1 tarama hakkı kullanacak.")
                        .font(.bodyText())
                        .foregroundStyle(DS.smoke)
                        .multilineTextAlignment(.center)

                    if let remaining = quotaRemaining {
                        Text("Bu ay \(remaining) tarama hakkın kaldı")
                            .font(.captionText())
                            .foregroundStyle(DS.dust)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 16)
                .background(DS.emberLight)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.radius)
                        .stroke(DS.stone, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.radius))

                Spacer()

                Button(action: startScan) {
                    Text("Tara ve Ekle")
                        .font(.buttonFont())
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(DS.ember)
                        .foregroundStyle(DS.flour)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radius))
                }
                .accessibilityIdentifier("addRecipe.confirmScanButton")

                Button {
                    processingState = .idle
                } label: {
                    Text("Vazgeç")
                        .font(.buttonFont())
                        .foregroundStyle(DS.smoke)
                }
                .accessibilityIdentifier("addRecipe.cancelScanButton")
            }
            .padding(20)
        }
    }

    // MARK: - Processing View

    private var processingView: some View {
        ZStack {
            DS.cream.ignoresSafeArea()

            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tarif Ekle")
                        .font(.system(size: 26, weight: .semibold, design: .serif))
                        .foregroundStyle(DS.ink)

                    Text(isWebRecipe
                        ? "Tarif sitesinden bilgiler çıkartılıyor…"
                        : "Bir video linki yapıştır, tarifi senin için çıkaralım.")
                        .font(.bodyText())
                        .foregroundStyle(DS.smoke)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Processing checklist card
                VStack(spacing: 0) {
                    if isWebRecipe {
                        checklistRow("Tarif bilgileri", state: checkState(for: .fetchingCaption))
                        Divider().background(DS.stone)
                        checklistRow("Besin değerleri", state: checkState(for: .analyzingRecipe))
                    } else {
                        checklistRow("Video bilgileri", state: checkState(for: .fetchingCaption))
                        Divider().background(DS.stone)
                        checklistRow("Tarif analizi", state: checkState(for: .analyzingRecipe))
                    }
                }
                .background(DS.cream)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.radius)
                        .stroke(DS.stone, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.radius))

                Text("Bir dakika sürmez, ocağı yakmaya hazırlan…")
                    .font(.handwritten())
                    .foregroundStyle(DS.smoke)
                    .padding(.top, 8)

                Spacer()

                Button {} label: {
                    Text("İşleniyor…")
                        .font(.buttonFont())
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(DS.sand)
                        .foregroundStyle(DS.dust)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radius))
                }
                .disabled(true)
            }
            .padding(20)
        }
    }

    private enum CheckState { case done, active, waiting }

    private func checkState(for step: ProcessingState) -> CheckState {
        let order: [ProcessingState] = [.fetchingCaption, .analyzingRecipe]
        guard let targetIdx = order.firstIndex(of: step),
              let currentIdx = order.firstIndex(of: processingState) else { return .waiting }
        if targetIdx < currentIdx { return .done }
        if targetIdx == currentIdx { return .active }
        return .waiting
    }

    @ViewBuilder
    private func checklistRow(_ label: String, state: CheckState) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(state == .done ? DS.ember : state == .active ? DS.emberLight : DS.sand)
                    .frame(width: 26, height: 26)

                if state == .done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.flour)
                } else if state == .active {
                    Circle()
                        .fill(DS.ember)
                        .frame(width: 9, height: 9)
                }
            }

            Text(label)
                .font(.bodyText())
                .foregroundStyle(state == .waiting ? DS.dust : DS.ink)
                .fontWeight(state == .active ? .semibold : .regular)

            Spacer()

            if state == .done {
                Text("tamam")
                    .font(.captionText())
                    .foregroundStyle(DS.ember)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
    }

    // MARK: - Result View

    private func resultView(_ recipe: ProcessedRecipe) -> some View {
        ZStack {
            DS.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: wasCached ? "checkmark.circle.fill" : "leaf.fill")
                            .font(.system(size: 15, weight: .semibold))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(wasCached ? "Bu tarif Feslihan'da hazır!" : "Bunu Feslihan'a ilk sen ekledin")
                                .font(.system(size: 14, weight: .semibold))
                            if wasCached {
                                Text("Anında eklendi — tarama hakkından düşülmedi.")
                                    .font(.captionText())
                            }
                        }
                    }
                    .foregroundStyle(DS.ember)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(DS.emberLight)
                    .clipShape(RoundedRectangle(cornerRadius: DS.radius))

                    Text(recipe.title)
                        .font(.displayTitle())
                        .foregroundStyle(DS.ink)

                    Rectangle()
                        .fill(DS.stone)
                        .frame(height: 1)

                    Text("Malzemeler")
                        .font(.sectionHeader())
                        .foregroundStyle(DS.ink)

                    IngredientsView(ingredients: recipe.ingredients)

                    Rectangle()
                        .fill(DS.stone)
                        .frame(height: 1)

                    Text("Yapılış")
                        .font(.sectionHeader())
                        .foregroundStyle(DS.ink)

                    Text(recipe.instructions)
                        .font(.bodyText())
                        .foregroundStyle(DS.ink)
                        .lineSpacing(4)

                    Button(action: saveRecipe) {
                        Text("Tarifi Kaydet")
                            .font(.buttonFont())
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(DS.ember)
                            .foregroundStyle(DS.cream)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityIdentifier("addRecipe.saveButton")
                    .padding(.top, 8)
                }
                .padding()
            }
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        ZStack {
            DS.cream.ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(DS.ember)
                Text("Hata")
                    .font(.displayTitle())
                    .foregroundStyle(DS.ink)
                Text(errorMessage ?? "Bilinmeyen bir hata oluştu")
                    .font(.bodyText())
                    .foregroundStyle(DS.smoke)
                    .multilineTextAlignment(.center)
                Button("Tekrar Dene") {
                    processingState = .idle
                    errorMessage = nil
                }
                .font(.buttonFont())
                .foregroundStyle(DS.ember)
                .padding(.top)
                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func fetchCaption() {
        let url = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }

        isFetchingCaption = true
        captionError = nil
        fetchedCaption = nil
        Task {
            do {
                let result = try await CaptionService.fetchCaption(from: url)
                fetchedCaption = result.caption
            } catch {
                captionError = "Açıklama alınamadı. Link'i kontrol edin."
            }
            isFetchingCaption = false
        }
    }

    private var trimmedURL: String {
        let raw = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip tracking/sharing query params (igsh, utm_, etc.)
        guard var components = URLComponents(string: raw) else { return raw }
        components.queryItems = nil
        components.fragment = nil
        return components.url?.absoluteString ?? raw
    }

    private func detectPlatform() -> String {
        let host = URL(string: trimmedURL)?.host?.lowercased() ?? ""
        if host.contains("instagram") { return "instagram" }
        if host.contains("tiktok") { return "tiktok" }
        if host.contains("twitter") || host.contains("x.com") { return "x" }
        if host.contains("nefisyemektarifleri") { return "nefisyemektarifleri" }
        return "other"
    }

    private var isWebRecipe: Bool {
        detectPlatform() == "nefisyemektarifleri"
    }

    /// Validate the pasted link is a well-formed http(s) URL on a supported host.
    /// Returns a Turkish error message if invalid, or nil if the link is OK.
    private func urlValidationError() -> String? {
        let raw = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: raw),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host, !host.isEmpty else {
            return "Geçerli bir bağlantı yapıştırın (https://…)."
        }
        guard detectPlatform() != "other" else {
            return "Bu platform desteklenmiyor. Instagram, TikTok, X veya nefisyemektarifleri bağlantısı yapıştırın."
        }
        return nil
    }

    private func processAll() {
        guard canProcess else { return }

        if let message = urlValidationError() {
            errorMessage = message
            processingState = .error
            return
        }

        Task {
            processingState = .analyzingRecipe
            wasCached = false

            // Catalog check first: a known URL is added instantly, free, and
            // without touching the scan quota.
            if let cached = await APIService.lookup(url: trimmedURL) {
                var dto = cached
                dto.user_id = Clerk.shared.user?.id
                _ = await APIService.save(recipe: dto)

                processedRecipe = cached.toProcessedRecipe()
                wasCached = true
                processingState = .done
                return
            }

            // New-to-catalog: this will spend a scan credit, so check the
            // server quota and ask the user before starting.
            if let status = await APIService.quotaStatus() {
                quotaRemaining = status.remaining
                if let remaining = status.remaining, remaining <= 0 {
                    showPaywall = true
                    processingState = .idle
                    return
                }
            } else {
                // Quota endpoint unreachable — fall back to the local counter.
                quotaRemaining = subscription.remainingRecipes
                if !subscription.canAddRecipe {
                    showPaywall = true
                    processingState = .idle
                    return
                }
            }

            processingState = .confirmScan
        }
    }

    /// Runs the actual AI scan after the user confirmed spending a credit.
    private func startScan() {
        Task {
            do {
                if isWebRecipe {
                    try await processWebRecipe()
                } else {
                    try await processVideoRecipe()
                }

                // Cache hits (race: someone scanned it first) are free.
                if !wasCached {
                    subscription.recordRecipeAdded()
                }
                processingState = .done
            } catch FeslihanError.quotaExceeded {
                // Server-side quota is the source of truth (402).
                showPaywall = true
                processingState = .idle
            } catch {
                errorMessage = error.localizedDescription
                processingState = .error
            }
        }
    }

    private func processWebRecipe() async throws {
        processingState = .fetchingCaption
        let scrapeResult = try await APIService.scrapeWebRecipe(url: trimmedURL)

        // Someone scanned this URL between our lookup and now — the backend
        // returned the catalog copy (already mapped to us) at no cost.
        if case .cached(let dto) = scrapeResult {
            processedRecipe = dto.toProcessedRecipe()
            wasCached = true
            return
        }
        guard case .scraped(let scraped) = scrapeResult else {
            throw FeslihanError.recipeParseFailed
        }

        processingState = .analyzingRecipe

        // Download thumbnail if URL provided
        var thumbnailBase64: String?
        if let thumbURL = scraped.thumbnail_url {
            let thumbData = await CaptionService.downloadImage(from: thumbURL)
            thumbnailBase64 = thumbData?.base64EncodedString()
        }

        let dto = RecipeDTO(
            platform: "nefisyemektarifleri",
            platform_user: scraped.platform_user,
            url: trimmedURL,
            likes_count: 0,
            comments_count: 0,
            caption: nil,
            title: scraped.title,
            description: scraped.instructions,
            ingredients_with_measures: scraped.ingredients.map {
                var dict = ["name": $0.name, "amount": $0.amount]
                if let ingId = $0.ingredient_id, !ingId.isEmpty { dict["ingredient_id"] = ingId }
                return dict
            },
            ingredients_without_measures: scraped.base_ingredients,
            servings: scraped.servings,
            calories_total_kcal: scraped.calories_total_kcal,
            calories_total_joules: scraped.calories_total_kcal.map { $0 * 4.184 },
            calories_per_serving_kcal: scraped.calories_per_serving_kcal,
            protein_grams: scraped.protein_grams,
            carbs_grams: scraped.carbs_grams,
            fat_grams: scraped.fat_grams,
            fiber_grams: scraped.fiber_grams,
            tags: scraped.tags,
            cooking_time_minutes: scraped.cooking_time_minutes,
            cuisine: scraped.cuisine,
            difficulty: scraped.difficulty,
            thumbnail_base64: thumbnailBase64,
            freezer_friendly: scraped.freezer_friendly,
            requested_by: Clerk.shared.user?.id ?? "default",
            user_id: Clerk.shared.user?.id
        )

        guard await APIService.save(recipe: dto) != nil else {
            throw FeslihanError.recipeParseFailed
        }

        processedRecipe = ProcessedRecipe(
            title: scraped.title,
            ingredients: scraped.ingredients.map { Ingredient(name: $0.name, amount: $0.amount) },
            instructions: scraped.instructions,
            cookingTimeMinutes: scraped.cooking_time_minutes,
            thumbnailData: nil,
            servings: scraped.servings,
            caloriesTotalKcal: scraped.calories_total_kcal,
            caloriesPerServingKcal: scraped.calories_per_serving_kcal,
            proteinGrams: scraped.protein_grams,
            carbsGrams: scraped.carbs_grams,
            fatGrams: scraped.fat_grams,
            fiberGrams: scraped.fiber_grams,
            baseIngredients: scraped.base_ingredients,
            difficulty: scraped.difficulty,
            cuisine: scraped.cuisine,
            tags: scraped.tags,
            platformUser: scraped.platform_user,
            likesCount: 0,
            commentsCount: 0,
            freezerFriendly: scraped.freezer_friendly
        )
    }

    private func processVideoRecipe() async throws {
        // Social video platforms don't expose the raw video file to the device, so
        // we work from the post's caption/metadata rather than extracting media.
        processingState = .fetchingCaption
        let captionResult = try await CaptionService.fetchCaption(from: trimmedURL)
        guard !captionResult.caption.isEmpty else {
            throw FeslihanError.captionFetchFailed
        }

        processingState = .analyzingRecipe
        let recipe = try await ClaudeService.analyzeRecipe(
            transcription: "",
            caption: captionResult.caption
        )

        var dto = RecipeDTO.from(
            processed: recipe,
            url: trimmedURL,
            platform: detectPlatform(),
            caption: captionResult.caption,
            requestedBy: Clerk.shared.user?.id ?? "default",
            userId: Clerk.shared.user?.id
        )
        dto.thumbnail_base64 = captionResult.thumbnailData?.base64EncodedString()
        dto.creator_profile_pic_base64 = captionResult.authorProfilePicData?.base64EncodedString()
        // Prefer oEmbed author over Claude's extraction
        if let author = captionResult.authorName, !author.isEmpty {
            dto.platform_user = author
        }
        // Fetch profile pic from the device (social platforms block server IPs)
        if dto.creator_profile_pic_base64 == nil, detectPlatform() == "instagram",
           let username = dto.platform_user {
            let picData = await CaptionService.fetchInstagramProfilePic(username: username)
            dto.creator_profile_pic_base64 = picData?.base64EncodedString()
        }
        guard await APIService.save(recipe: dto) != nil else {
            throw FeslihanError.recipeParseFailed
        }

        processedRecipe = recipe
    }

    private func saveRecipe() {
        guard let processed = processedRecipe else { return }

        let recipe = Recipe(
            title: processed.title,
            ingredients: processed.ingredients,
            instructions: processed.instructions,
            sourceURL: urlText.isEmpty ? nil : urlText,
            thumbnailData: processed.thumbnailData,
            cookingTimeMinutes: processed.cookingTimeMinutes,
            cuisine: processed.cuisine,
            difficulty: processed.difficulty,
            tags: processed.tags,
            likesCount: processed.likesCount,
            servings: processed.servings,
            caloriesTotalKcal: processed.caloriesTotalKcal,
            caloriesPerServingKcal: processed.caloriesPerServingKcal,
            proteinGrams: processed.proteinGrams,
            carbsGrams: processed.carbsGrams,
            fatGrams: processed.fatGrams,
            fiberGrams: processed.fiberGrams,
            platformUser: processed.platformUser,
            platform: detectPlatform(),
            freezerFriendly: processed.freezerFriendly
        )

        modelContext.insert(recipe)
        dismiss()
    }
}
