package com.feslihan.app.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * Typography ported from iOS Theme.swift Font extensions.
 * Titles use a **serif** face (iOS "New York" → Android system serif), body uses
 * the default sans. No rounded faces — editorial system. `FontFamily.Serif` maps
 * to the platform serif (Noto Serif on most devices); swap for a bundled Lora if
 * exact brand parity is needed later.
 */
private val Serif = FontFamily.Serif
private val Sans = FontFamily.Default

val FeslihanTypography = Typography(
    // Page titles — editorial serif, ~28pt semibold (iOS displayLarge)
    headlineLarge = TextStyle(fontFamily = Serif, fontWeight = FontWeight.SemiBold, fontSize = 28.sp, lineHeight = 34.sp),
    // Section titles — serif, ~22pt semibold (iOS displayTitle)
    headlineMedium = TextStyle(fontFamily = Serif, fontWeight = FontWeight.SemiBold, fontSize = 22.sp, lineHeight = 28.sp),
    // Section headers — sans, ~17pt semibold (iOS sectionHeader)
    titleLarge = TextStyle(fontFamily = Sans, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, lineHeight = 24.sp),
    // Card titles — sans, ~15pt semibold (iOS cardTitle)
    titleMedium = TextStyle(fontFamily = Sans, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, lineHeight = 20.sp),
    // Body — sans, ~15pt regular (iOS bodyText)
    bodyMedium = TextStyle(fontFamily = Sans, fontWeight = FontWeight.Normal, fontSize = 15.sp, lineHeight = 22.sp),
    // Labels — sans, ~13pt medium (iOS label)
    labelLarge = TextStyle(fontFamily = Sans, fontWeight = FontWeight.Medium, fontSize = 13.sp, lineHeight = 18.sp),
    // Captions — sans, ~12pt regular (iOS captionText)
    bodySmall = TextStyle(fontFamily = Sans, fontWeight = FontWeight.Normal, fontSize = 12.sp, lineHeight = 16.sp),
    // Button text — sans, ~16pt semibold (iOS buttonFont)
    labelMedium = TextStyle(fontFamily = Sans, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, lineHeight = 20.sp),
)

/** Handwritten / decorative — serif italic, ~15pt (iOS `handwritten`). For "anne notu". */
val HandwrittenTextStyle = TextStyle(
    fontFamily = Serif,
    fontWeight = FontWeight.Normal,
    fontStyle = FontStyle.Italic,
    fontSize = 15.sp,
    lineHeight = 22.sp,
)

/** Eyebrow — tiny uppercase tracker label, ~11pt semibold (iOS `eyebrow`). */
val EyebrowTextStyle = TextStyle(
    fontFamily = Sans,
    fontWeight = FontWeight.SemiBold,
    fontSize = 11.sp,
    lineHeight = 14.sp,
    letterSpacing = 1.3.sp,
)

/** Oversized editorial serif screen title (design uses ~40px "Tariflerim"). */
val DisplayXLTextStyle = TextStyle(
    fontFamily = Serif,
    fontWeight = FontWeight.SemiBold,
    fontSize = 38.sp,
    lineHeight = 42.sp,
    letterSpacing = (-1).sp,
)

/** Hero title over photos (design ~42px). */
val DisplayHeroTextStyle = TextStyle(
    fontFamily = Serif,
    fontWeight = FontWeight.SemiBold,
    fontSize = 40.sp,
    lineHeight = 44.sp,
    letterSpacing = (-1).sp,
)
