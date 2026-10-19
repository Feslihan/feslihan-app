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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.feslihan.app.data.model.MealPlanDay
import com.feslihan.app.ui.components.FeslihanPrimaryButton
import com.feslihan.app.ui.components.OptionCard
import com.feslihan.app.ui.components.WizardChrome
import com.feslihan.app.ui.theme.DisplayXLTextStyle
import com.feslihan.app.ui.theme.HandwrittenTextStyle
import com.feslihan.app.ui.theme.ds

/** Haftalık Plan (iOS ScrMealWizard + ScrMealResult) as one phased screen. */
@Composable
fun MealPrepScreen(
    onClose: () -> Unit,
    onOpenPaywall: () -> Unit,
    viewModel: MealPrepViewModel = hiltViewModel(),
) {
    val s by viewModel.state.collectAsStateWithLifecycle()

    when (s.phase) {
        MealPrepPhase.Wizard -> WizardPhase(s, viewModel, onClose)
        MealPrepPhase.Generating -> GeneratingPhase()
        MealPrepPhase.Result -> ResultPhase(s, viewModel, onClose)
        MealPrepPhase.Error -> ErrorPhase(s, viewModel, onOpenPaywall, onClose)
    }
}

@Composable
private fun WizardPhase(s: MealPrepState, vm: MealPrepViewModel, onClose: () -> Unit) {
    val (title, sub) = when (s.step) {
        1 -> "Kaç kişilik pişireceğiz?" to "Porsiyonları buna göre ayarlayalım."
        2 -> "Günde kaç öğün?" to "Plan bu öğünleri kapsayacak."
        3 -> "Nasıl besleniyorsunuz?" to "Birden fazla seçebilirsiniz."
        4 -> "Ne kadarlık plan?" to null
        5 -> "Evde çocuk var mı?" to "Çocuk dostu tarifler ekleyelim."
        6 -> "Nasıl hazırlamak istersin?" to null
        else -> "Bütçen ne kadar?" to "Malzemeleri ona göre seçelim."
    }
    WizardChrome(
        step = s.step, total = s.totalSteps, title = title, sub = sub,
        cta = if (s.step == s.totalSteps) "Planı Oluştur" else "Devam",
        enabled = s.canAdvance,
        onBack = { if (s.step == 1) onClose() else vm.back() },
        onNext = { vm.next() },
    ) {
        when (s.step) {
            1 -> listOf("1", "2", "3", "4", "5+").forEach { Opt(it + " kişi", s.peopleCount == it) { vm.setPeople(it) } }
            2 -> listOf("1", "2", "3").forEach { Opt("$it öğün", s.mealsPerDay == it) { vm.setMeals(it) } }
            3 -> listOf(
                "Dengeli" to "🥣", "Sebze ağırlıklı" to "🌿", "Et ağırlıklı" to "🔥",
                "Geleneksel" to "🍲", "Glutensiz" to "⭐",
            ).forEach { (t, e) -> OptionCard(title = t, selected = t in s.eatingStyles, onClick = { vm.toggleStyle(t) }, leadingEmoji = e) }
            4 -> listOf("1 Hafta", "2 Hafta").forEach { Opt(it, s.period == it) { vm.setPeriod(it) } }
            5 -> {
                Opt("Evet", s.hasKids == true) { vm.setKids(true) }
                Opt("Hayır", s.hasKids == false) { vm.setKids(false) }
            }
            6 -> listOf("Günlük taze", "Toplu (meal prep)").forEach { Opt(it, s.prepStyle == it) { vm.setPrep(it) } }
            else -> listOf("Ekonomik", "Dengeli", "Bol").forEach { Opt(it, s.budget == it) { vm.setBudget(it) } }
        }
    }
}

@Composable
private fun Opt(title: String, selected: Boolean, onClick: () -> Unit) =
    OptionCard(title = title, selected = selected, onClick = onClick)

