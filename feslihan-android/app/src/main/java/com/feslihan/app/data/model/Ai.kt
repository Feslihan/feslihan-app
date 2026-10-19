package com.feslihan.app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** `POST /ai/analyze` response — Claude's structured recipe extraction. */
@Serializable
data class AnalyzeResult(
    @SerialName("is_recipe") val isRecipe: Boolean = false,
    val title: String = "",
    val ingredients: List<AiIngredient> = emptyList(),
    @SerialName("base_ingredients") val baseIngredients: List<String> = emptyList(),
    val instructions: String = "",
    @SerialName("cooking_time_minutes") val cookingTimeMinutes: Int? = null,
    val servings: Int? = null,
    @SerialName("calories_total_kcal") val caloriesTotalKcal: Double? = null,
    @SerialName("calories_per_serving_kcal") val caloriesPerServingKcal: Double? = null,
    @SerialName("protein_grams") val proteinGrams: Double? = null,
    @SerialName("carbs_grams") val carbsGrams: Double? = null,
    @SerialName("fat_grams") val fatGrams: Double? = null,
    @SerialName("fiber_grams") val fiberGrams: Double? = null,
    val difficulty: String? = null,
    val cuisine: String? = null,
    @SerialName("freezer_friendly") val freezerFriendly: Boolean? = null,
    val tags: List<String>? = null,
    @SerialName("best_thumbnail_index") val bestThumbnailIndex: Int? = null,
    @SerialName("platform_user") val platformUser: String? = null,
    @SerialName("likes_count") val likesCount: Int? = null,
    @SerialName("comments_count") val commentsCount: Int? = null,
)

@Serializable
data class AiIngredient(
    val name: String,
    val amount: String = "",
    val section: String? = null,
    @SerialName("ingredient_id") val ingredientId: String? = null,
)

/** `POST /ai/analyze` request body (base64 frames/audio). */
@Serializable
data class AnalyzeRequest(
    val caption: String = "",
    val transcription: String = "",
    val frames: List<String> = emptyList(),
    @SerialName("cover_image") val coverImage: String? = null,
    val audio: String? = null,
)

/** `POST /recipes/scrape-web` request. A cache hit returns a full [Recipe] with `cached=true`. */
@Serializable
data class ScrapeWebRequest(val url: String)
