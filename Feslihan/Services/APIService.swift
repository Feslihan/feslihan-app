import Foundation
import ClerkKit

enum APIService {
    /// Backend origin. Overridable via the FESLIHAN_API_URL launch environment
    /// variable so UI tests can point the app at a local test backend.
    static let baseURL: String = {
        if let override = ProcessInfo.processInfo.environment["FESLIHAN_API_URL"],
           !override.isEmpty {
            return override
        }
        return "https://feslihan-app.vercel.app"
    }()

    // MARK: - Auth

    /// The current Clerk session JWT, or nil if signed out.
    private static func authToken() async -> String? {
        try? await Clerk.shared.session?.getToken()
    }

    /// A GET request for `url` carrying the Clerk bearer token.
    static func authedGet(_ url: URL) async -> URLRequest {
        var request = URLRequest(url: url)
        if let token = await authToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    /// A copy of `request` with the Clerk bearer token attached.
    static func authed(_ request: URLRequest) async -> URLRequest {
        var request = request
        if let token = await authToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    /// Check if a recipe already exists for this URL.
    static func lookup(url: String) async -> RecipeDTO? {
        guard let encoded = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let requestURL = URL(string: "\(baseURL)/recipes/lookup?url=\(encoded)") else {
            return nil
        }

        guard let (data, response) = try? await URLSession.shared.data(for: await authedGet(requestURL)),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            return nil
        }

        return try? JSONDecoder().decode(RecipeDTO.self, from: data)
    }

    /// Fetch all recipes from the backend.
    static func fetchAll() async -> [RecipeDTO] {
        guard let requestURL = URL(string: "\(baseURL)/recipes") else { return [] }

        guard let (data, response) = try? await URLSession.shared.data(for: await authedGet(requestURL)),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            return []
        }

        return (try? JSONDecoder().decode([RecipeDTO].self, from: data)) ?? []
    }

    /// Fetch recipes for a specific user.
    static func fetchUserRecipes(userId: String) async -> [RecipeDTO] {
        guard let requestURL = URL(string: "\(baseURL)/users/\(userId)/recipes") else { return [] }

        guard let (data, response) = try? await URLSession.shared.data(for: await authedGet(requestURL)),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            return []
        }

