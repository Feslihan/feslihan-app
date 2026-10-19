package com.feslihan.app.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.feslihan.app.ui.theme.FeslihanDimens
import com.feslihan.app.ui.theme.ds

/**
 * Editorial card: flat (no elevation/shadow), hairline border, radius 8.
 * The iOS system relies on hairline borders — not shadows — for structure.
 */
@Composable
fun FeslihanCard(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    content: @Composable () -> Unit,
) {
    val border = BorderStroke(FeslihanDimens.hairline, MaterialTheme.ds.stone)
    val shape = RoundedCornerShape(FeslihanDimens.radius)
    val colors = CardDefaults.cardColors(containerColor = MaterialTheme.ds.cream)
    val elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
    if (onClick != null) {
        Card(onClick = onClick, modifier = modifier, shape = shape, colors = colors, elevation = elevation, border = border) { content() }
    } else {
        Card(modifier = modifier, shape = shape, colors = colors, elevation = elevation, border = border) { content() }
    }
}

/** Primary (basil) action button, full width, radius 8, no shadow. */
@Composable
fun FeslihanPrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.fillMaxWidth().height(52.dp),
        shape = RoundedCornerShape(FeslihanDimens.radius),
        colors = ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.ds.ember,
            contentColor = Color.White,
        ),
        contentPadding = PaddingValues(horizontal = 22.dp),
    ) {
        Text(text, style = MaterialTheme.typography.labelMedium)
    }
}

/** Circular back button (iOS `BackButton`). */
@Composable
fun BackButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
    IconButton(onClick = onClick, modifier = modifier.size(38.dp)) {
        Box {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Geri",
                tint = MaterialTheme.ds.ink,
            )
        }
    }
}

/**
 * Editorial top app bar: serif title, optional circular back button, hairline
 * bottom border, flat (no shadow). Use on every secondary screen.
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun FeslihanTopBar(
    title: String,
    onBack: (() -> Unit)? = null,
    actions: @Composable androidx.compose.foundation.layout.RowScope.() -> Unit = {},
) {
    androidx.compose.material3.TopAppBar(
        title = {
            Text(
                title,
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.ds.ink,
            )
        },
        navigationIcon = { if (onBack != null) BackButton(onClick = onBack) },
        actions = actions,
        colors = androidx.compose.material3.TopAppBarDefaults.topAppBarColors(
            containerColor = MaterialTheme.ds.cream,
            titleContentColor = MaterialTheme.ds.ink,
        ),
    )
}

/** Tiny uppercase tracker label above section titles (iOS eyebrow). */
@Composable
fun Eyebrow(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text.uppercase(java.util.Locale("tr", "TR")),
        style = com.feslihan.app.ui.theme.EyebrowTextStyle,
        color = MaterialTheme.ds.dust,
        modifier = modifier,
    )
}
