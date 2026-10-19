package com.feslihan.app.ui.screens.recipes

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.feslihan.app.data.model.Recipe
import com.feslihan.app.ui.components.FeslihanCard
import com.feslihan.app.ui.components.FeslihanTopBar
import com.feslihan.app.ui.theme.ds

/**
 * Tariflerim — the saved-recipe library (iOS RecipeListView). Offline-first list
 * from Room, pull-refreshed from the backend. FAB opens "Tarif Ekle".
 */
@Composable
fun RecipeListScreen(
    onBack: () -> Unit,
    onAddRecipe: () -> Unit,
    onOpenRecipe: (String) -> Unit,
    viewModel: RecipeListViewModel = hiltViewModel(),
) {
    val recipes by viewModel.recipes.collectAsStateWithLifecycle()
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        containerColor = MaterialTheme.ds.cream,
        topBar = { FeslihanTopBar(title = "Tariflerim", onBack = onBack) },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = onAddRecipe,
                containerColor = MaterialTheme.ds.ember,
                contentColor = androidx.compose.ui.graphics.Color.White,
                icon = { Icon(Icons.Default.Add, contentDescription = null) },
                text = { Text("Tarif Ekle") },
            )
        },
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when {
                recipes.isEmpty() && uiState.isRefreshing -> {
                    CircularProgressIndicator(
                        color = MaterialTheme.ds.ember,
                        modifier = Modifier.align(Alignment.Center),
                    )
                }
                recipes.isEmpty() -> {
                    EmptyLibrary(error = uiState.error, modifier = Modifier.align(Alignment.Center))
                }
                else -> {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize().padding(horizontal = 20.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        item { androidx.compose.foundation.layout.Spacer(Modifier.padding(top = 4.dp)) }
                        items(recipes, key = { it.id ?: it.title }) { recipe ->
                            RecipeRow(
                                recipe = recipe,
                                onClick = { recipe.id?.let(onOpenRecipe) },
                                onToggleFavorite = { viewModel.toggleFavorite(recipe) },
                            )
                        }
                        item { androidx.compose.foundation.layout.Spacer(Modifier.padding(bottom = 80.dp)) }
                    }
                }
            }
        }
    }
}

@Composable
private fun RecipeRow(recipe: Recipe, onClick: () -> Unit, onToggleFavorite: () -> Unit) {
    FeslihanCard(modifier = Modifier.fillMaxWidth(), onClick = onClick) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = recipe.title,
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.ds.ink,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                val meta = buildList {
                    recipe.cookingTimeMinutes?.let { add("$it dk") }
                    recipe.servings?.let { add("$it porsiyon") }
                    recipe.caloriesPerServingKcal?.let { add("${it.toInt()} kcal") }
                }.joinToString(" · ")
                if (meta.isNotEmpty()) {
                    Text(
                        text = meta,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.ds.smoke,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }
            IconButton(onClick = onToggleFavorite) {
                val fav = recipe.isFavorite == true
                Icon(
                    imageVector = if (fav) Icons.Default.Favorite else Icons.Default.FavoriteBorder,
                    contentDescription = if (fav) "Favoriden çıkar" else "Favoriye ekle",
                    tint = if (fav) MaterialTheme.ds.tomato else MaterialTheme.ds.dust,
                )
            }
        }
    }
}

@Composable
private fun EmptyLibrary(error: String?, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("📒", style = MaterialTheme.typography.headlineLarge)
        Text(
            text = error ?: "Henüz tarif yok",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.ds.ink,
            modifier = Modifier.padding(top = 12.dp),
        )
        Text(
            text = "Bir tarif linki yapıştır, defterine eklensin.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.ds.smoke,
            modifier = Modifier.padding(top = 6.dp),
        )
    }
}
