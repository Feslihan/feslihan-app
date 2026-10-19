package com.feslihan.app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class PantryItem(
    val id: String,
    @SerialName("ingredient_id") val ingredientId: String,
    @SerialName("ingredient_name") val ingredientName: String,
    @SerialName("price_tier") val priceTier: String? = null,
    val availability: String? = null,
    @SerialName("added_at") val addedAt: String,
)

@Serializable
data class ShoppingItem(
    val id: String, // shopping-list row id (use for check/delete)
    @SerialName("ingredient_id") val ingredientId: String,
    @SerialName("ingredient_name") val ingredientName: String,
    @SerialName("price_tier") val priceTier: String? = null,
    val availability: String? = null,
    @SerialName("is_checked") val isChecked: Boolean = false,
    @SerialName("added_at") val addedAt: String,
    @SerialName("pantry_alternative") val pantryAlternative: String? = null,
)

/** `GET /ingredients` — `name` acts as the id on the client. */
@Serializable
data class Ingredient(
    val name: String,
    @SerialName("price_tier") val priceTier: String? = null,
    val availability: String? = null,
    @SerialName("price_per_unit") val pricePerUnit: Double? = null,
    @SerialName("price_unit") val priceUnit: String? = null,
    @SerialName("price_updated_at") val priceUpdatedAt: String? = null,
    @SerialName("default_unit") val defaultUnit: String? = null,
    @SerialName("density_g_ml") val densityGMl: Double? = null,
    @SerialName("gram_per_adet") val gramPerAdet: Double? = null,
    @SerialName("alternative_ids") val alternativeIds: List<String>? = null,
)

/** Request body for pantry/shopping-list add endpoints. */
@Serializable
data class IngredientNamesRequest(
    @SerialName("ingredient_names") val ingredientNames: List<String>,
)

@Serializable
data class CheckRequest(@SerialName("is_checked") val isChecked: Boolean)
