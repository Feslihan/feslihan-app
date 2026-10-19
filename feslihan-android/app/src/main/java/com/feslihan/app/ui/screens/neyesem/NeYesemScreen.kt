package com.feslihan.app.ui.screens.neyesem

import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.feslihan.app.data.model.Recipe
import com.feslihan.app.ui.components.Chip
import com.feslihan.app.ui.components.FoodBlock
import com.feslihan.app.ui.components.OptionCard
import com.feslihan.app.ui.components.WizardChrome
import com.feslihan.app.ui.theme.DisplayXLTextStyle
import com.feslihan.app.ui.theme.HandwrittenTextStyle
import com.feslihan.app.ui.theme.ds

/** Ne Yesem? (iOS ScrNeYesemWizard + ScrNeYesemSwipe) — a quick wizard then a swipe deck. */
@Composable
fun NeYesemScreen(onClose: () -> Unit, viewModel: NeYesemViewModel = hiltViewModel()) {
    val s by viewModel.state.collectAsStateWithLifecycle()
    when (s.phase) {
        NeYesemPhase.Wizard -> WizardChrome(
            step = 1, total = 1, title = "Ne kadar vaktin var?",
            sub = "Sana uygun tarifleri ona göre seçelim.", cta = "Önerileri Gör",
            enabled = s.timeChoice != null, onBack = onClose, onNext = { viewModel.start() },
        ) {
            OptionCard("Acelem var", s.timeChoice == "15", { viewModel.setTime("15") }, sub = "15 dakikada hazır", leadingEmoji = "🔥")
            OptionCard("Normal", s.timeChoice == "45", { viewModel.setTime("45") }, sub = "30–45 dakika", leadingEmoji = "⏱️")
            OptionCard("Bol vaktim", s.timeChoice == "999", { viewModel.setTime("999") }, sub = "1 saat ve üzeri, keyifle", leadingEmoji = "🍲")
        }
        NeYesemPhase.Loading -> Box(Modifier.fillMaxSize().background(MaterialTheme.ds.cream), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = MaterialTheme.ds.ember)
        }
        NeYesemPhase.Swipe -> SwipePhase(s, viewModel, onClose)
    }
}

@Composable
private fun SwipePhase(s: NeYesemState, vm: NeYesemViewModel, onClose: () -> Unit) {
    Column(Modifier.fillMaxSize().background(MaterialTheme.ds.cream)) {
        Spacer(Modifier.height(54.dp))
        Row(Modifier.fillMaxWidth().padding(horizontal = 22.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(38.dp).background(MaterialTheme.ds.sand, CircleShape).clickable(onClick = onClose), contentAlignment = Alignment.Center) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Geri", tint = MaterialTheme.ds.smoke, modifier = Modifier.size(19.dp))
            }
            Text("Ne Yesem?", style = MaterialTheme.typography.titleLarge, color = MaterialTheme.ds.ink,
                modifier = Modifier.weight(1f), textAlign = TextAlign.Center)
            Chip(text = "♥ ${s.likedCount}", soft = true)
        }

        Box(Modifier.weight(1f).fillMaxWidth().padding(22.dp), contentAlignment = Alignment.Center) {
            val recipe = s.current
            when {
                s.error != null -> Text(s.error, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.smoke)
                recipe == null -> Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("🌿", fontSize = 40.sp)
                    Text("Bugünlük bu kadar!", style = DisplayXLTextStyle.copy(fontSize = 24.sp), color = MaterialTheme.ds.ink, modifier = Modifier.padding(top = 12.dp))
                    Text("${s.likedCount} tarif beğendin.", style = HandwrittenTextStyle, color = MaterialTheme.ds.smoke, modifier = Modifier.padding(top = 6.dp))
                }
                else -> SwipeCard(recipe)
            }
        }

        if (s.current != null) {
            Row(Modifier.fillMaxWidth().padding(bottom = 30.dp), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(58.dp).background(MaterialTheme.ds.cream, CircleShape)
                    .clickable { vm.skip() }, contentAlignment = Alignment.Center) {
                    Box(Modifier.size(58.dp).background(Color.Transparent, CircleShape)) {}
                    Icon(Icons.Default.Close, contentDescription = "Geç", tint = MaterialTheme.ds.tomato, modifier = Modifier.size(26.dp).align(Alignment.Center))
                }
                Spacer(Modifier.size(28.dp))
                Box(Modifier.size(64.dp).background(MaterialTheme.ds.ember, CircleShape)
                    .clickable { vm.like() }, contentAlignment = Alignment.Center) {
                    Icon(Icons.Default.Favorite, contentDescription = "Sevdim", tint = Color.White, modifier = Modifier.size(30.dp))
                }
            }
        }
    }
}

@Composable
private fun SwipeCard(recipe: Recipe) {
    Column(
        Modifier.fillMaxSize().background(MaterialTheme.ds.cream, RoundedCornerShape(20.dp)),
    ) {
        FoodBlock(seed = recipe.title, corner = 20, modifier = Modifier.fillMaxWidth().weight(0.6f))
        Column(Modifier.weight(0.4f).padding(18.dp)) {
            Text(recipe.title, style = DisplayXLTextStyle.copy(fontSize = 23.sp), color = MaterialTheme.ds.ink)
            Row(Modifier.padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                recipe.cuisine?.let { Chip(text = it) }
                recipe.cookingTimeMinutes?.let { Chip(text = "$it dk") }
                recipe.difficulty?.let { Chip(text = when (it) { "low" -> "Kolay"; "medium" -> "Orta"; else -> "Zor" }) }
            }
            Spacer(Modifier.weight(1f))
            Text(
                recipe.description.take(90).let { if (recipe.description.length > 90) "$it…" else it },
                style = MaterialTheme.typography.bodyMedium.copy(fontSize = 13.5.sp), color = MaterialTheme.ds.smoke, maxLines = 2,
            )
        }
    }
}
