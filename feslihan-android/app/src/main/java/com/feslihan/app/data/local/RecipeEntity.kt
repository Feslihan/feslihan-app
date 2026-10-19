package com.feslihan.app.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.feslihan.app.data.model.IngredientMeasure
import com.feslihan.app.data.model.Recipe

/**
 * Local cache of the user's saved recipes (mirrors the SwiftData `Recipe` model
 * on iOS). Lets the library render offline; the server remains the source of truth.
 */
@Entity(tableName = "recipes")
data class RecipeEntity(
    @PrimaryKey val id: String,
    val title: String,
    val instructions: String,
    val sourceUrl: String?,
    val thumbnailUrl: String?,
    val cookingTimeMinutes: Int?,
    val cuisine: String?,
    val difficulty: String?,
    val servings: Int?,
    val caloriesPerServingKcal: Double?,
    val platform: String?,
    val platformUser: String?,
    val folderId: String?,
    val isFavorite: Boolean,
    val freezerFriendly: Boolean?,
    val tags: List<String>,
    val ingredientsWithMeasures: List<IngredientMeasure>,
    val ingredientsWithoutMeasures: List<String>,
    val createdAtEpochMs: Long,
)

fun RecipeEntity.toDomain(): Recipe = Recipe(
    id = id,
    title = title,
    description = instructions,
    url = sourceUrl ?: "",
    thumbnailUrl = thumbnailUrl,
    cookingTimeMinutes = cookingTimeMinutes,
    cuisine = cuisine,
    difficulty = difficulty,
    servings = servings,
    caloriesPerServingKcal = caloriesPerServingKcal,
    platform = platform ?: "other",
    platformUser = platformUser,
    folderId = folderId,
    isFavorite = isFavorite,
    freezerFriendly = freezerFriendly,
    tags = tags,
    ingredientsWithMeasures = ingredientsWithMeasures,
    ingredientsWithoutMeasures = ingredientsWithoutMeasures,
)

fun Recipe.toEntity(createdAtEpochMs: Long): RecipeEntity? {
    val recipeId = id ?: return null // can't cache a recipe without a server id
    return RecipeEntity(
        id = recipeId,
        title = title,
        instructions = description,
        sourceUrl = url.ifBlank { null },
        thumbnailUrl = thumbnailUrl,
        cookingTimeMinutes = cookingTimeMinutes,
        cuisine = cuisine,
        difficulty = difficulty,
        servings = servings,
        caloriesPerServingKcal = caloriesPerServingKcal,
        platform = platform,
        platformUser = platformUser,
        folderId = folderId,
        isFavorite = isFavorite ?: false,
        freezerFriendly = freezerFriendly,
        tags = tags ?: emptyList(),
        ingredientsWithMeasures = ingredientsWithMeasures,
        ingredientsWithoutMeasures = ingredientsWithoutMeasures,
        createdAtEpochMs = createdAtEpochMs,
    )
}
