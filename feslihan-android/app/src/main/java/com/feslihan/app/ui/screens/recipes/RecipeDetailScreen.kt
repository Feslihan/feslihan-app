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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.feslihan.app.ui.components.Chip
import com.feslihan.app.ui.components.FoodBlock
import com.feslihan.app.ui.components.StatusDot
import com.feslihan.app.ui.components.Availability
import com.feslihan.app.ui.theme.DisplayHeroTextStyle
import com.feslihan.app.ui.theme.ds

private val TABS = listOf("Malzemeler", "Yapılış", "Besin")

/** Tarif Detayı (iOS ScrRecipeDetail). Hero photo, creator, portions, tabs, dots. */
@Composable
fun RecipeDetailScreen(
    onBack: () -> Unit,
    onStartCooking: (String) -> Unit,
    viewModel: RecipeDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var tab by remember { mutableIntStateOf(0) }
    var portion by remember { mutableIntStateOf(1) }
    var showShare by remember { mutableStateOf(false) }
    val context = androidx.compose.ui.platform.LocalContext.current

    val recipe = state.recipe
    Box(modifier = Modifier.fillMaxSize().background(MaterialTheme.ds.cream)) {
        when {
            state.isLoading -> CircularProgressIndicator(color = MaterialTheme.ds.ember, modifier = Modifier.align(Alignment.Center))
            recipe == null -> Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(state.error ?: "Tarif bulunamadı", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.smoke)
                Spacer(Modifier.height(10.dp))
                Text("Geri", color = MaterialTheme.ds.ember, modifier = Modifier.clickable(onClick = onBack))
            }
            else -> {
                Column(Modifier.fillMaxSize()) {
                    Column(Modifier.weight(1f).verticalScroll(rememberScrollState())) {
                        // Hero
                        FoodBlock(seed = recipe.title, corner = 0, modifier = Modifier.fillMaxWidth().height(320.dp)) {
                            CircleIcon(Icons.AutoMirrored.Filled.ArrowBack, "Geri",
                                Modifier.align(Alignment.TopStart).padding(start = 20.dp, top = 52.dp), onBack)
                            Row(Modifier.align(Alignment.TopEnd).padding(end = 20.dp, top = 52.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                if (recipe.id != null) CircleIcon(Icons.Default.Share, "Tarif Gönder", Modifier) { showShare = true }
                                CircleIcon(Icons.Default.Favorite, "Favori", Modifier) {}
                            }
                            Column(Modifier.align(Alignment.BottomStart).padding(22.dp)) {
                                Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                                    recipe.cuisine?.let { HeroChip(it) }
                                    recipe.cookingTimeMinutes?.let { HeroChip("$it dk") }
                                }
                                Spacer(Modifier.height(12.dp))
                                Text(recipe.title, style = DisplayHeroTextStyle, color = Color.White)
                            }
                        }

                        // Creator row
                        recipe.platformUser?.let { user ->
                            Row(Modifier.fillMaxWidth().padding(horizontal = 22.dp, vertical = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                                Box(Modifier.size(32.dp).background(MaterialTheme.ds.ink, CircleShape), contentAlignment = Alignment.Center) {
                                    Text(user.take(2).uppercase(), color = Color.White, style = MaterialTheme.typography.bodySmall)
                                }
                                Spacer(Modifier.size(10.dp))
                                Text("@$user", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.ds.ink, modifier = Modifier.weight(1f))
                                Icon(Icons.Default.PlayArrow, contentDescription = null, tint = MaterialTheme.ds.ink)
                            }
                        }

                        // Portion stepper
                        Row(Modifier.fillMaxWidth().padding(horizontal = 22.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text("Porsiyon", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.ds.smoke, modifier = Modifier.weight(1f))
                            Row(Modifier.border(1.dp, MaterialTheme.ds.stone, RoundedCornerShape(8.dp))) {
                                listOf("½", "1x", "2x", "4x", "6x").forEachIndexed { i, s ->
                                    Box(
                                        Modifier.size(width = 44.dp, height = 32.dp)
                                            .background(if (i == portion) MaterialTheme.ds.ink else Color.Transparent)
                                            .clickable { portion = i },
                                        contentAlignment = Alignment.Center,
                                    ) { Text(s, style = MaterialTheme.typography.bodySmall, color = if (i == portion) Color.White else MaterialTheme.ds.ink) }
                                }
                            }
                        }

                        // Tabs
                        Row(Modifier.fillMaxWidth().padding(start = 22.dp, end = 22.dp, top = 20.dp), horizontalArrangement = Arrangement.spacedBy(24.dp)) {
                            TABS.forEachIndexed { i, t ->
                                Column(Modifier.clickable { tab = i }) {
                                    Text(t, style = MaterialTheme.typography.titleMedium,
                                        color = if (i == tab) MaterialTheme.ds.ink else MaterialTheme.ds.dust)
                                    Spacer(Modifier.height(8.dp))
                                    Box(Modifier.height(2.dp).size(width = 56.dp, height = 2.dp)
                                        .background(if (i == tab) MaterialTheme.ds.ink else Color.Transparent))
                                }
                            }
                        }
                        Box(Modifier.fillMaxWidth().height(1.dp).background(MaterialTheme.ds.stone))

                        // Tab content
                        when (tab) {
                            0 -> IngredientsTab(state)
                            1 -> Text(recipe.description, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.ink,
                                modifier = Modifier.padding(22.dp))
                            else -> NutritionTab(recipe.caloriesPerServingKcal, recipe.proteinGrams, recipe.carbsGrams, recipe.fatGrams)
                        }
                        Spacer(Modifier.height(16.dp))
                    }

                    // Bottom bar
                    Row(
                        Modifier.fillMaxWidth().background(MaterialTheme.ds.cream)
                            .border(1.dp, MaterialTheme.ds.stone).padding(horizontal = 22.dp, vertical = 12.dp),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        Row(
                            Modifier.weight(1.6f).height(50.dp).background(MaterialTheme.ds.ember, RoundedCornerShape(8.dp))
                                .clickable { recipe.id?.let(onStartCooking) },
                            horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(Icons.Default.LocalFireDepartment, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
                            Spacer(Modifier.size(8.dp))
                            Text("Pişirmeye Başla", color = Color.White, style = MaterialTheme.typography.labelMedium)
                        }
                        Row(
                            Modifier.weight(1f).height(50.dp).border(1.dp, MaterialTheme.ds.ink, RoundedCornerShape(8.dp)),
                            horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(Icons.Default.PlayArrow, contentDescription = null, tint = MaterialTheme.ds.ink, modifier = Modifier.size(16.dp))
                            Spacer(Modifier.size(6.dp))
                            Text("Video", color = MaterialTheme.ds.ink, style = MaterialTheme.typography.labelMedium)
                        }
                    }
                }

                if (showShare && recipe.id != null) {
                    com.feslihan.app.ui.screens.social.FriendPickerSheet(
                        recipeId = recipe.id,
                        onDismiss = { showShare = false },
                        onResult = { msg ->
                            android.widget.Toast.makeText(context, msg, android.widget.Toast.LENGTH_SHORT).show()
                            showShare = false
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun IngredientsTab(state: RecipeDetailUiState) {
    Column(Modifier.padding(horizontal = 22.dp)) {
        state.ingredients.forEachIndexed { i, line ->
            Row(Modifier.fillMaxWidth().height(44.dp), verticalAlignment = Alignment.CenterVertically) {
                StatusDot(line.availability)
                Spacer(Modifier.size(12.dp))
                Text(line.measure.name, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.ink, modifier = Modifier.weight(1f))
                Text(line.measure.amount, style = MaterialTheme.typography.bodyMedium.copy(fontSize = 14.sp), color = MaterialTheme.ds.smoke)
            }
            if (i < state.ingredients.size - 1) Box(Modifier.fillMaxWidth().height(1.dp).background(MaterialTheme.ds.stone))
        }
        Row(Modifier.padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            Legend(Availability.Have, "Var"); Legend(Availability.Maybe, "Belki"); Legend(Availability.Need, "Almalı")
        }
    }
}

@Composable
private fun Legend(state: Availability, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        StatusDot(state); Spacer(Modifier.size(6.dp))
        Text(label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.ds.smoke)
    }
}

@Composable
private fun NutritionTab(kcal: Double?, protein: Double?, carbs: Double?, fat: Double?) {
    Column(Modifier.padding(22.dp)) {
        NutritionRow("Kalori (porsiyon)", kcal?.let { "${it.toInt()} kcal" })
        NutritionRow("Protein", protein?.let { "${it.toInt()} g" })
        NutritionRow("Karbonhidrat", carbs?.let { "${it.toInt()} g" })
        NutritionRow("Yağ", fat?.let { "${it.toInt()} g" })
    }
}

@Composable
private fun NutritionRow(label: String, value: String?) {
    Row(Modifier.fillMaxWidth().height(44.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.ink, modifier = Modifier.weight(1f))
        Text(value ?: "—", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.smoke)
    }
}

@Composable
private fun HeroChip(text: String) {
    Box(Modifier.border(1.dp, Color.White.copy(alpha = 0.7f), CircleShape).padding(horizontal = 13.dp, vertical = 6.dp)) {
        Text(text, style = MaterialTheme.typography.labelLarge, color = Color.White)
    }
}

@Composable
private fun CircleIcon(icon: androidx.compose.ui.graphics.vector.ImageVector, desc: String, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier = modifier.size(38.dp).background(Color.White, CircleShape).clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { Icon(icon, contentDescription = desc, tint = MaterialTheme.ds.ink, modifier = Modifier.size(18.dp)) }
}
