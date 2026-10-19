package com.feslihan.app.ui.screens.home

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.ShoppingBasket
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.feslihan.app.ui.components.Eyebrow
import com.feslihan.app.ui.components.FoodBlock
import com.feslihan.app.ui.components.PlusBadge
import com.feslihan.app.ui.navigation.Routes
import com.feslihan.app.ui.theme.DisplayXLTextStyle
import com.feslihan.app.ui.theme.HandwrittenTextStyle
import com.feslihan.app.ui.theme.ds

/**
 * Home hub (iOS ScrHome). Greeting, a featured food-card for Haftalık Plan,
 * numbered mode rows for Ne Yesem? / Tariflerim, and a "Mutfak" section with
 * Kilerim / Alışveriş count cards. Matches the design closely.
 */
@Composable
fun HomeScreen(
    onOpenMode: (String) -> Unit,
    onOpenSettings: () -> Unit,
    viewModel: HomeViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(containerColor = MaterialTheme.ds.cream) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding).padding(horizontal = 22.dp),
        ) {
            item {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Wordmark(modifier = Modifier.weight(1f))
                    androidx.compose.material3.IconButton(onClick = { onOpenMode(Routes.FRIENDS) }) {
                        Icon(Icons.Default.Group, contentDescription = "Arkadaşlar", tint = MaterialTheme.ds.ink)
                    }
                    Spacer(Modifier.size(2.dp))
                    Avatar(initial = "N", onClick = onOpenSettings)
                }
                Spacer(Modifier.height(30.dp))
                Text("İyi akşamlar,", style = HandwrittenTextStyle, color = MaterialTheme.ds.smoke)
                Text(
                    "Merhaba,\nNeslihan",
                    style = DisplayXLTextStyle.copy(fontSize = 34.sp, lineHeight = 38.sp),
                    color = MaterialTheme.ds.ink,
                    modifier = Modifier.padding(top = 6.dp),
                )
                Spacer(Modifier.height(22.dp))
            }

            // Featured — Haftalık Plan
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onOpenMode(Routes.MEAL_PREP) }
                        .padding(bottom = 18.dp),
                ) {
                    FoodBlock(seed = "salata", brush = com.feslihan.app.ui.components.BasilGradient, modifier = Modifier.fillMaxWidth().height(112.dp)) {
                        Text("01", color = Color.White, style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.align(Alignment.TopStart).padding(14.dp))
                        Icon(Icons.Default.CalendarMonth, contentDescription = null, tint = Color.White,
                            modifier = Modifier.align(Alignment.TopEnd).padding(14.dp).size(22.dp))
                    }
                    Row(modifier = Modifier.padding(top = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text("Haftalık Plan", style = MaterialTheme.typography.headlineMedium.copy(fontSize = 26.sp), color = MaterialTheme.ds.ink)
                        Spacer(Modifier.size(10.dp))
                        PlusBadge()
                    }
                    Text("Bir haftalık yemek planı hazırla", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.smoke)
                }
                HairlineDivider()
            }

            item {
                ModeRow("02", Icons.Outlined.AutoAwesome, MaterialTheme.ds.tomato, "Ne Yesem?",
                    "Sana özel tarif önerileri keşfet") { onOpenMode(Routes.WHAT_TO_EAT) }
            }
            item {
                ModeRow("03", Icons.Default.MenuBook, MaterialTheme.ds.honeyInk, "Tariflerim",
                    "Kaydettiğin tüm tarifler") { onOpenMode(Routes.RECIPE_LIST) }
            }

            item {
                Eyebrow("Mutfak", modifier = Modifier.padding(top = 26.dp, bottom = 4.dp))
                Row(modifier = Modifier.fillMaxWidth().height(96.dp)) {
                    UtilCard(
                        title = "Kilerim", icon = Icons.Default.Inventory2, color = MaterialTheme.ds.eggplant,
                        count = state.pantryCount?.toString() ?: "—", unit = "malzeme", first = true,
                        modifier = Modifier.weight(1f).clickable { onOpenMode(Routes.PANTRY) },
                    )
                    UtilCard(
                        title = "Alışveriş", icon = Icons.Default.ShoppingBasket, color = MaterialTheme.ds.tomato,
                        count = state.shoppingCount?.toString() ?: "—", unit = "eksik ürün", first = false,
                        modifier = Modifier.weight(1f).clickable { onOpenMode(Routes.SHOPPING_LIST) },
                    )
                }
                Spacer(Modifier.height(28.dp))
            }
        }
    }
}

@Composable
private fun Wordmark(modifier: Modifier = Modifier) {
    Row(modifier = modifier, verticalAlignment = Alignment.CenterVertically) {
        LeafMark(size = 18)
        Spacer(Modifier.size(7.dp))
        Text("Feslihan", style = MaterialTheme.typography.headlineMedium.copy(fontSize = 20.sp), color = MaterialTheme.ds.ink)
    }
}

@Composable
private fun Avatar(initial: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier.size(34.dp).background(MaterialTheme.ds.ink, CircleShape).clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(initial, color = Color.White, style = MaterialTheme.typography.labelLarge)
    }
}

@Composable
private fun ModeRow(n: String, icon: ImageVector, color: Color, title: String, desc: String, onClick: () -> Unit) {
    Column(Modifier.fillMaxWidth().clickable(onClick = onClick)) {
        Row(modifier = Modifier.fillMaxWidth().padding(vertical = 18.dp), verticalAlignment = Alignment.Top) {
            Text(n, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.ds.dust,
                modifier = Modifier.width(20.dp).padding(top = 6.dp))
            Column(Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.headlineMedium.copy(fontSize = 22.sp), color = MaterialTheme.ds.ink)
                Text(desc, style = MaterialTheme.typography.bodyMedium.copy(fontSize = 14.sp), color = MaterialTheme.ds.smoke,
                    modifier = Modifier.padding(top = 2.dp))
            }
            Icon(icon, contentDescription = null, tint = color, modifier = Modifier.padding(top = 4.dp).size(22.dp))
        }
        HairlineDivider()
    }
}

@Composable
private fun UtilCard(
    title: String, icon: ImageVector, color: Color, count: String, unit: String, first: Boolean,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .then(if (!first) Modifier.border(0.dp, Color.Transparent) else Modifier)
            .padding(start = if (first) 0.dp else 16.dp, end = if (first) 16.dp else 0.dp, top = 16.dp),
    ) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(title, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.ds.ink, modifier = Modifier.weight(1f))
            Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(18.dp))
        }
        Row(modifier = Modifier.padding(top = 10.dp), verticalAlignment = Alignment.Bottom) {
            Text(count, style = DisplayXLTextStyle.copy(fontSize = 32.sp, lineHeight = 32.sp), color = color)
            Spacer(Modifier.size(6.dp))
            Text(unit, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.ds.smoke, modifier = Modifier.padding(bottom = 3.dp))
        }
    }
}

@Composable
private fun HairlineDivider() {
    Box(Modifier.fillMaxWidth().height(1.dp).background(MaterialTheme.ds.stone))
}

/** Basil leaf brand mark (matches the SVG leaf in the design/web). */
@Composable
fun LeafMark(size: Int, tint: Color = MaterialTheme.ds.ember) {
    Box(
        modifier = Modifier.size(size.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text("🌿", fontSize = (size - 2).sp)
    }
}