        return (try? JSONDecoder().decode([RecipeDTO].self, from: data)) ?? []
    }

    /// Submit a recipe review after cooking.
    static func submitReview(recipeId: String, userId: String, rating: Int, comment: String?) async -> Bool {
        guard let url = URL(string: "\(baseURL)/recipes/\(recipeId)/reviews") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "user_id": userId,
            "rating": rating,
            "comment": comment ?? NSNull()
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (_, response) = try? await URLSession.shared.data(for: await authed(request)),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else { return false }
        return true
    }

    /// Delete a recipe review.
    static func deleteReview(reviewId: String, userId: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/reviews/\(reviewId)?user_id=\(userId)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        guard let (_, response) = try? await URLSession.shared.data(for: await authed(request)),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else { return false }
        return true
    }

    /// Fetch all recipe IDs a user has reviewed/tried.
    static func fetchUserReviews(userId: String) async -> [UserReviewDTO] {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/reviews") else { return [] }
        guard let (data, response) = try? await URLSession.shared.data(for: await authedGet(url)),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else { return [] }
        return (try? JSONDecoder().decode([UserReviewDTO].self, from: data)) ?? []
    }

    /// Fetch all known ingredients (with price tier) from the backend.
    static func fetchIngredients() async -> [IngredientDTO] {
        guard let requestURL = URL(string: "\(baseURL)/ingredients") else { return [] }

        guard let (data, response) = try? await URLSession.shared.data(for: await authedGet(requestURL)),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            return []
        }

        return (try? JSONDecoder().decode([IngredientDTO].self, from: data)) ?? []
    }

    /// Fetch all predefined tags from the backend.
    static func fetchTags() async -> [String] {
        guard let requestURL = URL(string: "\(baseURL)/tags") else { return [] }

        guard let (data, response) = try? await URLSession.shared.data(for: await authedGet(requestURL)),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            return []
        }

        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    /// Save a recipe to the backend.
    static func save(recipe: RecipeDTO) async -> RecipeDTO? {
        guard let requestURL = URL(string: "\(baseURL)/recipes") else { return nil }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let body = try? JSONEncoder().encode(recipe) else { return nil }
        request.httpBody = body

        guard let (data, response) = try? await URLSession.shared.data(for: await authed(request)),
              let http = response as? HTTPURLResponse,
              (200...201).contains(http.statusCode) else {
            return nil
        }

        return try? JSONDecoder().decode(RecipeDTO.self, from: data)
    }

    // MARK: - Web Scraping

    static func scrapeWebRecipe(url: String) async throws -> ScrapedRecipe {
        guard let requestURL = URL(string: "\(baseURL)/recipes/scrape-web") else {
            throw FeslihanError.recipeParseFailed
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        let body = ["url": url]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: await authed(request))

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw FeslihanError.recipeParseFailed
        }

        return try JSONDecoder().decode(ScrapedRecipe.self, from: data)
    }

    // MARK: - Folders

    static func fetchFolders(userId: String) async -> [FolderDTO] {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/folders") else { return [] }
        guard let (data, response) = try? await URLSession.shared.data(for: await authedGet(url)),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
        return (try? JSONDecoder().decode([FolderDTO].self, from: data)) ?? []
    }

    static func createFolder(userId: String, name: String, emoji: String?) async -> FolderDTO? {
        guard let url = URL(string: "\(baseURL)/folders") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["user_id": userId, "name": name, "emoji": emoji ?? ""]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, response) = try? await URLSession.shared.data(for: await authed(request)),
              let http = response as? HTTPURLResponse, http.statusCode == 201 else { return nil }
        return try? JSONDecoder().decode(FolderDTO.self, from: data)
    }

    static func deleteFolder(id: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/folders/\(id)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        guard let (_, response) = try? await URLSession.shared.data(for: await authed(request)),
              let http = response as? HTTPURLResponse, http.statusCode == 204 else { return false }
        return true
    }

    static func moveRecipeToFolder(userId: String, recipeId: String, folderId: String?) async -> Bool {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/recipes/\(recipeId)/folder") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any?] = ["folder_id": folderId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
        guard let (_, response) = try? await URLSession.shared.data(for: await authed(request)),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
        return true
    }

    /// Toggle favorite status for a recipe.
    static func toggleFavorite(userId: String, recipeId: String, isFavorite: Bool) async -> Bool {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/recipes/\(recipeId)/favorite") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["is_favorite": isFavorite])
        guard let (_, response) = try? await URLSession.shared.data(for: await authed(request)),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
        return true
    }

    /// Delete a recipe from the user's collection (keeps the global recipe).
    static func deleteUserRecipe(userId: String, recipeId: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/recipes/\(recipeId)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        guard let (_, response) = try? await URLSession.shared.data(for: await authed(request)),
              let http = response as? HTTPURLResponse, http.statusCode == 204 else { return false }
        return true
    }

    /// Fetch estimated cost for a recipe.
    static func fetchRecipeCost(recipeId: String) async -> RecipeCostDTO? {
        guard let requestURL = URL(string: "\(baseURL)/recipes/\(recipeId)/cost") else { return nil }
        guard let (data, response) = try? await URLSession.shared.data(for: await authedGet(requestURL)),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(RecipeCostDTO.self, from: data)
    }

    // MARK: - Meal Plans

    /// Fetch the user's saved meal plans, most recent first.
    static func fetchMealPlans(userId: String) async -> [SavedPlanItem] {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/meal-plans") else { return [] }
        guard let (data, response) = try? await URLSession.shared.data(for: await authedGet(url)),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
        return (try? JSONDecoder().decode([SavedPlanItem].self, from: data)) ?? []
    }

    // MARK: - Pantry

    /// Fetch the user's pantry items.
    static func fetchPantry(userId: String) async -> [PantryItemDTO] {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/pantry") else { return [] }
        guard let (data, response) = try? await URLSession.shared.data(for: await authedGet(url)),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
        return (try? JSONDecoder().decode([PantryItemDTO].self, from: data)) ?? []
    }

    static func addToPantry(userId: String, ingredientNames: [String]) async -> Bool {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/pantry") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["ingredient_names": ingredientNames]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (_, response) = try? await URLSession.shared.data(for: await authed(request)),
              let http = response as? HTTPURLResponse, http.statusCode == 201 else { return false }
        return true
    }

    static func removeFromPantry(userId: String, ingredientId: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/pantry/\(ingredientId)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        guard let (_, response) = try? await URLSession.shared.data(for: await authed(request)),
              let http = response as? HTTPURLResponse, http.statusCode == 204 else { return false }
        return true
    }

    // MARK: - Shopping List

    static func fetchShoppingList(userId: String) async -> [ShoppingItemDTO] {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/shopping-list") else { return [] }
        guard let (data, response) = try? await URLSession.shared.data(for: await authedGet(url)),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
        return (try? JSONDecoder().decode([ShoppingItemDTO].self, from: data)) ?? []
    }

    static func addToShoppingList(userId: String, ingredientNames: [String]) async -> Bool {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/shopping-list") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["ingredient_names": ingredientNames]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, response) = try? await URLSession.shared.data(for: await authed(request)),
              let http = response as? HTTPURLResponse, http.statusCode == 201 else { return false }
        // 201 with added == 0 means nothing matched (or it was already in the
        // list) — don't let the UI flip to "added" on a no-op.
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let added = json["added"] as? Int {
            return added > 0
        }
        return true
    }

    static func toggleShoppingItem(userId: String, itemId: String, isChecked: Bool) async -> Bool {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/shopping-list/\(itemId)/check") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Bool] = ["is_checked": isChecked]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (_, response) = try? await URLSession.shared.data(for: await authed(request)),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
        return true
    }

    static func removeFromShoppingList(userId: String, itemId: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/shopping-list/\(itemId)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        guard let (_, response) = try? await URLSession.shared.data(for: await authed(request)),
              let http = response as? HTTPURLResponse, http.statusCode == 204 else { return false }
        return true
    }

    // MARK: - KVKK (Data Rights)

    /// Download all personal data held for the current user as raw JSON (KVKK export).
    static func exportMyData() async -> Data? {
        guard let url = URL(string: "\(baseURL)/users/me/export") else { return nil }
        guard let (data, response) = try? await URLSession.shared.data(for: await authedGet(url)),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        return data
    }

    /// Permanently delete the current user and all of their data on the backend (KVKK erasure).
    static func deleteMyData() async -> Bool {
        guard let url = URL(string: "\(baseURL)/users/me") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        guard let (_, response) = try? await URLSession.shared.data(for: await authed(request)),
              let http = response as? HTTPURLResponse, http.statusCode == 204 else { return false }
        return true
    }

    /// Fetch instagram user info including profile picture URL.
    static func fetchCreator(username: String) async -> InstagramUserDTO? {
        guard let requestURL = URL(string: "\(baseURL)/creators/\(username)") else { return nil }

        guard let (data, response) = try? await URLSession.shared.data(for: await authedGet(requestURL)),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            return nil
        }

        return try? JSONDecoder().decode(InstagramUserDTO.self, from: data)
    }

    /// Backfill missing creator profile pictures from this device.
    static func backfillCreatorPictures() async {
        guard let url = URL(string: "\(baseURL)/creators/missing-pictures") else { return }
        guard let (data, response) = try? await URLSession.shared.data(for: await authedGet(url)),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let creators = try? JSONDecoder().decode([MissingPicCreator].self, from: data),
              !creators.isEmpty else { return }

        for creator in creators {
            guard creator.platform == "instagram" else { continue }
            guard let picData = await CaptionService.fetchInstagramProfilePic(username: creator.username) else { continue }
            guard let uploadURL = URL(string: "\(baseURL)/creators/\(creator.username)/picture") else { continue }
            var request = URLRequest(url: uploadURL)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: String] = ["base64": picData.base64EncodedString()]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: await authed(request))
        }
    }

    // MARK: - Social (friends & recipe shares)

    /// My friend code plus pending-request/share counts for badges.
    static func fetchSocialMe() async -> SocialMeDTO? {
        guard let url = URL(string: "\(baseURL)/social/me") else { return nil }
        guard let (data, response) = try? await URLSession.shared.data(for: await authedGet(url)),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(SocialMeDTO.self, from: data)
    }

    /// Look up a user by friend code or exact email.
    static func lookupFriend(code: String? = nil, email: String? = nil) async -> SocialLookupDTO? {
        // Percent-encode "+" explicitly: URLComponents leaves it raw in query
        // strings, but the server decodes a raw "+" as a space — which breaks
        // emails like "name+alias@example.com".
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=?")
        let query: String?
        if let code {
            query = code.addingPercentEncoding(withAllowedCharacters: allowed).map { "code=\($0)" }
        } else if let email {
            query = email.addingPercentEncoding(withAllowedCharacters: allowed).map { "email=\($0)" }
        } else {
            query = nil
        }
        guard let query, let url = URL(string: "\(baseURL)/social/lookup?\(query)") else { return nil }
        guard let (data, response) = try? await URLSession.shared.data(for: await authedGet(url)),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(SocialLookupDTO.self, from: data)
    }

    /// Send a follow request. The backend auto-accepts if the other side
    /// already requested us, so the returned status may be "accepted".
    static func sendFriendRequest(to userId: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/social/requests") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["to_user_id": userId])
        guard let (_, response) = try? await URLSession.shared.data(for: await authed(request)),
              let http = response as? HTTPURLResponse,
              (200...201).contains(http.statusCode) else { return false }
        return true
    }

    static func fetchFriendRequests() async -> FriendRequestsDTO? {
        guard let url = URL(string: "\(baseURL)/social/requests") else { return nil }
        guard let (data, response) = try? await URLSession.shared.data(for: await authedGet(url)),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(FriendRequestsDTO.self, from: data)
    }

    static func acceptFriendRequest(id: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/social/requests/\(id)/accept") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        guard let (_, response) = try? await URLSession.shared.data(for: await authed(request)),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
        return true
    }

    /// Decline an incoming request or cancel an outgoing one.
    static func deleteFriendRequest(id: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/social/requests/\(id)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        guard let (_, response) = try? await URLSession.shared.data(for: await authed(request)),
              let http = response as? HTTPURLResponse, http.statusCode == 204 else { return false }
        return true
    }

    static func fetchFriends() async -> [FriendDTO] {
        guard let url = URL(string: "\(baseURL)/social/friends") else { return [] }
        guard let (data, response) = try? await URLSession.shared.data(for: await authedGet(url)),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
        return (try? JSONDecoder().decode([FriendDTO].self, from: data)) ?? []
    }

    static func removeFriend(userId: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/social/friends/\(userId)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        guard let (_, response) = try? await URLSession.shared.data(for: await authed(request)),
              let http = response as? HTTPURLResponse, http.statusCode == 204 else { return false }
        return true
    }

    /// A friend's saved recipes (requires an accepted connection).
    static func fetchFriendRecipes(userId: String) async -> [RecipeDTO] {
        guard let url = URL(string: "\(baseURL)/social/friends/\(userId)/recipes") else { return [] }
        guard let (data, response) = try? await URLSession.shared.data(for: await authedGet(url)),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
        return (try? JSONDecoder().decode([RecipeDTO].self, from: data)) ?? []
    }

    /// Send a recipe to a friend.
    static func sendRecipe(recipeId: String, to userId: String, message: String?) async -> Bool {
        guard let url = URL(string: "\(baseURL)/social/shares") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["to_user_id": userId, "recipe_id": recipeId]
        if let message, !message.isEmpty { body["message"] = message }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (_, response) = try? await URLSession.shared.data(for: await authed(request)),
              let http = response as? HTTPURLResponse,
              (200...201).contains(http.statusCode) else { return false }
        return true
    }

    static func fetchShareInbox() async -> [ShareInboxItemDTO] {
        guard let url = URL(string: "\(baseURL)/social/shares/inbox") else { return [] }
        guard let (data, response) = try? await URLSession.shared.data(for: await authedGet(url)),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
        return (try? JSONDecoder().decode([ShareInboxItemDTO].self, from: data)) ?? []
    }

    /// Accept a shared recipe: the backend adds it to my library.
    static func acceptShare(id: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/social/shares/\(id)/accept") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        guard let (_, response) = try? await URLSession.shared.data(for: await authed(request)),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
        return true
    }

    static func dismissShare(id: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/social/shares/\(id)/dismiss") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        guard let (_, response) = try? await URLSession.shared.data(for: await authed(request)),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
        return true
    }

    /// All reviews on a recipe (the public board), with author name/avatar.
    static func fetchRecipeReviews(recipeId: String) async -> [UserReviewDTO] {
        guard let url = URL(string: "\(baseURL)/recipes/\(recipeId)/reviews") else { return [] }
        guard let (data, response) = try? await URLSession.shared.data(for: await authedGet(url)),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
        return (try? JSONDecoder().decode([UserReviewDTO].self, from: data)) ?? []
    }
}

