package com.feslihan.app.ui.navigation

/** Navigation routes. Mirrors the iOS screen set (one entry per View). */
object Routes {
    const val SPLASH = "splash"
    const val ONBOARDING = "onboarding"
    const val HOME = "home" // ModeSelectionView — the 5-mode hub

    // Mode 1 — Haftalık Plan
    const val MEAL_PREP = "meal_prep"
    const val SAVED_MEAL_PLANS = "saved_meal_plans"

    // Mode 2 — Ne Yesem?
    const val WHAT_TO_EAT = "what_to_eat"

    // Mode 3 — Tariflerim
    const val RECIPE_LIST = "recipe_list"
    const val ADD_RECIPE = "add_recipe"
    const val RECIPE_DETAIL = "recipe_detail" // + /{recipeId}
    const val COOKING_MODE = "cooking_mode"    // + /{recipeId}

    // Mode 4 — Kilerim
    const val PANTRY = "pantry"

    // Mode 5 — Alışveriş Listesi
    const val SHOPPING_LIST = "shopping_list"

    // Social
    const val FRIENDS = "friends"
    const val FRIEND_RECIPES = "friend_recipes" // + /{userId}
    const val SHARED_INBOX = "shared_inbox"

    // Settings / paywall
    const val SETTINGS = "settings"
    const val PAYWALL = "paywall"

    fun recipeDetail(recipeId: String) = "$RECIPE_DETAIL/$recipeId"
    fun cookingMode(recipeId: String) = "$COOKING_MODE/$recipeId"
    fun friendRecipes(userId: String, name: String) =
        "$FRIEND_RECIPES/$userId?name=${android.net.Uri.encode(name)}"
}
