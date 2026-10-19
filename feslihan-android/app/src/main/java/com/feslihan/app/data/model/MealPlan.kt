package com.feslihan.app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject

/** `POST /ai/meal-plan` request body. */
@Serializable
data class MealPlanRequest(
    @SerialName("people_count") val peopleCount: String,
    @SerialName("meals_per_day") val mealsPerDay: String,
    @SerialName("eating_styles") val eatingStyles: List<String> = emptyList(),
    val period: String,
    @SerialName("has_kids") val hasKids: Boolean = false,
    @SerialName("kids_count") val kidsCount: Int = 0,
    @SerialName("prep_style") val prepStyle: String,
    val budget: String,
    @SerialName("user_id") val userId: String,
)

/** `POST /ai/meal-plan` response. */
@Serializable
data class MealPlanResult(
    val days: List<MealPlanDay> = emptyList(),
    @SerialName("shopping_list") val shoppingList: List<ShoppingListItem> = emptyList(),
    @SerialName("recipe_ids") val recipeIds: List<String> = emptyList(),
    @SerialName("avg_calories_per_day") val avgCaloriesPerDay: Int? = null,
)

@Serializable
data class MealPlanDay(
    @SerialName("day_name") val dayName: String,
    val meals: List<Meal> = emptyList(),
)

@Serializable
data class Meal(
    @SerialName("meal_type") val mealType: String,
    @SerialName("recipe_ids") val recipeIds: List<String>? = null,
    // Fallback fields when a meal isn't a saved recipe:
    val name: String? = null,
    val description: String? = null,
    val calories: Int? = null,
    val ingredients: List<String>? = null,
)

@Serializable
data class ShoppingListItem(
    val name: String,
    val amount: String = "",
    @SerialName("ingredient_id") val ingredientId: String = "",
)

/** `meal_plans` row. `plan` is kept as a raw JSON object (mirrors server shape). */
@Serializable
data class SavedPlan(
    val id: String,
    @SerialName("user_id") val userId: String,
    val name: String = "",
    val plan: JsonObject,
    @SerialName("recipe_ids") val recipeIds: List<String> = emptyList(),
    @SerialName("shopping_list") val shoppingList: List<ShoppingListItem> = emptyList(),
    @SerialName("shopping_ingredient_ids") val shoppingIngredientIds: List<String> = emptyList(),
    @SerialName("created_at") val createdAt: String,
)

/** `POST /meal-plans` body. */
@Serializable
data class SaveMealPlanRequest(
    val name: String? = null,
    val plan: JsonObject,
    @SerialName("recipe_ids") val recipeIds: List<String>? = null,
    @SerialName("shopping_list") val shoppingList: List<ShoppingListItem>? = null,
)
