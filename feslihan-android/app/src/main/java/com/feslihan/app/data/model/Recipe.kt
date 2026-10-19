package com.feslihan.app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Recipe DTO ↔ backend `recipes` (snake_case JSON). Mirrors iOS `RecipeDTO` /
 * SwiftData `Recipe`. All fields nullable except what the server requires on
 * create (`title`, `url`, `requested_by`, `platform`). See docs/API_CONTRACT.md.
 */
@Serializable
data class Recipe(
    val id: String? = null,
    val platform: String = "other",
    @SerialName("platform_user") val platformUser: String? = null,
    val url: String = "",
    @SerialName("likes_count") val likesCount: Int? = null,
    @SerialName("comments_count") val commentsCount: Int? = null,
    val caption: String? = null,
    val title: String = "",
    val description: String = "",
    @SerialName("ingredients_with_measures") val ingredientsWithMeasures: List<IngredientMeasure> = emptyList(),
    @SerialName("ingredients_without_measures") val ingredientsWithoutMeasures: List<String> = emptyList(),
    val servings: Int? = null,
    @SerialName("calories_total_kcal") val caloriesTotalKcal: Double? = null,
    @SerialName("calories_per_serving_kcal") val caloriesPerServingKcal: Double? = null,
    @SerialName("protein_grams") val proteinGrams: Double? = null,
    @SerialName("carbs_grams") val carbsGrams: Double? = null,
    @SerialName("fat_grams") val fatGrams: Double? = null,
    @SerialName("fiber_grams") val fiberGrams: Double? = null,
    val tags: List<String>? = null,
    @SerialName("cooking_time_minutes") val cookingTimeMinutes: Int? = null,
    val cuisine: String? = null,
    val difficulty: String? = null,
    @SerialName("health_score") val healthScore: Double? = null,
    @SerialName("thumbnail_url") val thumbnailUrl: String? = null,
    @SerialName("thumbnail_base64") val thumbnailBase64: String? = null, // write-only on save
    @SerialName("freezer_friendly") val freezerFriendly: Boolean? = null,
    @SerialName("requested_by") val requestedBy: String? = null,
    @SerialName("user_id") val userId: String? = null,
    @SerialName("folder_id") val folderId: String? = null,
    @SerialName("is_favorite") val isFavorite: Boolean? = null,
    @SerialName("save_count") val saveCount: Int? = null,
    val cached: Boolean? = null, // set by scrape-web cache hits
)

/**
 * One ingredient with its measure. Authoritative ingredient reference — match
 * pantry/shopping by [baseName]/[ingredientId], NOT by positional pairing with
 * `ingredients_without_measures`.
 */
@Serializable
data class IngredientMeasure(
    val name: String,
    val amount: String = "",
    val section: String? = null,
    @SerialName("base_name") val baseName: String? = null,
    @SerialName("ingredient_id") val ingredientId: String? = null,
)
