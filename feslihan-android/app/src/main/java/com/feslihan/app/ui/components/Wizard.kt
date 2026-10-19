package com.feslihan.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.feslihan.app.ui.theme.DisplayXLTextStyle
import com.feslihan.app.ui.theme.ds

/**
 * Wizard shell (iOS WizardChrome): top progress bar, back + step counter,
 * serif title + sub, scrollable content, and a bottom primary CTA.
 */
@Composable
fun WizardChrome(
    step: Int,
    total: Int,
    title: String,
    cta: String = "Devam",
    enabled: Boolean = true,
    sub: String? = null,
    onBack: () -> Unit,
    onNext: () -> Unit,
    content: @Composable () -> Unit,
) {
    Column(modifier = Modifier.fillMaxSize().background(MaterialTheme.ds.cream)) {
        // progress
        Box(Modifier.fillMaxWidth().height(4.dp).background(MaterialTheme.ds.stone)) {
            Box(Modifier.fillMaxHeight().fillMaxWidth(fraction = step / total.toFloat()).background(MaterialTheme.ds.ember))
        }
        Spacer(Modifier.height(50.dp))
        Row(Modifier.fillMaxWidth().padding(horizontal = 22.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(38.dp).background(MaterialTheme.ds.sand, CircleShape).clickable(onClick = onBack),
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Geri", tint = MaterialTheme.ds.smoke, modifier = Modifier.size(19.dp)) }
            Spacer(Modifier.weight(1f))
            Text("$step / $total", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.ds.smoke)
        }
        Column(Modifier.padding(horizontal = 22.dp, vertical = 14.dp)) {
            Text(title, style = DisplayXLTextStyle.copy(fontSize = 27.sp, lineHeight = 31.sp), color = MaterialTheme.ds.ink)
            if (sub != null) Text(sub, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.smoke, modifier = Modifier.padding(top = 6.dp))
        }
        Column(
            Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 22.dp, vertical = 4.dp),
            verticalArrangement = Arrangement.spacedBy(11.dp),
        ) { content() }
        Box(Modifier.padding(22.dp)) {
            FeslihanPrimaryButton(text = cta, onClick = onNext, enabled = enabled)
        }
        Spacer(Modifier.height(10.dp))
    }
}

/** Selectable option card (iOS OptionCard): optional icon, title, sub, checkmark. */
@Composable
fun OptionCard(
    title: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    sub: String? = null,
    leadingEmoji: String? = null,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(if (selected) MaterialTheme.ds.emberTint else MaterialTheme.ds.cream, RoundedCornerShape(14.dp))
            .border(1.5.dp, if (selected) MaterialTheme.ds.ember else MaterialTheme.ds.stone, RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (leadingEmoji != null) {
            Box(
                Modifier.size(42.dp).background(if (selected) MaterialTheme.ds.cream else MaterialTheme.ds.sand, RoundedCornerShape(11.dp)),
                contentAlignment = Alignment.Center,
            ) { Text(leadingEmoji, fontSize = 20.sp) }
            Spacer(Modifier.size(13.dp))
        }
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleMedium.copy(fontSize = 16.sp), color = MaterialTheme.ds.ink)
            if (sub != null) Text(sub, style = MaterialTheme.typography.bodyMedium.copy(fontSize = 13.sp), color = MaterialTheme.ds.smoke, modifier = Modifier.padding(top = 1.dp))
        }
        Box(
            Modifier.size(24.dp)
                .background(if (selected) MaterialTheme.ds.ember else Color.Transparent, CircleShape)
                .then(if (!selected) Modifier.border(1.5.dp, MaterialTheme.ds.stone, CircleShape) else Modifier),
            contentAlignment = Alignment.Center,
        ) { if (selected) Icon(Icons.Default.Check, contentDescription = null, tint = Color.White, modifier = Modifier.size(14.dp)) }
    }
}
