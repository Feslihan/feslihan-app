package com.feslihan.app.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.feslihan.app.ui.theme.ds
import kotlin.math.absoluteValue

/**
 * "Market produce" food block — a flat diagonal gradient keyed by dish, matching
 * the design's `.f-*` photo placeholders (theme.css). Real recipes pass their
 * title; a stable hash picks a gradient so every card has a warm, distinct block
 * until a real thumbnail is wired via Coil.
 */
private val FoodGradients: List<Pair<Color, Color>> = listOf(
    Color(0xFFE8503C) to Color(0xFFC5301F), // menemen (tomato/egg)
    Color(0xFF7E3A7E) to Color(0xFF55215A), // karnıyarık (eggplant)
    Color(0xFFF5B12E) to Color(0xFFE08A0C), // mercimek (lentil)
    Color(0xFF36A15E) to Color(0xFF1E7A42), // salata (greens)
    Color(0xFFC2532F) to Color(0xFF93361C), // köfte
    Color(0xFFF2C55A) to Color(0xFFD99A1E), // börek
    Color(0xFFF1E07A) to Color(0xFFD9C23A), // pilav
    Color(0xFF7F9632) to Color(0xFF5A6E1E), // dolma
    Color(0xFF9BBF45) to Color(0xFF6E9628), // baklava
    Color(0xFFF09A3A) to Color(0xFFD27315), // tavuk
    Color(0xFF9A4A78) to Color(0xFF6B2D55), // balık
    Color(0xFFF07F2E) to Color(0xFFD25E12), // çorba
)

fun foodGradientFor(seed: String): Brush {
    val idx = (seed.hashCode().absoluteValue) % FoodGradients.size
    val (a, b) = FoodGradients[idx]
    return Brush.linearGradient(listOf(a, b))
}

/** A fixed basil/green gradient for non-dish cards (e.g. the featured meal-plan card). */
val BasilGradient: Brush = Brush.linearGradient(listOf(Color(0xFF36A15E), Color(0xFF1E7A42)))

/** Rounded food image placeholder with the dish gradient; children overlay on top. */
@Composable
fun FoodBlock(
    seed: String,
    modifier: Modifier = Modifier,
    corner: Int = 8,
    brush: Brush? = null,
    content: @Composable (BoxScope.() -> Unit) = {},
) {
    Box(
        modifier = modifier
            .background(brush ?: foodGradientFor(seed), RoundedCornerShape(corner.dp)),
        content = content,
    )
}

// Re-export BoxScope type alias so screens don't need the import.
typealias BoxScope = androidx.compose.foundation.layout.BoxScope

/** Pill chip. [active] fills basil; [soft] uses the wash; otherwise hairline outline. */
@Composable
fun Chip(
    text: String,
    modifier: Modifier = Modifier,
    active: Boolean = false,
    soft: Boolean = false,
    leading: @Composable (() -> Unit)? = null,
) {
    val bg = when {
        active -> MaterialTheme.ds.ember
        soft -> MaterialTheme.ds.sand
        else -> Color.Transparent
    }
    val fg = if (active) Color.White else MaterialTheme.ds.ink
    val border = if (active || soft) null else BorderStroke(1.dp, MaterialTheme.ds.stone)
    Row(
        modifier = modifier
            .background(bg, CircleShape)
            .then(if (border != null) Modifier.border(border, CircleShape) else Modifier)
            .padding(horizontal = 13.dp, vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (leading != null) { leading(); androidx.compose.foundation.layout.Spacer(Modifier.size(5.dp)) }
        Text(text, style = MaterialTheme.typography.labelLarge, color = fg)
    }
}

/** Availability dot used in ingredient lists: have=basil, maybe=saffron, need=tomato. */
enum class Availability { Have, Maybe, Need }

@Composable
fun StatusDot(state: Availability, modifier: Modifier = Modifier) {
    val color = when (state) {
        Availability.Have -> MaterialTheme.ds.ember
        Availability.Maybe -> MaterialTheme.ds.honey
        Availability.Need -> MaterialTheme.ds.tomato
    }
    Box(modifier = modifier.size(8.dp).background(color, CircleShape))
}

/** Pantry "bubble" chip (design: filled basil when on, wash when off). */
@Composable
fun Bubble(text: String, on: Boolean = true, modifier: Modifier = Modifier) {
    val bg = if (on) MaterialTheme.ds.ember else MaterialTheme.ds.sand
    val fg = if (on) Color.White else MaterialTheme.ds.smoke
    val border = if (on) null else BorderStroke(1.dp, MaterialTheme.ds.stone)
    Box(
        modifier = modifier
            .background(bg, CircleShape)
            .then(if (border != null) Modifier.border(border, CircleShape) else Modifier)
            .padding(horizontal = 16.dp, vertical = 9.dp),
    ) {
        Text(text, style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.SemiBold), color = fg)
    }
}

/** PLUS badge (basil outline + crown) — design uses "PLUS", not "PREMIUM". */
@Composable
fun PlusBadge(modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .border(1.dp, MaterialTheme.ds.ember, RoundedCornerShape(4.dp))
            .padding(horizontal = 7.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Default.WorkspacePremium, contentDescription = null, tint = MaterialTheme.ds.ember, modifier = Modifier.size(12.dp))
        androidx.compose.foundation.layout.Spacer(Modifier.size(4.dp))
        Text("PLUS", color = MaterialTheme.ds.ember, style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold, fontSize = 10.sp, letterSpacing = 0.8.sp))
    }
}
