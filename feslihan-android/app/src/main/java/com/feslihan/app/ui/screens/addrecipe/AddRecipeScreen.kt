package com.feslihan.app.ui.screens.addrecipe

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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ContentPaste
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.feslihan.app.ui.components.FeslihanPrimaryButton
import com.feslihan.app.ui.components.FoodBlock
import com.feslihan.app.ui.theme.DisplayXLTextStyle
import com.feslihan.app.ui.theme.HandwrittenTextStyle
import com.feslihan.app.ui.theme.ds

/** Tarif Ekle (iOS ScrAddProcessing + ScrAddDone) — paste a link, extract, save. */
@Composable
fun AddRecipeScreen(onClose: () -> Unit, viewModel: AddRecipeViewModel = hiltViewModel()) {
    val s by viewModel.state.collectAsStateWithLifecycle()
    val clipboard = LocalClipboardManager.current

    // Dismiss once saved.
    if (s.saved) { onClose(); return }

    Column(
        Modifier.fillMaxSize().background(MaterialTheme.ds.cream),
    ) {
        Spacer(Modifier.height(54.dp))
        Box(Modifier.fillMaxWidth().padding(top = 10.dp), contentAlignment = Alignment.Center) {
            Box(Modifier.size(width = 40.dp, height = 5.dp).background(MaterialTheme.ds.stone, RoundedCornerShape(3.dp)))
        }
        Column(Modifier.padding(horizontal = 22.dp, vertical = 16.dp)) {
            Text(
                if (s.phase == AddPhase.Done) "Tarif Hazır!" else "Tarif Ekle",
                style = DisplayXLTextStyle.copy(fontSize = 26.sp), color = MaterialTheme.ds.ink,
            )
            Text(
                if (s.phase == AddPhase.Done) "Bilgileri kontrol et, beğenirsen kaydet." else "Bir video linki yapıştır, tarifi senin için çıkaralım.",
                style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.smoke, modifier = Modifier.padding(top = 4.dp),
            )
        }

        Column(Modifier.weight(1f).fillMaxWidth().padding(horizontal = 22.dp)) {
            if (s.phase == AddPhase.Idle || s.phase == AddPhase.Error) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Row(
                        Modifier.weight(1f).height(46.dp).border(1.dp, MaterialTheme.ds.stone, RoundedCornerShape(8.dp)).padding(horizontal = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Box(Modifier.fillMaxWidth()) {
                            if (s.url.isEmpty()) Text("Tarif linkini yapıştır…", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.dust)
                            BasicTextField(value = s.url, onValueChange = viewModel::setUrl, singleLine = true,
                                textStyle = MaterialTheme.typography.bodyMedium.copy(color = MaterialTheme.ds.ink),
                                cursorBrush = SolidColor(MaterialTheme.ds.ember))
                        }
                    }
                    Spacer(Modifier.size(8.dp))
                    Row(
                        Modifier.height(46.dp).border(1.dp, MaterialTheme.ds.ink, RoundedCornerShape(8.dp))
                            .clickable { clipboard.getText()?.let { viewModel.setUrl(it.text) } }.padding(horizontal = 16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(Icons.Default.ContentPaste, contentDescription = null, tint = MaterialTheme.ds.ember, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.size(6.dp)); Text("Yapıştır", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.ds.ink)
                    }
                }
                if (s.error != null) Text(s.error!!, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.tomato, modifier = Modifier.padding(top = 14.dp))
            }

            if (s.phase == AddPhase.Processing || s.phase == AddPhase.Done) {
                Column(Modifier.fillMaxWidth().padding(top = 8.dp).border(1.dp, MaterialTheme.ds.stone, RoundedCornerShape(8.dp)).padding(horizontal = 16.dp)) {
                    ChecklistRow("Video bilgileri", Step.VideoInfo, s)
                    RowDivider()
                    ChecklistRow("Ses çıkartma", Step.Audio, s)
                    RowDivider()
                    ChecklistRow("Yazı çevirme", Step.Transcribe, s)
                    RowDivider()
                    ChecklistRow("Tarif analizi", Step.Analyze, s)
                }
            }

            if (s.phase == AddPhase.Done) {
                val r = s.result
                Row(
                    Modifier.fillMaxWidth().padding(top = 18.dp).border(1.dp, MaterialTheme.ds.stone, RoundedCornerShape(8.dp)).padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    FoodBlock(seed = r?.title ?: "tarif", corner = 12, modifier = Modifier.size(76.dp))
                    Column(Modifier.weight(1f).padding(start = 12.dp)) {
                        Text(r?.title ?: "", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.ds.ink)
                        Text(
                            listOfNotNull(
                                r?.ingredientsWithMeasures?.size?.takeIf { it > 0 }?.let { "$it malzeme" },
                                r?.cookingTimeMinutes?.let { "$it dk" },
                            ).joinToString(" · "),
                            style = MaterialTheme.typography.bodySmall, color = MaterialTheme.ds.smoke, modifier = Modifier.padding(top = 7.dp),
                        )
                    }
                }
                Text("Anne notu: beğendiğin tarifleri deftere ekleyince kaybolmaz.", style = HandwrittenTextStyle,
                    color = MaterialTheme.ds.smoke, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(top = 18.dp))
            }
        }

        Box(Modifier.padding(22.dp)) {
            when (s.phase) {
                AddPhase.Idle -> FeslihanPrimaryButton("Tarifi Çıkar", onClick = viewModel::process, enabled = s.url.isNotBlank())
                AddPhase.Processing -> FeslihanPrimaryButton("İşleniyor…", onClick = {}, enabled = false)
                AddPhase.Done -> FeslihanPrimaryButton("Kaydet", onClick = viewModel::save)
                AddPhase.Error -> FeslihanPrimaryButton("Tekrar Dene", onClick = viewModel::process, enabled = s.url.isNotBlank())
            }
        }
        Spacer(Modifier.height(10.dp))
    }
}

@Composable
private fun ChecklistRow(label: String, step: Step, s: AddRecipeState) {
    val done = step in s.completedSteps
    val active = s.activeStep == step && !done && s.phase == AddPhase.Processing
    Row(Modifier.fillMaxWidth().height(46.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(
            Modifier.size(26.dp).background(
                when { done -> MaterialTheme.ds.ember; active -> MaterialTheme.ds.emberTint; else -> MaterialTheme.ds.sand },
                CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            if (done) Icon(Icons.Default.Check, contentDescription = null, tint = Color.White, modifier = Modifier.size(15.dp))
            else if (active) Box(Modifier.size(9.dp).background(MaterialTheme.ds.ember, CircleShape))
        }
        Text(label, style = MaterialTheme.typography.bodyMedium.copy(fontWeight = if (active) FontWeight.Bold else FontWeight.Normal),
            color = if (done || active) MaterialTheme.ds.ink else MaterialTheme.ds.dust,
            modifier = Modifier.weight(1f).padding(start = 12.dp))
        if (done) Text("tamam", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.ds.ember)
    }
}

@Composable
private fun RowDivider() = Box(Modifier.fillMaxWidth().height(1.dp).background(MaterialTheme.ds.stone))