struct MissingPicCreator: Codable {
    let username: String
    let platform: String
}

struct FolderDTO: Codable, Identifiable {
    var id: String
    var user_id: String
    var name: String
    var emoji: String?
    var sort_order: Int
    var recipe_count: Int?
}

struct IngredientDTO: Codable, Identifiable {
    var id: String { name }
    let name: String
    let price_tier: String?
    let availability: String?
    let price_per_unit: Double?
    let price_unit: String?
    let price_updated_at: String?
    let default_unit: String?      // "g", "ml", "adet"
    let density_g_ml: Double?      // grams per ml
    let gram_per_adet: Double?     // grams per 1 piece
    let alternative_ids: [String]?

    var priceTierEmoji: String? {
        switch price_tier {
        case "cheap": return "₺"
        case "neutral": return "₺₺"
        case "expensive": return "₺₺₺"
        default: return nil
        }
    }

    var formattedPrice: String? {
        guard let price = price_per_unit, let unit = price_unit else { return nil }
        return String(format: "%.2f ₺/%@", price, unit)
    }

    var availabilityIcon: String? {
        switch availability {
        case "easy": return "checkmark.circle"
        case "neutral": return "minus.circle"
        case "rare": return "exclamationmark.circle"
        default: return nil
        }
    }
}

