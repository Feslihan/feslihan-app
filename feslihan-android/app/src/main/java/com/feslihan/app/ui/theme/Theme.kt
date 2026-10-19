package com.feslihan.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.unit.dp

/** One radius everywhere (iOS `DS.radius = 8`). */
object FeslihanDimens {
    val radius = 8.dp
    val hairline = 1.dp
    val screenPadding = 20.dp
    val cardPadding = 16.dp
    val gutter = 12.dp
}

private val FeslihanShapes = Shapes(
    extraSmall = RoundedCornerShape(FeslihanDimens.radius),
    small = RoundedCornerShape(FeslihanDimens.radius),
    medium = RoundedCornerShape(FeslihanDimens.radius),
    large = RoundedCornerShape(FeslihanDimens.radius),
    extraLarge = RoundedCornerShape(FeslihanDimens.radius),
)

private val LocalDsPalette = staticCompositionLocalOf { lightDsPalette() }

/** Access DS tokens in composables: `MaterialTheme.ds.ember`. */
val MaterialTheme.ds: DsPalette
    @Composable @ReadOnlyComposable
    get() = LocalDsPalette.current

@Composable
fun FeslihanTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val palette = if (darkTheme) darkDsPalette() else lightDsPalette()

    // Map DS tokens onto Material3's scheme so stock M3 components inherit the brand.
    val colorScheme = if (darkTheme) {
        darkColorScheme(
            primary = palette.ember,
            onPrimary = FeslihanColors.CreamDark,
            secondary = palette.honey,
            background = palette.cream,
            onBackground = palette.ink,
            surface = palette.cream,
            onSurface = palette.ink,
            surfaceVariant = palette.sand,
            outline = palette.stone,
            error = palette.tomato,
        )
    } else {
        lightColorScheme(
            primary = palette.ember,
            onPrimary = FeslihanColors.CreamLight,
            secondary = palette.honey,
            background = palette.cream,
            onBackground = palette.ink,
            surface = palette.cream,
            onSurface = palette.ink,
            surfaceVariant = palette.sand,
            outline = palette.stone,
            error = palette.tomato,
        )
    }

    CompositionLocalProvider(LocalDsPalette provides palette) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = FeslihanTypography,
            shapes = FeslihanShapes,
            content = content,
        )
    }
}
