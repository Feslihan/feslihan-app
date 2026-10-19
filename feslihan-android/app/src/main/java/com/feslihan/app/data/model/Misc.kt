package com.feslihan.app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class Folder(
    val id: String,
    @SerialName("user_id") val userId: String,
    val name: String,
    val emoji: String? = null,
    @SerialName("sort_order") val sortOrder: Int = 0,
    @SerialName("recipe_count") val recipeCount: Int? = null,
)

@Serializable
data class CreateFolderRequest(
    @SerialName("user_id") val userId: String,
    val name: String,
    val emoji: String,
)

@Serializable
data class UserReview(
    val id: String,
    @SerialName("user_id") val userId: String,
    @SerialName("recipe_id") val recipeId: String,
    val rating: Int,
    val comment: String? = null,
    @SerialName("created_at") val createdAt: String,
    @SerialName("user_name") val userName: String? = null,
    @SerialName("user_avatar_url") val userAvatarUrl: String? = null,
)

@Serializable
data class RecipeCost(
    @SerialName("estimated_cost") val estimatedCost: Double? = null,
    val currency: String? = null,
    @SerialName("priced_count") val pricedCount: Int = 0,
    @SerialName("total_count") val totalCount: Int = 0,
    val ingredients: List<RecipeCostIngredient> = emptyList(),
)

@Serializable
data class RecipeCostIngredient(
    val name: String,
    val measure: String? = null,
    @SerialName("price_per_unit") val pricePerUnit: Double? = null,
    @SerialName("price_unit") val priceUnit: String? = null,
    @SerialName("estimated_qty") val estimatedQty: Double? = null,
    @SerialName("estimated_cost") val estimatedCost: Double? = null,
)

/** `GET /users/me/quota` — the source of truth for subscription gating. */
@Serializable
data class QuotaStatus(
    val plan: String, // "free" | "plus" | "pro"
    val used: Int = 0,
    val limit: Int? = null, // null = unlimited
    val remaining: Int? = null,
    @SerialName("meal_plans_used") val mealPlansUsed: Int = 0,
    @SerialName("meal_plan_limit") val mealPlanLimit: Int? = null,
    @SerialName("meal_plans_remaining") val mealPlansRemaining: Int? = null,
    @SerialName("unlimited_until") val unlimitedUntil: String? = null,
    val month: String = "",
)

@Serializable
data class UserSyncRequest(
    val email: String? = null,
    val name: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
)

// Generic responses
@Serializable
data class OkResponse(val ok: Boolean = false)

@Serializable
data class AddedResponse(val added: Int = 0)

@Serializable
data class FavoriteResponse(val ok: Boolean = false, @SerialName("is_favorite") val isFavorite: Boolean = false)

@Serializable
data class AcceptShareResponse(val ok: Boolean = false, @SerialName("already_saved") val alreadySaved: Boolean = false)

@Serializable
data class FolderUpdateRequest(@SerialName("folder_id") val folderId: String? = null)

@Serializable
data class FavoriteRequest(@SerialName("is_favorite") val isFavorite: Boolean)
