package com.feslihan.app.ui.screens.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Checklist
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.feslihan.app.R
import com.feslihan.app.ui.components.Eyebrow
import com.feslihan.app.ui.components.FeslihanCard
import com.feslihan.app.ui.navigation.Routes
import com.feslihan.app.ui.theme.ds

private data class Mode(
    val titleRes: Int,
    val subtitle: String,
    val icon: ImageVector,
    val route: String,
    val premium: Boolean = false,
)

/**
 * Home hub (iOS ModeSelectionView). The five app modes; Haftalık Plan carries the
 * premium crown badge. Editorial list of hairline cards, no shadows.
 */
@Composable
fun HomeScreen(onOpenMode: (String) -> Unit, onOpenSettings: () -> Unit) {
    val modes = listOf(
        Mode(R.string.mode_meal_prep, "Haftalık yemek planı ve alışveriş listesi", Icons.Default.CalendarMonth, Routes.MEAL_PREP, premium = true),
        Mode(R.string.mode_what_to_eat, "Kilerindekine göre bu akşam ne pişsin?", Icons.Default.Restaurant, Routes.WHAT_TO_EAT),
        Mode(R.string.mode_my_recipes, "Kaydettiğin tariflerin defteri", Icons.Default.MenuBook, Routes.RECIPE_LIST),
        Mode(R.string.mode_pantry, "Evde ne var ne yok", Icons.Default.Inventory2, Routes.PANTRY),
        Mode(R.string.mode_shopping_list, "Eksik malzemeler tek listede", Icons.Default.Checklist, Routes.SHOPPING_LIST),
    )

    Scaffold(containerColor = MaterialTheme.ds.cream) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding).padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(top = 24.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Eyebrow("Annenin yemek defteri")
                        Text(
                            text = "Feslihan",
                            style = MaterialTheme.typography.headlineLarge,
                            color = MaterialTheme.ds.ink,
                            modifier = Modifier.padding(top = 4.dp),
                        )
                    }
                    IconButton(onClick = onOpenSettings) {
                        Icon(Icons.Default.Settings, contentDescription = "Ayarlar", tint = MaterialTheme.ds.smoke)
                    }
                }
                Spacer(Modifier.height(8.dp))
            }

            items(modes) { mode ->
                ModeCard(mode = mode, onClick = { onOpenMode(mode.route) })
            }

            item { Spacer(Modifier.height(24.dp)) }
        }
    }
}

@Composable
private fun ModeCard(mode: Mode, onClick: () -> Unit) {
    FeslihanCard(modifier = Modifier.fillMaxWidth(), onClick = onClick) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = mode.icon,
                contentDescription = null,
                tint = MaterialTheme.ds.ember,
                modifier = Modifier.size(28.dp),
            )
            Column(modifier = Modifier.weight(1f).padding(start = 14.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = androidx.compose.ui.res.stringResource(mode.titleRes),
                        style = MaterialTheme.typography.titleLarge,
                        color = MaterialTheme.ds.ink,
                    )
                    if (mode.premium) {
                        Spacer(Modifier.size(6.dp))
                        PremiumBadge()
                    }
                }
                Text(
                    text = mode.subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.ds.smoke,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
        }
    }
}

@Composable
private fun PremiumBadge() {
    Row(
        modifier = Modifier
            .padding(start = 2.dp)
            .height(20.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = Icons.Default.WorkspacePremium,
            contentDescription = "Premium",
            tint = MaterialTheme.ds.ember,
            modifier = Modifier.size(16.dp),
        )
    }
}
