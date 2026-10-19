package com.feslihan.app.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.navigation.NavType
import com.feslihan.app.ui.screens.home.HomeScreen
import com.feslihan.app.ui.screens.placeholder.ComingSoonScreen
import com.feslihan.app.ui.screens.recipes.RecipeListScreen

/**
 * Top-level navigation graph. The home hub (ModeSelectionView parity) routes to
 * the five app modes plus social/settings. Screens not yet ported render a
 * DS-styled "coming soon" placeholder so the graph is complete and navigable;
 * each is replaced by its real screen as that task lands.
 */
@Composable
fun FeslihanNavGraph(navController: NavHostController = rememberNavController()) {
    NavHost(navController = navController, startDestination = Routes.HOME) {

        composable(Routes.HOME) {
            HomeScreen(
                onOpenMode = { route -> navController.navigate(route) },
                onOpenSettings = { navController.navigate(Routes.SETTINGS) },
            )
        }

        // Mode 3 — Tariflerim (real screen)
        composable(Routes.RECIPE_LIST) {
            RecipeListScreen(
                onBack = { navController.popBackStack() },
                onAddRecipe = { navController.navigate(Routes.ADD_RECIPE) },
                onOpenRecipe = { id -> navController.navigate(Routes.recipeDetail(id)) },
            )
        }

        // Detail routes take a recipeId argument.
        composable(
            route = "${Routes.RECIPE_DETAIL}/{recipeId}",
            arguments = listOf(navArgument("recipeId") { type = NavType.StringType }),
        ) { backStackEntry ->
            val id = backStackEntry.arguments?.getString("recipeId").orEmpty()
            ComingSoonScreen(title = "Tarif Detayı", onBack = { navController.popBackStack() })
            // TODO(task 6): RecipeDetailScreen(recipeId = id, ...)
        }
        composable(
            route = "${Routes.COOKING_MODE}/{recipeId}",
            arguments = listOf(navArgument("recipeId") { type = NavType.StringType }),
        ) {
            ComingSoonScreen(title = "Pişirme Modu", onBack = { navController.popBackStack() })
        }

        // Placeholders — replaced as each task lands.
        placeholder(Routes.MEAL_PREP, "Haftalık Plan", navController)
        placeholder(Routes.SAVED_MEAL_PLANS, "Kayıtlı Planlar", navController)
        placeholder(Routes.WHAT_TO_EAT, "Ne Yesem?", navController)
        placeholder(Routes.ADD_RECIPE, "Tarif Ekle", navController)
        placeholder(Routes.PANTRY, "Kilerim", navController)
        placeholder(Routes.SHOPPING_LIST, "Alışveriş Listesi", navController)
        placeholder(Routes.FRIENDS, "Arkadaşlar", navController)
        placeholder(Routes.SHARED_INBOX, "Gelen Tarifler", navController)
        placeholder(Routes.SETTINGS, "Ayarlar", navController)
        placeholder(Routes.PAYWALL, "Feslihan'ı Yükselt", navController)
        placeholder(Routes.ONBOARDING, "Hoş Geldin", navController)
        placeholder(Routes.SPLASH, "Feslihan", navController)
    }
}

private fun androidx.navigation.NavGraphBuilder.placeholder(
    route: String,
    title: String,
    navController: NavHostController,
) {
    composable(route) {
        ComingSoonScreen(title = title, onBack = { navController.popBackStack() })
    }
}
