package com.feslihan.app.data.repository

import com.feslihan.app.data.model.CheckRequest
import com.feslihan.app.data.model.Ingredient
import com.feslihan.app.data.model.IngredientNamesRequest
import com.feslihan.app.data.model.PantryItem
import com.feslihan.app.data.model.QuotaStatus
import com.feslihan.app.data.model.ShoppingItem
import com.feslihan.app.data.remote.FeslihanApi
import com.feslihan.app.data.session.SessionManager
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Pantry, shopping list, ingredient catalog, and quota. Thin wrappers over the
 * API scoped to the current user; kept network-only (these lists are small and
 * always read fresh), with Result wrapping so screens can show error states.
 */
@Singleton
class UserDataRepository @Inject constructor(
    private val api: FeslihanApi,
    private val session: SessionManager,
) {
    // Pantry
    suspend fun pantry(): Result<List<PantryItem>> = runCatching { api.getPantry(session.requireUserId()) }

    suspend fun addToPantry(names: List<String>): Result<Int> = runCatching {
        api.addPantry(session.requireUserId(), IngredientNamesRequest(names)).added
    }

    suspend fun removeFromPantry(ingredientId: String): Result<Unit> = runCatching {
        val res = api.deletePantry(session.requireUserId(), ingredientId)
        if (!res.isSuccessful) error("delete failed: ${res.code()}")
    }

    // Shopping list
    suspend fun shoppingList(): Result<List<ShoppingItem>> = runCatching { api.getShoppingList(session.requireUserId()) }

    suspend fun addToShopping(names: List<String>): Result<Int> = runCatching {
        api.addShopping(session.requireUserId(), IngredientNamesRequest(names)).added
    }

    suspend fun setChecked(itemId: String, checked: Boolean): Result<Unit> = runCatching {
        api.checkShopping(session.requireUserId(), itemId, CheckRequest(checked))
        Unit
    }

    suspend fun removeFromShopping(itemId: String): Result<Unit> = runCatching {
        val res = api.deleteShopping(session.requireUserId(), itemId)
        if (!res.isSuccessful) error("delete failed: ${res.code()}")
    }

    // Catalog / quota
    suspend fun ingredients(): Result<List<Ingredient>> = runCatching { api.getIngredients() }
    suspend fun quota(): Result<QuotaStatus> = runCatching { api.quota() }
}
