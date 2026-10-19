package com.feslihan.app.ui.screens.social

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.feslihan.app.data.model.Recipe
import com.feslihan.app.ui.components.BackButton
import com.feslihan.app.ui.components.FoodBlock
import com.feslihan.app.ui.theme.DisplayXLTextStyle
import com.feslihan.app.ui.theme.ds

/**
 * A friend's saved recipes (iOS FriendRecipesView). Two-column grid of food-block
 * cards; tapping opens the shared recipe detail. Backend gates this on an accepted
 * connection (403 otherwise → error state).
 */
@Composable
fun FriendRecipesScreen(
    onBack: () -> Unit,
    onOpenRecipe: (recipeId: String) -> Unit,
    viewModel: FriendRecipesViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(containerColor = MaterialTheme.ds.cream) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(start = 18.dp, end = 18.dp, top = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                BackButton(onClick = onBack)
                Spacer(Modifier.size(4.dp))
                Text(state.friendName, style = DisplayXLTextStyle.copy(fontSize = 26.sp), color = MaterialTheme.ds.ink,
                    maxLines = 1, overflow = TextOverflow.Ellipsis)
            }

            when {
                state.isLoading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = MaterialTheme.ds.ember)
                }
                state.recipes.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text(state.error ?: "Henüz kayıtlı tarif yok", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.smoke)
                }
                else -> LazyVerticalGrid(
                    columns = GridCells.Fixed(2),
                    modifier = Modifier.fillMaxSize().padding(horizontal = 22.dp),
                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = 16.dp),
                ) {
                    items(state.recipes, key = { it.id ?: it.title }) { recipe ->
                        FriendRecipeCard(recipe = recipe, onClick = { recipe.id?.let(onOpenRecipe) })
                    }
                }
            }
        }
    }
}

@Composable
private fun FriendRecipeCard(recipe: Recipe, onClick: () -> Unit) {
    Column(modifier = Modifier.fillMaxWidth().clickable(onClick = onClick)) {
        FoodBlock(seed = recipe.title, modifier = Modifier.fillMaxWidth().aspectRatio(1.3f))
        Text(
            recipe.title,
            style = MaterialTheme.typography.titleMedium.copy(fontSize = 15.sp),
            color = MaterialTheme.ds.ink,
            maxLines = 2, overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 8.dp),
        )
        recipe.cookingTimeMinutes?.let {
            Text("$it dk", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.ds.dust, modifier = Modifier.padding(top = 2.dp))
        }
    }
}
