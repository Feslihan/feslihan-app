package com.feslihan.app.data.repository

import com.feslihan.app.data.local.RecipeDao
import com.feslihan.app.data.local.toDomain
import com.feslihan.app.data.local.toEntity
import com.feslihan.app.data.model.Recipe
import com.feslihan.app.data.remote.FeslihanApi
import com.feslihan.app.data.session.SessionManager
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Recipe data access: the user's library is cached in Room (offline-first) and
 * refreshed from the backend. Mutations hit the API, then update the cache.
 */
@Singleton
class RecipeRepository @Inject constructor(
    private val api: FeslihanApi,
    private val dao: RecipeDao,
    private val session: SessionManager,
) {
    /** Offline-first stream of the saved library. */
    val library: Flow<List<Recipe>> = dao.observeAll().map { list -> list.map { it.toDomain() } }

    /** Pulls the user's recipes from the server and replaces the local cache. */
    suspend fun refreshLibrary(): Result<Unit> = runCatching {
        val userId = session.requireUserId()
        val remote = api.getUserRecipes(userId)
        var stamp = System.currentTimeMillis()
        val entities = remote.mapNotNull { it.toEntity(createdAtEpochMs = stamp--) }
        dao.clear()
        dao.upsertAll(entities)
    }

    suspend fun getRecipe(id: String): Result<Recipe> = runCatching { api.getRecipe(id) }

    /** Checks whether a URL is already in the catalog (free, no quota). */
    suspend fun lookup(url: String): Recipe? = runCatching { api.lookupRecipe(url) }.getOrNull()

    /** Saves a recipe to the user's library and caches it locally. */
    suspend fun save(recipe: Recipe): Result<Recipe> = runCatching {
        val userId = session.requireUserId()
        val response = api.saveRecipe(recipe.copy(requestedBy = recipe.requestedBy ?: userId))
        val saved = response.body() ?: error("save failed: ${response.code()}")
        saved.toEntity(createdAtEpochMs = System.currentTimeMillis())?.let { dao.upsert(it) }
        saved
    }

    suspend fun delete(recipeId: String): Result<Unit> = runCatching {
        val userId = session.requireUserId()
        val res = api.deleteUserRecipe(userId, recipeId)
        if (!res.isSuccessful) error("delete failed: ${res.code()}")
        dao.deleteById(recipeId)
    }

    suspend fun setFavorite(recipeId: String, isFavorite: Boolean): Result<Unit> = runCatching {
        val userId = session.requireUserId()
        api.setRecipeFavorite(userId, recipeId, com.feslihan.app.data.model.FavoriteRequest(isFavorite))
        dao.setFavorite(recipeId, isFavorite)
    }

    suspend fun moveToFolder(recipeId: String, folderId: String?): Result<Unit> = runCatching {
        val userId = session.requireUserId()
        api.moveRecipeToFolder(userId, recipeId, com.feslihan.app.data.model.FolderUpdateRequest(folderId))
        dao.setFolder(recipeId, folderId)
    }
}
