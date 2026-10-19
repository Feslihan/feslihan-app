package com.feslihan.app.ui.screens.social

import android.widget.Toast
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.feslihan.app.data.model.ShareInboxItem
import com.feslihan.app.ui.components.FoodBlock
import com.feslihan.app.ui.components.UserAvatar
import com.feslihan.app.ui.theme.DisplayXLTextStyle
import com.feslihan.app.ui.components.BackButton
import com.feslihan.app.ui.theme.ds

/**
 * Benimle Paylaşılanlar (iOS SharedInboxView). Pending recipe shares from friends;
 * each card shows the sender, the recipe, an optional note, and accept/dismiss.
 */
@Composable
fun SharedInboxScreen(
    onBack: () -> Unit,
    onOpenRecipe: (recipeId: String) -> Unit,
    viewModel: SharedInboxViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current

    LaunchedEffect(state.message) {
        state.message?.let { Toast.makeText(context, it, Toast.LENGTH_SHORT).show(); viewModel.consumeMessage() }
    }

    Scaffold(containerColor = MaterialTheme.ds.cream) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(start = 18.dp, end = 18.dp, top = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                BackButton(onClick = onBack)
                Spacer(Modifier.size(4.dp))
                Text("Gelen Tarifler", style = DisplayXLTextStyle.copy(fontSize = 26.sp), color = MaterialTheme.ds.ink)
            }

            when {
                state.isLoading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = MaterialTheme.ds.ember)
                }
                state.items.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text(state.error ?: "Paylaşılan tarif yok", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.smoke)
                }
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize().padding(horizontal = 22.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = 14.dp),
                ) {
                    items(state.items, key = { it.id }) { item ->
                        ShareCard(
                            item = item,
                            onOpen = { onOpenRecipe(item.recipe.id) },
                            onAccept = { viewModel.accept(item) },
                            onDismiss = { viewModel.dismiss(item) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ShareCard(item: ShareInboxItem, onOpen: () -> Unit, onAccept: () -> Unit, onDismiss: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxWidth()
            .border(1.dp, MaterialTheme.ds.stone, RoundedCornerShape(8.dp))
            .padding(14.dp),
    ) {
        // Sender line
        Row(verticalAlignment = Alignment.CenterVertically) {
            UserAvatar(name = item.sender.name, size = 32)
            Spacer(Modifier.size(10.dp))
            Text(
                buildString { append(item.sender.name ?: "Bir arkadaşın"); append(" sana bir tarif gönderdi") },
                style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.smoke,
                maxLines = 2, overflow = TextOverflow.Ellipsis,
            )
        }
        Spacer(Modifier.height(12.dp))

        // Recipe
        Row(modifier = Modifier.fillMaxWidth().clickable(onClick = onOpen), verticalAlignment = Alignment.CenterVertically) {
            FoodBlock(seed = item.recipe.title, modifier = Modifier.size(56.dp))
            Spacer(Modifier.size(12.dp))
            Column(Modifier.weight(1f)) {
                Text(item.recipe.title, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.ds.ink,
                    maxLines = 2, overflow = TextOverflow.Ellipsis)
                item.recipe.cookingTimeMinutes?.let {
                    Text("$it dk", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.ds.dust, modifier = Modifier.padding(top = 2.dp))
                }
            }
        }

        // Optional note
        item.message?.takeIf { it.isNotBlank() }?.let { note ->
            Spacer(Modifier.height(10.dp))
            Text("“$note”", style = MaterialTheme.typography.bodyMedium.copy(fontStyle = androidx.compose.ui.text.font.FontStyle.Italic),
                color = MaterialTheme.ds.smoke)
        }

        Spacer(Modifier.height(14.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier.weight(1f).height(44.dp).background(MaterialTheme.ds.ember, RoundedCornerShape(8.dp))
                    .clickable(onClick = onAccept),
                contentAlignment = Alignment.Center,
            ) { Text("Kitaplığıma Ekle", color = Color.White, style = MaterialTheme.typography.labelMedium) }
            Spacer(Modifier.size(10.dp))
            Box(
                modifier = Modifier.height(44.dp).border(1.dp, MaterialTheme.ds.stone, RoundedCornerShape(8.dp))
                    .clickable(onClick = onDismiss).padding(horizontal = 18.dp),
                contentAlignment = Alignment.Center,
            ) { Text("Yoksay", color = MaterialTheme.ds.smoke, style = MaterialTheme.typography.labelMedium) }
        }
    }
}
