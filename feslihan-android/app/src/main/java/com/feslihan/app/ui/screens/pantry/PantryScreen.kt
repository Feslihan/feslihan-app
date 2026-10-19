package com.feslihan.app.ui.screens.pantry

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.feslihan.app.data.model.PantryItem
import com.feslihan.app.ui.components.Chip
import com.feslihan.app.ui.theme.DisplayXLTextStyle
import com.feslihan.app.ui.components.BackButton
import com.feslihan.app.ui.theme.ds

/**
 * Kilerim (iOS ScrPantry). Oversized title + count chip, search field, and a
 * flowing cloud of ingredient "bubbles". Tap a bubble to remove; the floating
 * "Ekle" pill reveals the add field. API has no category metadata, so items
 * render as one cloud (design groups by category illustratively).
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun PantryScreen(onBack: () -> Unit, viewModel: PantryViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var query by remember { mutableStateOf("") }
    var adding by remember { mutableStateOf(false) }
    var newItem by remember { mutableStateOf("") }

    Scaffold(containerColor = MaterialTheme.ds.cream) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            Column(modifier = Modifier.fillMaxSize().padding(horizontal = 22.dp)) {
                Spacer(Modifier.height(6.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    BackButton(onClick = onBack)
                    Spacer(Modifier.size(4.dp))
                    Text("Kilerim", style = DisplayXLTextStyle.copy(fontSize = 30.sp), color = MaterialTheme.ds.ink)
                    Spacer(Modifier.size(10.dp))
                    Chip(text = "${state.items.size} malzeme", soft = true)
                }
                Spacer(Modifier.height(12.dp))
                SearchField(query = query, onChange = { query = it })
                Spacer(Modifier.height(20.dp))

                when {
                    state.isLoading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = MaterialTheme.ds.ember)
                    }
                    state.items.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text(state.error ?: "Kilerin boş. Evdeki malzemeleri ekle.",
                            style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.smoke)
                    }
                    else -> {
                        val filtered = state.items.filter {
                            query.isBlank() || it.ingredientName.contains(query, ignoreCase = true)
                        }
                        FlowRow(
                            modifier = Modifier.fillMaxWidth().verticalScroll(rememberScrollState()),
                            horizontalArrangement = Arrangement.spacedBy(9.dp),
                            verticalArrangement = Arrangement.spacedBy(9.dp),
                        ) {
                            filtered.forEach { item -> RemovableBubble(item = item, onRemove = { viewModel.remove(item) }) }
                            Spacer(Modifier.height(90.dp))
                        }
                    }
                }
            }

            // Floating "Ekle" pill
            Box(
                modifier = Modifier.align(Alignment.BottomEnd).padding(20.dp)
                    .background(MaterialTheme.ds.ember, RoundedCornerShape(26.dp))
                    .clickable { adding = true }
                    .padding(horizontal = 22.dp, vertical = 14.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Add, contentDescription = null, tint = Color.White, modifier = Modifier.size(22.dp))
                    Spacer(Modifier.size(6.dp))
                    Text("Ekle", color = Color.White, style = MaterialTheme.typography.labelMedium)
                }
            }

            if (adding) {
                AddBubbleField(
                    value = newItem,
                    onChange = { newItem = it },
                    onSubmit = { if (newItem.isNotBlank()) { viewModel.add(newItem); newItem = "" }; adding = false },
                    onDismiss = { adding = false },
                )
            }
        }
    }
}

@Composable
private fun RemovableBubble(item: PantryItem, onRemove: () -> Unit) {
    Row(
        modifier = Modifier
            .background(MaterialTheme.ds.ember, CircleShape)
            .clickable(onClick = onRemove)
            .padding(start = 16.dp, end = 10.dp, top = 9.dp, bottom = 9.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(item.ingredientName, color = Color.White, style = MaterialTheme.typography.labelLarge)
        Spacer(Modifier.size(6.dp))
        Icon(Icons.Default.Close, contentDescription = "Çıkar", tint = Color.White.copy(alpha = 0.85f), modifier = Modifier.size(14.dp))
    }
}

@Composable
private fun SearchField(query: String, onChange: (String) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().height(46.dp)
            .border(1.dp, MaterialTheme.ds.stone, RoundedCornerShape(8.dp)).padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Default.Search, contentDescription = null, tint = MaterialTheme.ds.dust, modifier = Modifier.size(18.dp))
        Spacer(Modifier.size(10.dp))
        Box(Modifier.fillMaxWidth()) {
            if (query.isEmpty()) Text("Malzeme ara...", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.dust)
            BasicTextField(value = query, onValueChange = onChange, singleLine = true,
                textStyle = MaterialTheme.typography.bodyMedium.copy(color = MaterialTheme.ds.ink),
                cursorBrush = androidx.compose.ui.graphics.SolidColor(MaterialTheme.ds.ember))
        }
    }
}

@Composable
private fun AddBubbleField(value: String, onChange: (String) -> Unit, onSubmit: () -> Unit, onDismiss: () -> Unit) {
    Box(
        modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.3f)).clickable(onClick = onDismiss),
        contentAlignment = Alignment.BottomCenter,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().background(MaterialTheme.ds.cream).padding(22.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Row(
                modifier = Modifier.weight(1f).height(46.dp)
                    .border(1.dp, MaterialTheme.ds.ink, RoundedCornerShape(8.dp)).padding(horizontal = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(Modifier.fillMaxWidth()) {
                    if (value.isEmpty()) Text("Malzeme ekle…", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.dust)
                    BasicTextField(value = value, onValueChange = onChange, singleLine = true,
                        textStyle = MaterialTheme.typography.bodyMedium.copy(color = MaterialTheme.ds.ink),
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                        keyboardActions = KeyboardActions(onDone = { onSubmit() }),
                        cursorBrush = androidx.compose.ui.graphics.SolidColor(MaterialTheme.ds.ember))
                }
            }
            Spacer(Modifier.size(10.dp))
            Box(
                modifier = Modifier.size(46.dp).background(MaterialTheme.ds.ember, RoundedCornerShape(8.dp)).clickable(onClick = onSubmit),
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Default.Add, contentDescription = "Ekle", tint = Color.White) }
        }
    }
}