struct UserReviewDTO: Codable, Identifiable {
    let id: String
    let user_id: String
    let recipe_id: String
    let rating: Int
    let comment: String?
    let created_at: String
    // Author info, present on the public reviews endpoint (joined server-side).
    var user_name: String?
    var user_avatar_url: String?
}

struct InstagramUserDTO: Codable {
    let username: String
    let profile_picture_url: String?
}

struct RecipeCostDTO: Codable {
    let estimated_cost: Double?
    let currency: String?
    let priced_count: Int
    let total_count: Int
    let ingredients: [IngredientCostDTO]
}

struct IngredientCostDTO: Codable {
    let name: String
    let measure: String?
    let price_per_unit: Double?
    let price_unit: String?
    let estimated_qty: Double?
    let estimated_cost: Double?
}

/// DTO matching the backend API shape.
struct RecipeDTO: Codable {
    var id: String?
    var platform: String
    var platform_user: String?
    var url: String
    var likes_count: Int?
    var comments_count: Int?
    var caption: String?

    var title: String
    var description: String

    var ingredients_with_measures: [[String: String]]
    var ingredients_without_measures: [String]
    var servings: Int?

    var calories_total_kcal: Double?
    var calories_total_joules: Double?
    var calories_per_serving_kcal: Double?
    var protein_grams: Double?
    var carbs_grams: Double?
    var fat_grams: Double?
    var fiber_grams: Double?

