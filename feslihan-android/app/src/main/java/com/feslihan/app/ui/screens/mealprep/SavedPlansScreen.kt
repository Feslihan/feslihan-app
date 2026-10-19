package com.feslihan.app.ui.screens.mealprep

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Add
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.feslihan.app.data.model.SavedPlan
import com.feslihan.app.ui.components.BackButton
import com.feslihan.app.ui.components.FoodBlock
import com.feslihan.app.ui.theme.DisplayXLTextStyle
import com.feslihan.app.ui.theme.HandwrittenTextStyle
import com.feslihan.app.ui.theme.ds

/** Kayıtlı Planlar (iOS ScrSavedPlans). List of saved weekly plans. */
@Composable
fun SavedPlansScreen(
    onBack: () -> Unit,
    onNewPlan: () -> Unit,
    viewModel: SavedPlansViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(containerColor = MaterialTheme.ds.cream) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).padding(horizontal = 22.dp)) {
            Spacer(Modifier.size(6.dp))
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                BackButton(onClick = onBack)
                Spacer(Modifier.size(4.dp))
                Text("Planlarım", style = DisplayXLTextStyle.copy(fontSize = 30.sp), color = MaterialTheme.ds.ink, modifier = Modifier.weight(1f))
                Box(Modifier.size(42.dp).background(MaterialTheme.ds.ember, CircleShape).clickable(onClick = onNewPlan), contentAlignment = Alignment.Center) {
                    Icon(Icons.Default.Add, contentDescription = "Yeni Plan", tint = Color.White, modifier = Modifier.size(22.dp))
                }
            }
            Spacer(Modifier.size(14.dp))
            when {
                state.isLoading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = MaterialTheme.ds.ember) }
                state.plans.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text(state.error ?: "Henüz kayıtlı plan yok.", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.smoke)
                }
                else -> LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    items(state.plans, key = { it.id }) { plan -> PlanRow(plan) }
                    item {
                        Text("Sevdiğin planları tekrar tekrar pişirebilirsin.", style = HandwrittenTextStyle,
                            color = MaterialTheme.ds.smoke, modifier = Modifier.fillMaxWidth().padding(top = 6.dp),
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                    }
                }
            }
        }
    }
}

@Composable
private fun PlanRow(plan: SavedPlan) {
    Row(
        Modifier.fillMaxWidth().border(1.dp, MaterialTheme.ds.stone, RoundedCornerShape(8.dp)).padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        FoodBlock(seed = plan.name, corner = 12, modifier = Modifier.size(64.dp))
        Column(Modifier.weight(1f).padding(start = 13.dp)) {
            Text(plan.name.ifBlank { "Haftalık Plan" }, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.ds.ink)
            Text("${plan.recipeIds.size} tarif", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.ds.smoke, modifier = Modifier.padding(top = 6.dp))
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = MaterialTheme.ds.dust)
    }
}
