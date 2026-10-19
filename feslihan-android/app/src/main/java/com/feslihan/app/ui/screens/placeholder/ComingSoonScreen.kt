package com.feslihan.app.ui.screens.placeholder

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.feslihan.app.ui.components.FeslihanTopBar
import com.feslihan.app.ui.theme.ds

/**
 * DS-styled placeholder for screens not yet ported. Keeps the nav graph complete
 * and navigable; replaced by the real screen as each task lands.
 */
@Composable
fun ComingSoonScreen(title: String, onBack: () -> Unit) {
    Scaffold(
        containerColor = MaterialTheme.ds.cream,
        topBar = { FeslihanTopBar(title = title, onBack = onBack) },
    ) { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding).padding(24.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("🌿", style = MaterialTheme.typography.headlineLarge)
            Text(
                text = "Bu bölüm yakında",
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.ds.ink,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 12.dp),
            )
            Text(
                text = "“$title” ekranı Android portuna aktarılıyor.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.ds.smoke,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 6.dp),
            )
        }
    }
}