    var tags: [String]?
    var cooking_time: String?
    var cooking_time_minutes: Int?
    var cuisine: String?
    var difficulty: String?
    var health_score: Double?
    var thumbnail_url: String?
    var thumbnail_base64: String?
    var freezer_friendly: Bool?

    var creator_profile_pic_base64: String?

    var requested_by: String
    var user_id: String?
    var folder_id: String?
    var is_favorite: Bool?
    var save_count: Int?
}

extension RecipeDTO {
    /// Convert from ProcessedRecipe (Claude output) to DTO for saving.
    static func from(
        processed: ProcessedRecipe,
        url: String,
        platform: String,
        caption: String?,
        requestedBy: String,
        userId: String? = nil
    ) -> RecipeDTO {
        RecipeDTO(
            platform: platform,
            platform_user: processed.platformUser,
            url: url,
            likes_count: processed.likesCount,
            comments_count: processed.commentsCount,
            caption: caption,
            title: processed.title,
            description: processed.instructions,
            ingredients_with_measures: processed.ingredients.map {
                var dict = ["name": $0.name, "amount": $0.amount]
                if let section = $0.section { dict["section"] = section }
                return dict
            },
            ingredients_without_measures: processed.baseIngredients,
            servings: processed.servings,
            calories_total_kcal: processed.caloriesTotalKcal,
            calories_total_joules: processed.caloriesTotalKcal.map { $0 * 4.184 },
            calories_per_serving_kcal: processed.caloriesPerServingKcal,
            protein_grams: processed.proteinGrams,
            carbs_grams: processed.carbsGrams,
            fat_grams: processed.fatGrams,
            fiber_grams: processed.fiberGrams,
            tags: processed.tags,
            cooking_time: nil,
            cooking_time_minutes: processed.cookingTimeMinutes,
            cuisine: processed.cuisine,
            difficulty: processed.difficulty,
            thumbnail_base64: processed.thumbnailData?.base64EncodedString(),
            freezer_friendly: processed.freezerFriendly,
            requested_by: requestedBy,
            user_id: userId
        )
    }

