package com.feslihan.app.data.remote

import com.feslihan.app.data.model.AcceptShareResponse
import com.feslihan.app.data.model.AddedResponse
import com.feslihan.app.data.model.AnalyzeRequest
import com.feslihan.app.data.model.AnalyzeResult
import com.feslihan.app.data.model.CheckRequest
import com.feslihan.app.data.model.CreateFolderRequest
import com.feslihan.app.data.model.FavoriteRequest
import com.feslihan.app.data.model.FavoriteResponse
import com.feslihan.app.data.model.FollowRequest
import com.feslihan.app.data.model.Folder
import com.feslihan.app.data.model.FolderUpdateRequest
import com.feslihan.app.data.model.Friend
import com.feslihan.app.data.model.FriendRequests
import com.feslihan.app.data.model.Ingredient
import com.feslihan.app.data.model.IngredientNamesRequest
import com.feslihan.app.data.model.MealPlanRequest
import com.feslihan.app.data.model.MealPlanResult
import com.feslihan.app.data.model.OkResponse
import com.feslihan.app.data.model.PantryItem
import com.feslihan.app.data.model.QuotaStatus
import com.feslihan.app.data.model.Recipe
import com.feslihan.app.data.model.RecipeCost
import com.feslihan.app.data.model.SaveMealPlanRequest
import com.feslihan.app.data.model.SavedPlan
import com.feslihan.app.data.model.ScrapeWebRequest
import com.feslihan.app.data.model.ShareInboxItem
import com.feslihan.app.data.model.ShareRequest
import com.feslihan.app.data.model.ShoppingItem
import com.feslihan.app.data.model.SocialLookup
import com.feslihan.app.data.model.SocialMe
import com.feslihan.app.data.model.UserReview
import com.feslihan.app.data.model.UserSyncRequest
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.PUT
import retrofit2.http.Path
import retrofit2.http.Query

/**
 * Retrofit surface for the Feslihan backend. One-to-one with docs/API_CONTRACT.md.
 * The Clerk bearer token is attached by [AuthInterceptor]; `:userId` path params
 * are accepted by the server but it trusts the token's identity.
 *
 * Mutations that return no body (204) use `Response<Unit>` so callers can inspect
 * the status; quota-metered calls return `Response<T>` so a 402 body/code is readable.
 */
interface FeslihanApi {

    // ── Recipes ──────────────────────────────────────────────────────────────
    @GET("/recipes/lookup")
    suspend fun lookupRecipe(@Query("url") url: String): Recipe?

    @GET("/recipes")
    suspend fun getRecipes(
        @Query("requested_by") requestedBy: String? = null,
        @Query("platform") platform: String? = null,
    ): List<Recipe>

    @GET("/recipes/{id}")
    suspend fun getRecipe(@Path("id") id: String): Recipe

    @GET("/users/{userId}/recipes")
    suspend fun getUserRecipes(@Path("userId") userId: String): List<Recipe>

    @POST("/recipes")
    suspend fun saveRecipe(@Body recipe: Recipe): Response<Recipe>

    @DELETE("/users/{userId}/recipes/{recipeId}")
    suspend fun deleteUserRecipe(
        @Path("userId") userId: String,
        @Path("recipeId") recipeId: String,
    ): Response<Unit>

    @PUT("/users/{userId}/recipes/{recipeId}/folder")
    suspend fun moveRecipeToFolder(
        @Path("userId") userId: String,
        @Path("recipeId") recipeId: String,
        @Body body: FolderUpdateRequest,
    ): OkResponse

    @PUT("/users/{userId}/recipes/{recipeId}/favorite")
    suspend fun setRecipeFavorite(
        @Path("userId") userId: String,
        @Path("recipeId") recipeId: String,
        @Body body: FavoriteRequest,
    ): FavoriteResponse

    @GET("/recipes/{id}/cost")
    suspend fun getRecipeCost(@Path("id") id: String): RecipeCost

    @GET("/recipes/{recipeId}/reviews")
    suspend fun getRecipeReviews(
        @Path("recipeId") recipeId: String,
        @Query("limit") limit: Int = 50,
        @Query("offset") offset: Int = 0,
    ): List<UserReview>

    @POST("/recipes/scrape-web")
    suspend fun scrapeWeb(@Body body: ScrapeWebRequest): Response<Recipe>

    // ── AI (metered — may return 402) ────────────────────────────────────────
    @POST("/ai/analyze")
    suspend fun analyze(@Body body: AnalyzeRequest): Response<AnalyzeResult>