@Composable
private fun GeneratingPhase() {
    Column(
        Modifier.fillMaxSize().background(MaterialTheme.ds.cream).padding(32.dp),
        verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        CircularProgressIndicator(color = MaterialTheme.ds.ember)
        Text("Planın hazırlanıyor…", style = DisplayXLTextStyle.copy(fontSize = 24.sp), color = MaterialTheme.ds.ink, modifier = Modifier.padding(top = 24.dp))
        Text("Annenin defterinden en iyi tarifleri seçiyoruz.", style = HandwrittenTextStyle, color = MaterialTheme.ds.smoke,
            textAlign = TextAlign.Center, modifier = Modifier.padding(top = 8.dp))
    }
}

@Composable
private fun ResultPhase(s: MealPrepState, vm: MealPrepViewModel, onClose: () -> Unit) {
    Column(Modifier.fillMaxSize().background(MaterialTheme.ds.cream)) {
        Row(Modifier.fillMaxWidth().padding(start = 22.dp, end = 22.dp, top = 54.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(38.dp).background(MaterialTheme.ds.sand, CircleShape).clickable(onClick = onClose), contentAlignment = Alignment.Center) {
                Icon(Icons.Default.Close, contentDescription = "Kapat", tint = MaterialTheme.ds.smoke, modifier = Modifier.size(18.dp))
            }
        }
        Column(Modifier.padding(horizontal = 22.dp, vertical = 6.dp)) {
            Text("Afiyet olsun ✦", style = HandwrittenTextStyle, color = MaterialTheme.ds.smoke)
            Text("Haftalık Planın Hazır", style = DisplayXLTextStyle.copy(fontSize = 27.sp), color = MaterialTheme.ds.ink)
            val meta = listOfNotNull(
                s.peopleCount?.let { "$it kişi" }, s.mealsPerDay?.let { "$it öğün" }, s.period,
            ).joinToString(" · ")
            if (meta.isNotEmpty()) Text(meta, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.smoke, modifier = Modifier.padding(top = 2.dp))
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 22.dp, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)) {
            s.result?.days?.forEach { day -> DayCard(day) }
        }
        Box(Modifier.padding(22.dp)) {
            if (s.saved) {
                Text("Plan kaydedildi ✓", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.ds.ember,
                    modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
            } else {
                FeslihanPrimaryButton(text = "Planı Kaydet", onClick = { vm.save("Bu Haftanın Planı") })
            }
        }
    }
}

@Composable
private fun DayCard(day: MealPlanDay) {
    Column(
        Modifier.fillMaxWidth().border(1.dp, MaterialTheme.ds.stone, RoundedCornerShape(8.dp)).padding(16.dp),
    ) {
        Text(day.dayName, style = MaterialTheme.typography.titleLarge.copy(fontSize = 15.sp), color = MaterialTheme.ds.ink)
        Box(Modifier.fillMaxWidth().height(1.dp).background(MaterialTheme.ds.stone).padding(vertical = 10.dp))
        Spacer(Modifier.height(10.dp))
        day.meals.forEach { meal ->
            Row(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                Text(meal.mealType, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.ds.smoke, modifier = Modifier.size(width = 70.dp, height = 20.dp))
                Text(meal.name ?: meal.recipeIds?.firstOrNull() ?: "—",
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold),
                    color = MaterialTheme.ds.ink, modifier = Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun ErrorPhase(s: MealPrepState, vm: MealPrepViewModel, onOpenPaywall: () -> Unit, onClose: () -> Unit) {
    Column(
        Modifier.fillMaxSize().background(MaterialTheme.ds.cream).padding(32.dp),
        verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(if (s.premiumRequired) "👑" else "🍲", fontSize = 40.sp)
        Text(s.error ?: "Bir şeyler ters gitti", style = DisplayXLTextStyle.copy(fontSize = 22.sp), color = MaterialTheme.ds.ink,
            textAlign = TextAlign.Center, modifier = Modifier.padding(top = 16.dp))
        Spacer(Modifier.height(20.dp))
        if (s.premiumRequired) {
            FeslihanPrimaryButton(text = "Feslihan+'a Geç", onClick = onOpenPaywall)
        } else {
            FeslihanPrimaryButton(text = "Tekrar Dene", onClick = { vm.restart() })
        }
        Spacer(Modifier.height(10.dp))
        Text("Kapat", color = MaterialTheme.ds.smoke, modifier = Modifier.clickable(onClick = onClose).padding(8.dp))
    }
}
