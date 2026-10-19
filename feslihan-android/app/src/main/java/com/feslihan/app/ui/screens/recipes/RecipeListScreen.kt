package com.feslihan.app.ui.screens.recipes

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.feslihan.app.data.model.Recipe
import com.feslihan.app.ui.components.Chip
import com.feslihan.app.ui.components.FoodBlock
import com.feslihan.app.ui.theme.DisplayXLTextStyle
import com.feslihan.app.ui.theme.HandwrittenTextStyle
import com.feslihan.app.ui.theme.ds

private val FILTERS = listOf("Tümü", "Çorbalar", "Ana Yemek", "Tatlılar", "Kahvaltı", "Hamur İşi")

/**
 * Tariflerim (iOS ScrRecipeList). Oversized serif title + filter affordance,
 * search field, category chip row, then a 2-column grid of food-card recipes.
 * Dark square FAB; editorial empty state.
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

    Scaffold(containerColor = MaterialTheme.ds.cream) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            if (recipes.isEmpty() && !uiState.isRefreshing) {
                EmptyLibrary(onAddRecipe = onAddRecipe)
            } else {
                LazyVerticalGrid(
                    columns = GridCells.Fixed(2),
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(start = 22.dp, end = 22.dp, bottom = 100.dp),
                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                    verticalArrangement = Arrangement.spacedBy(22.dp),
                ) {
                    item(span = { GridItemSpan(2) }) { Header() }
                    if (recipes.isEmpty() && uiState.isRefreshing) {
                        item(span = { GridItemSpan(2) }) {
                            Box(Modifier.fillMaxWidth().height(200.dp), contentAlignment = Alignment.Center) {
                                CircularProgressIndicator(color = MaterialTheme.ds.ember)
                            }
                        }
                    }
                    items(recipes, key = { it.id ?: it.title }) { recipe ->
                        RecipeCard(recipe = recipe, onClick = { recipe.id?.let(onOpenRecipe) })
                    }
                }
            }

            // Dark square FAB (design)
            Box(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(22.dp)
                    .size(56.dp)
                    .background(MaterialTheme.ds.ink, RoundedCornerShape(8.dp))
                    .clickable(onClick = onAddRecipe),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Default.Add, contentDescription = "Tarif Ekle", tint = Color.White, modifier = Modifier.size(24.dp))
            }
        }
    }
}

@Composable
private fun Header() {
    Column(Modifier.fillMaxWidth()) {
        Spacer(Modifier.height(26.dp))
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
            Text("Tariflerim", style = DisplayXLTextStyle, color = MaterialTheme.ds.ink, modifier = Modifier.weight(1f))
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(bottom = 6.dp)) {
                Icon(Icons.Default.Tune, contentDescription = "Filtre", tint = MaterialTheme.ds.ink, modifier = Modifier.size(18.dp))
                Spacer(Modifier.size(6.dp))
                Text("Filtre", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.ds.ink)
            }
        }
        Spacer(Modifier.height(16.dp))
        // search field
        Row(
            modifier = Modifier.fillMaxWidth().height(46.dp)
                .border(1.dp, MaterialTheme.ds.stone, RoundedCornerShape(8.dp))
                .padding(horizontal = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Default.Search, contentDescription = null, tint = MaterialTheme.ds.dust, modifier = Modifier.size(18.dp))
            Spacer(Modifier.size(10.dp))
            Text("Tarif ara...", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.dust)
        }
        Spacer(Modifier.height(14.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FILTERS.take(3).forEachIndexed { i, f -> Chip(text = f, active = i == 0) }
        }
        Spacer(Modifier.height(4.dp))
    }
}

@Composable
private fun RecipeCard(recipe: Recipe, onClick: () -> Unit) {
    Column(Modifier.clickable(onClick = onClick)) {
        FoodBlock(seed = recipe.title, modifier = Modifier.fillMaxWidth().height(112.dp)) {
            Icon(Icons.Default.Favorite, contentDescription = null,
                tint = if (recipe.isFavorite == true) Color.White else Color.White.copy(alpha = 0.85f),
                modifier = Modifier.align(Alignment.TopEnd).padding(10.dp).size(17.dp))
        }
        Text(recipe.title, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.ds.ink,
            maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(top = 9.dp))
        Row(modifier = Modifier.fillMaxWidth().padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(recipe.cookingTimeMinutes?.let { "$it dk" } ?: "", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.ds.smoke)
            Spacer(Modifier.weight(1f))
            DifficultyDots(recipe.difficulty)
        }
    }
}

@Composable
private fun DifficultyDots(difficulty: String?) {
    val level = when (difficulty) { "low" -> 1; "medium" -> 2; "high" -> 3; else -> 1 }
    Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
        (1..3).forEach { i ->
            Box(Modifier.size(5.dp).background(
                if (i <= level) MaterialTheme.ds.ink else MaterialTheme.ds.stone,
                androidx.compose.foundation.shape.CircleShape))
        }
    }
}

@Composable
private fun EmptyLibrary(onAddRecipe: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 22.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        Text("🍲", style = MaterialTheme.typography.headlineLarge)
        Text("Henüz tarif eklemediniz…", style = HandwrittenTextStyle.copy(fontSize = 22.sp),
            color = MaterialTheme.ds.smoke, modifier = Modifier.padding(top = 20.dp))
        Text("Bir video linki yapıştır, gerisini Feslihan halletsin.",
            style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.smoke, modifier = Modifier.padding(top = 8.dp))
        Row(
            modifier = Modifier.padding(top = 26.dp)
                .background(MaterialTheme.ds.ember, RoundedCornerShape(8.dp))
                .clickable(onClick = onAddRecipe)
                .padding(horizontal = 22.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Default.Add, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
            Spacer(Modifier.size(8.dp))
            Text("İlk Tarifini Ekle", color = Color.White, style = MaterialTheme.typography.labelMedium)
        }
    }
}