    @POST("/ai/meal-plan")
    suspend fun generateMealPlan(@Body body: MealPlanRequest): Response<MealPlanResult>

    // ── Meal plans (saved) ───────────────────────────────────────────────────
    @GET("/users/{userId}/meal-plans")
    suspend fun getMealPlans(@Path("userId") userId: String): List<SavedPlan>

    @POST("/meal-plans")
    suspend fun saveMealPlan(@Body body: SaveMealPlanRequest): SavedPlan

    @DELETE("/meal-plans/{id}")
    suspend fun deleteMealPlan(@Path("id") id: String): Response<Unit>

    // ── Pantry ───────────────────────────────────────────────────────────────
    @GET("/users/{userId}/pantry")
    suspend fun getPantry(@Path("userId") userId: String): List<PantryItem>

    @POST("/users/{userId}/pantry")
    suspend fun addPantry(
        @Path("userId") userId: String,
        @Body body: IngredientNamesRequest,
    ): AddedResponse

    @DELETE("/users/{userId}/pantry/{ingredientId}")
    suspend fun deletePantry(
        @Path("userId") userId: String,
        @Path("ingredientId") ingredientId: String,
    ): Response<Unit>

    // ── Shopping list ────────────────────────────────────────────────────────
    @GET("/users/{userId}/shopping-list")
    suspend fun getShoppingList(@Path("userId") userId: String): List<ShoppingItem>

    @POST("/users/{userId}/shopping-list")
    suspend fun addShopping(
        @Path("userId") userId: String,
        @Body body: IngredientNamesRequest,
    ): AddedResponse

    @PUT("/users/{userId}/shopping-list/{itemId}/check")
    suspend fun checkShopping(
        @Path("userId") userId: String,
        @Path("itemId") itemId: String,
        @Body body: CheckRequest,
    ): OkResponse

    @DELETE("/users/{userId}/shopping-list/{itemId}")
    suspend fun deleteShopping(
        @Path("userId") userId: String,
        @Path("itemId") itemId: String,
    ): Response<Unit>

    // ── Folders ──────────────────────────────────────────────────────────────
    @GET("/users/{userId}/folders")
    suspend fun getFolders(@Path("userId") userId: String): List<Folder>

    @POST("/folders")
    suspend fun createFolder(@Body body: CreateFolderRequest): Folder

    @DELETE("/folders/{id}")
    suspend fun deleteFolder(@Path("id") id: String): Response<Unit>

    // ── Ingredients / tags ───────────────────────────────────────────────────
    @GET("/ingredients")
    suspend fun getIngredients(): List<Ingredient>

    @GET("/tags")
    suspend fun getTags(): List<String>

    // ── Social ───────────────────────────────────────────────────────────────
    @GET("/social/me")
    suspend fun socialMe(): SocialMe

    @GET("/social/lookup")
    suspend fun socialLookup(
        @Query("code") code: String? = null,
        @Query("email") email: String? = null,
    ): Response<SocialLookup>

    @POST("/social/requests")
    suspend fun sendFriendRequest(@Body body: FollowRequest): Response<Unit>

    @GET("/social/requests")
    suspend fun friendRequests(): FriendRequests

    @POST("/social/requests/{id}/accept")
    suspend fun acceptFriendRequest(@Path("id") id: String): Response<Unit>

    @DELETE("/social/requests/{id}")
    suspend fun declineFriendRequest(@Path("id") id: String): Response<Unit>

    @GET("/social/friends")
    suspend fun friends(): List<Friend>

    @DELETE("/social/friends/{userId}")
    suspend fun unfriend(@Path("userId") userId: String): Response<Unit>

    @GET("/social/friends/{userId}/recipes")
    suspend fun friendRecipes(@Path("userId") userId: String): Response<List<Recipe>>

    @POST("/social/shares")
    suspend fun shareRecipe(@Body body: ShareRequest): Response<Unit>

    @GET("/social/shares/inbox")
    suspend fun shareInbox(@Query("status") status: String = "pending"): List<ShareInboxItem>

    @POST("/social/shares/{id}/accept")
    suspend fun acceptShare(@Path("id") id: String): AcceptShareResponse

    @POST("/social/shares/{id}/dismiss")
    suspend fun dismissShare(@Path("id") id: String): OkResponse

    // ── Subscription / quota / user ──────────────────────────────────────────
    @GET("/users/me/quota")
    suspend fun quota(): QuotaStatus

    @POST("/users/sync")
    suspend fun syncUser(@Body body: UserSyncRequest): OkResponse
}
