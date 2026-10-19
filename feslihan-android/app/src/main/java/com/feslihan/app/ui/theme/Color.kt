package com.feslihan.app.ui.theme

import androidx.compose.ui.graphics.Color

/**
 * Design-system colors ported 1:1 from the iOS `DS` enum (Feslihan/Theme.swift).
 * "Modern Kitchen Editorial" — clean white/neutral system with a basil accent.
 * Each token has an explicit light + dark value (iOS `Color(light:dark:)`).
 */
object FeslihanColors {
    // Backgrounds (editorial neutrals — dark: near-black)
    val CreamLight = Color(0xFFFFFFFF); val CreamDark = Color(0xFF0F0F0F) // Paper White
    val SandLight = Color(0xFFF4F4F4); val SandDark = Color(0xFF1C1C1C)   // Wash
    val StoneLight = Color(0xFFE5E5E5); val StoneDark = Color(0xFF2B2B2B) // Line / hairline

    // Text (near-black ink + neutral grays — inverted for dark)
    val InkLight = Color(0xFF111111); val InkDark = Color(0xFFF2F2F2)   // Ink
    val SmokeLight = Color(0xFF555555); val SmokeDark = Color(0xFFB3B3B3) // Gray 1
    val DustLight = Color(0xFF767676); val DustDark = Color(0xFF8C8C8C)   // Gray 2

    // Accent (basil green — brightened for dark)
    val EmberLight = Color(0xFF23834A); val EmberDark = Color(0xFF3DA363)         // Basil
    val EmberTintLight = Color(0xFFE6F3EA); val EmberTintDark = Color(0xFF17301F) // Basil Tint

    // Supporting (market-produce accents)
    val TerracottaLight = Color(0xFFD93A2B); val TerracottaDark = Color(0xFFE05A4C)
    val Honey = Color(0xFFF2A516)
    val HoneyInkLight = Color(0xFFB86E00); val HoneyInkDark = Color(0xFFD98F1F) // Saffron Ink
    val TomatoLight = Color(0xFFD93A2B); val TomatoDark = Color(0xFFE05A4C)
    val EggplantLight = Color(0xFF6B2D6B); val EggplantDark = Color(0xFF9A5A9A)
}

/**
 * Semantic DS palette resolved for the active color scheme. Access via
 * `MaterialTheme.ds` inside composables. Mirrors the iOS `DS` token names so
 * screen code reads the same across platforms.
 */
data class DsPalette(
    val cream: Color,      // primary background (paper white)
    val sand: Color,       // wash / secondary surface
    val stone: Color,      // hairline border / divider
    val ink: Color,        // primary text
    val smoke: Color,      // secondary text
    val dust: Color,       // tertiary text
    val ember: Color,      // basil accent
    val emberTint: Color,  // basil tint (chips, highlights)
    val terracotta: Color,
    val honey: Color,
    val honeyInk: Color,
    val tomato: Color,
    val eggplant: Color,
    val isDark: Boolean,
)

fun lightDsPalette() = DsPalette(
    cream = FeslihanColors.CreamLight,
    sand = FeslihanColors.SandLight,
    stone = FeslihanColors.StoneLight,
    ink = FeslihanColors.InkLight,
    smoke = FeslihanColors.SmokeLight,
    dust = FeslihanColors.DustLight,
    ember = FeslihanColors.EmberLight,
    emberTint = FeslihanColors.EmberTintLight,
    terracotta = FeslihanColors.TerracottaLight,
    honey = FeslihanColors.Honey,
    honeyInk = FeslihanColors.HoneyInkLight,
    tomato = FeslihanColors.TomatoLight,
    eggplant = FeslihanColors.EggplantLight,
    isDark = false,
)

fun darkDsPalette() = DsPalette(
    cream = FeslihanColors.CreamDark,
    sand = FeslihanColors.SandDark,
    stone = FeslihanColors.StoneDark,
    ink = FeslihanColors.InkDark,
    smoke = FeslihanColors.SmokeDark,
    dust = FeslihanColors.DustDark,
    ember = FeslihanColors.EmberDark,
    emberTint = FeslihanColors.EmberTintDark,
    terracotta = FeslihanColors.TerracottaDark,
    honey = FeslihanColors.Honey,
    honeyInk = FeslihanColors.HoneyInkDark,
    tomato = FeslihanColors.TomatoDark,
    eggplant = FeslihanColors.EggplantDark,
    isDark = true,
)