    /// Convert DTO to local SwiftData Recipe. Call from async context.
    func toRecipe(thumbnailData: Data? = nil) -> Recipe {
        let ingredients = ingredients_with_measures.enumerated().map { index, item in
            Self.makeIngredient(item: item, index: index, withoutMeasures: ingredients_without_measures)
        }

        return Recipe(
            title: title,
            ingredients: ingredients,
            instructions: description,
            sourceURL: url,
            thumbnailData: thumbnailData,
            cookingTimeMinutes: cooking_time_minutes,
            cuisine: cuisine,
            difficulty: difficulty,
            tags: tags ?? [],
            likesCount: likes_count,
            servings: servings,
            caloriesTotalKcal: calories_total_kcal,
            caloriesPerServingKcal: calories_per_serving_kcal,
            proteinGrams: protein_grams,
            carbsGrams: carbs_grams,
            fatGrams: fat_grams,
            fiberGrams: fiber_grams,
            platformUser: platform_user,
            platform: platform,
            folderId: folder_id,
            freezerFriendly: freezer_friendly ?? false,
            saveCount: save_count ?? 0
        )
    }

    /// Build an Ingredient from a backend ingredients_with_measures entry.
    /// Prefers the entry's own base_name/ingredient_id (canonical reference);
    /// positional pairing with ingredients_without_measures is only a fallback
    /// for old payloads, where the arrays often misalign.
    static func makeIngredient(item: [String: String], index: Int, withoutMeasures: [String]) -> Ingredient {
        let sec = item["section"]?.trimmingCharacters(in: .whitespaces)
        let baseName = item["base_name"]
            ?? (index < withoutMeasures.count ? withoutMeasures[index] : nil)
        let ingredientId = (item["ingredient_id"]?.isEmpty ?? true) ? nil : item["ingredient_id"]
        return Ingredient(
            name: item["name"] ?? "",
            amount: item["amount"] ?? "",
            baseName: baseName,
            section: (sec?.isEmpty ?? true) ? nil : sec,
            ingredientId: ingredientId
        )
    }

