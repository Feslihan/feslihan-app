package com.feslihan.app.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.navigation.NavType
import com.feslihan.app.ui.screens.addrecipe.AddRecipeScreen
import com.feslihan.app.ui.screens.home.HomeScreen
import com.feslihan.app.ui.screens.mealprep.MealPrepScreen
import com.feslihan.app.ui.screens.mealprep.SavedPlansScreen
import com.feslihan.app.ui.screens.neyesem.NeYesemScreen
import com.feslihan.app.ui.screens.pantry.PantryScreen
import com.feslihan.app.ui.screens.placeholder.ComingSoonScreen
import com.feslihan.app.ui.screens.recipes.CookingModeScreen
import com.feslihan.app.ui.screens.recipes.RecipeDetailScreen
import com.feslihan.app.ui.screens.recipes.RecipeListScreen
import com.feslihan.app.ui.screens.shopping.ShoppingListScreen
import com.feslihan.app.ui.screens.social.FriendRecipesScreen
import com.feslihan.app.ui.screens.social.FriendsScreen
import com.feslihan.app.ui.screens.social.SharedInboxScreen

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
        ) {
            RecipeDetailScreen(
                onBack = { navController.popBackStack() },
                onStartCooking = { id -> navController.navigate(Routes.cookingMode(id)) },
            )
        }
        composable(
            route = "${Routes.COOKING_MODE}/{recipeId}",
            arguments = listOf(navArgument("recipeId") { type = NavType.StringType }),
        ) {
            CookingModeScreen(onClose = { navController.popBackStack() })
        }

        // Mode 4 — Kilerim (real screen)
        composable(Routes.PANTRY) {
            PantryScreen(onBack = { navController.popBackStack() })
        }

        // Mode 5 — Alışveriş Listesi (real screen)
        composable(Routes.SHOPPING_LIST) {
            ShoppingListScreen(onBack = { navController.popBackStack() })
        }

        // Mode 1 — Haftalık Plan (wizard → result)
        composable(Routes.MEAL_PREP) {
            MealPrepScreen(
                onClose = { navController.popBackStack() },
                onOpenPaywall = { navController.navigate(Routes.PAYWALL) },
            )
        }
        composable(Routes.SAVED_MEAL_PLANS) {
            SavedPlansScreen(
                onBack = { navController.popBackStack() },
                onNewPlan = { navController.navigate(Routes.MEAL_PREP) },
            )
        }

        // Mode 2 — Ne Yesem? (wizard → swipe deck)
        composable(Routes.WHAT_TO_EAT) {
            NeYesemScreen(onClose = { navController.popBackStack() })
        }

        // Tarif Ekle
        composable(Routes.ADD_RECIPE) {
            AddRecipeScreen(onClose = { navController.popBackStack() })
        }
        // Social — Arkadaşlar hub, friend recipe browsing, shared-recipe inbox
        composable(Routes.FRIENDS) {
            FriendsScreen(
                onBack = { navController.popBackStack() },
                onOpenFriend = { userId, name -> navController.navigate(Routes.friendRecipes(userId, name)) },
                onOpenInbox = { navController.navigate(Routes.SHARED_INBOX) },
            )
        }
        composable(
            route = "${Routes.FRIEND_RECIPES}/{userId}?name={name}",
            arguments = listOf(
                navArgument("userId") { type = NavType.StringType },
                navArgument("name") { type = NavType.StringType; defaultValue = "Arkadaş" },
            ),
        ) {
            FriendRecipesScreen(
                onBack = { navController.popBackStack() },
                onOpenRecipe = { id -> navController.navigate(Routes.recipeDetail(id)) },
            )
        }
        composable(Routes.SHARED_INBOX) {
            SharedInboxScreen(
                onBack = { navController.popBackStack() },
                onOpenRecipe = { id -> navController.navigate(Routes.recipeDetail(id)) },
            )
        }
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
