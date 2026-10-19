package com.feslihan.app.ui.screens.recipes

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.feslihan.app.ui.theme.HandwrittenTextStyle

private val Night = Color(0xFF000000)
private val BasilTintOnDark = Color(0xFFCFE8D6)
private val Terracotta = Color(0xFFD93A2B)
private val Honey = Color(0xFFF2A516)

/**
 * Pişirme Modu (iOS ScrCooking). Immersive dark step-by-step: step counter,
 * progress bar, large instruction, timer pill, prev/next. Always-dark by design.
 */
@Composable
fun CookingModeScreen(onClose: () -> Unit, viewModel: CookingViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var step by remember { mutableIntStateOf(0) }
    val total = state.steps.size.coerceAtLeast(1)
    val current = step.coerceIn(0, total - 1)

    Column(modifier = Modifier.fillMaxSize().background(Night).padding(horizontal = 22.dp)) {
        Spacer(Modifier.height(54.dp))
        Row(Modifier.fillMaxWidth().padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("ADIM ${current + 1} / $total", color = Color.White.copy(alpha = 0.55f),
                style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold), modifier = Modifier.weight(1f))
            Box(
                Modifier.size(38.dp).background(Color.White.copy(alpha = 0.12f), CircleShape).clickable(onClick = onClose),
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Default.Close, contentDescription = "Kapat", tint = Color.White.copy(alpha = 0.8f), modifier = Modifier.size(18.dp)) }
        }

        // progress
        Box(Modifier.fillMaxWidth().padding(top = 14.dp).height(5.dp).background(Color.White.copy(alpha = 0.15f), RoundedCornerShape(3.dp))) {
            Box(Modifier.fillMaxHeight().fillMaxWidth(fraction = (current + 1) / total.toFloat())
                .background(BasilTintOnDark, RoundedCornerShape(3.dp)))
        }

        // instruction
        Column(
            modifier = Modifier.weight(1f).fillMaxWidth().padding(horizontal = 12.dp),
            verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (state.title.isNotBlank()) {
                Text(state.title, style = HandwrittenTextStyle.copy(fontSize = 15.sp), color = Honey)
                Spacer(Modifier.height(22.dp))
            }
            Text(
                text = state.steps.getOrNull(current) ?: "",
                color = Color.White,
                style = MaterialTheme.typography.titleLarge.copy(fontSize = 24.sp, lineHeight = 39.sp, fontWeight = FontWeight.SemiBold),
                textAlign = TextAlign.Center,
            )
        }

        // nav
        Row(Modifier.fillMaxWidth().padding(bottom = 30.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            NavButton(
                text = "Önceki", leading = true, enabled = current > 0,
                bg = Color.White.copy(alpha = 0.12f), fg = Color.White.copy(alpha = 0.9f),
                modifier = Modifier.weight(1f),
            ) { if (current > 0) step = current - 1 }
            NavButton(
                text = if (current < total - 1) "Sonraki" else "Bitir", leading = false, enabled = true,
                bg = BasilTintOnDark, fg = Night, modifier = Modifier.weight(1.4f),
            ) { if (current < total - 1) step = current + 1 else onClose() }
        }
    }
}

@Composable
private fun NavButton(text: String, leading: Boolean, enabled: Boolean, bg: Color, fg: Color, modifier: Modifier, onClick: () -> Unit) {
    Row(
        modifier = modifier.height(50.dp).background(bg, RoundedCornerShape(8.dp))
            .clickable(enabled = enabled, onClick = onClick),
        horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
    ) {
        if (leading) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null, tint = fg, modifier = Modifier.size(20.dp)); Spacer(Modifier.size(6.dp)) }
        Text(text, color = fg, style = MaterialTheme.typography.labelMedium)
        if (!leading) { Spacer(Modifier.size(6.dp)); Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = null, tint = fg, modifier = Modifier.size(20.dp)) }
    }
}
