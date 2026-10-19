package com.feslihan.app.data.repository

import com.feslihan.app.data.model.MealPlanRequest
import com.feslihan.app.data.model.MealPlanResult
import com.feslihan.app.data.model.SaveMealPlanRequest
import com.feslihan.app.data.model.SavedPlan
import com.feslihan.app.data.remote.FeslihanApi
import com.feslihan.app.data.session.SessionManager
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.encodeToJsonElement
import kotlinx.serialization.json.jsonObject
import javax.inject.Inject
import javax.inject.Singleton

/** Weekly meal plans: generate (metered), list, save, delete. */
@Singleton
class MealPlanRepository @Inject constructor(
    private val api: FeslihanApi,
    private val session: SessionManager,
    private val json: Json,
) {
    /** Generate a plan. Typed failure carries the HTTP code (402 = quota/premium). */
    suspend fun generate(request: MealPlanRequest): Result<MealPlanResult> = runCatching {
        val response = api.generateMealPlan(request.copy(userId = session.requireUserId()))
        if (response.isSuccessful) response.body() ?: error("empty")
        else throw MealPlanError(response.code())
    }

    suspend fun saved(): Result<List<SavedPlan>> = runCatching { api.getMealPlans(session.requireUserId()) }

    suspend fun save(name: String, result: MealPlanResult): Result<SavedPlan> = runCatching {
        val planObj = json.encodeToJsonElement(result).jsonObject
        api.saveMealPlan(
            SaveMealPlanRequest(
                name = name,
                plan = planObj,
                recipeIds = result.recipeIds,
                shoppingList = result.shoppingList,
            ),
        )
    }

    suspend fun delete(id: String): Result<Unit> = runCatching {
        val res = api.deleteMealPlan(id)
        if (!res.isSuccessful) error("delete failed")
    }
}

/** HTTP error from meal-plan endpoints. code 402 = quota/premium required. */
class MealPlanError(val code: Int) : Exception("meal plan http $code")