    /// Convert DTO from backend to ProcessedRecipe for the UI.
    func toProcessedRecipe() -> ProcessedRecipe {
        let ingredients = ingredients_with_measures.enumerated().map { index, item in
            Self.makeIngredient(item: item, index: index, withoutMeasures: ingredients_without_measures)
        }

        return ProcessedRecipe(
            title: title,
            ingredients: ingredients,
            instructions: description,
            cookingTimeMinutes: cooking_time_minutes,
            thumbnailData: nil,
            servings: servings,
            caloriesTotalKcal: calories_total_kcal,
            caloriesPerServingKcal: calories_per_serving_kcal,
            proteinGrams: protein_grams,
            carbsGrams: carbs_grams,
            fatGrams: fat_grams,
            fiberGrams: fiber_grams,
            baseIngredients: ingredients_without_measures,
            difficulty: difficulty,
            cuisine: cuisine,
            tags: tags ?? [],
            platformUser: platform_user,
            likesCount: likes_count,
            commentsCount: comments_count,
            freezerFriendly: freezer_friendly ?? false
        )
    }
}

struct PantryItemDTO: Codable, Identifiable {
    let id: String
    let ingredient_id: String
    let ingredient_name: String
    let price_tier: String?
    let availability: String?
    let added_at: String
}

struct ShoppingItemDTO: Codable, Identifiable {
    let id: String
    let ingredient_id: String
    let ingredient_name: String
    let price_tier: String?
    let availability: String?
    let is_checked: Bool
    let added_at: String
    let pantry_alternative: String?
}

// MARK: - Social DTOs

struct SocialMeDTO: Codable {
    let friend_code: String
    let incoming_request_count: Int
    let pending_share_count: Int
}

struct SocialUserDTO: Codable {
    let clerk_id: String
    let name: String?
    let avatar_url: String?

    /// Display name with a Turkish fallback for users without a synced profile.
    var displayName: String {
        let trimmed = name?.trimmingCharacters(in: .whitespaces) ?? ""
        return trimmed.isEmpty ? "Feslihan kullanıcısı" : trimmed
    }
}

struct SocialLookupDTO: Codable {
    let user: SocialUserDTO
    let relationship: String  // none | self | pending_outgoing | pending_incoming | friends
}

struct FriendRequestDTO: Codable, Identifiable {
    let id: String
    let user: SocialUserDTO
    let created_at: String
}

struct FriendRequestsDTO: Codable {
    let incoming: [FriendRequestDTO]
    let outgoing: [FriendRequestDTO]
}

struct FriendDTO: Codable, Identifiable {
    let user: SocialUserDTO
    let connected_at: String?

    var id: String { user.clerk_id }
}

struct SharedRecipeSummaryDTO: Codable {
    let id: String
    let title: String
    let thumbnail_url: String?
    let cooking_time_minutes: Int?
    let platform: String?
}

struct ShareInboxItemDTO: Codable, Identifiable {
    let id: String
    let message: String?
    let status: String
    let created_at: String
    let sender: SocialUserDTO
    let recipe: SharedRecipeSummaryDTO
}

struct ScrapedRecipeIngredient: Codable {
    let name: String
    let amount: String
    let ingredient_id: String?
}

struct ScrapedRecipe: Codable {
    let is_recipe: Bool
    let title: String
    let ingredients: [ScrapedRecipeIngredient]
    let base_ingredients: [String]
    let instructions: String
    let cooking_time_minutes: Int?
    let servings: Int?
    let calories_total_kcal: Double?
    let calories_per_serving_kcal: Double?
    let protein_grams: Double?
    let carbs_grams: Double?
    let fat_grams: Double?
    let fiber_grams: Double?
    let difficulty: String?
    let cuisine: String?
    let tags: [String]
    let freezer_friendly: Bool
    let platform_user: String?
    let thumbnail_url: String?
    let likes_count: Int?
    let comments_count: Int?
}
