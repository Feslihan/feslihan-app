package com.feslihan.app.ui.screens.pantry

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.feslihan.app.data.model.PantryItem
import com.feslihan.app.ui.components.FeslihanCard
import com.feslihan.app.ui.components.FeslihanTopBar
import com.feslihan.app.ui.theme.ds

/** Kilerim (iOS PantryView). Inventory of what's at home; add/remove items. */
@Composable
fun PantryScreen(onBack: () -> Unit, viewModel: PantryViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var newItem by remember { mutableStateOf("") }

    Scaffold(
        containerColor = MaterialTheme.ds.cream,
        topBar = { FeslihanTopBar(title = "Kilerim", onBack = onBack) },
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding).padding(horizontal = 20.dp)) {
            OutlinedTextField(
                value = newItem,
                onValueChange = { newItem = it },
                placeholder = { Text("Malzeme ekle…") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = { viewModel.add(newItem); newItem = "" }),
            )

            Box(modifier = Modifier.fillMaxSize()) {
                when {
                    state.isLoading -> CircularProgressIndicator(
                        color = MaterialTheme.ds.ember,
                        modifier = Modifier.align(Alignment.Center),
                    )
                    state.items.isEmpty() -> Text(
                        text = state.error ?: "Kilerin boş. Evdeki malzemeleri ekle.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.ds.smoke,
                        modifier = Modifier.align(Alignment.Center),
                    )
                    else -> LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        items(state.items, key = { it.id }) { item ->
                            PantryRow(item = item, onRemove = { viewModel.remove(item) })
                        }
                        item { Spacer(Modifier.padding(bottom = 24.dp)) }
                    }
                }
            }
        }
    }
}

@Composable
private fun PantryRow(item: PantryItem, onRemove: () -> Unit) {
    FeslihanCard(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(start = 16.dp, top = 6.dp, bottom = 6.dp, end = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = item.ingredientName,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.ds.ink,
                modifier = Modifier.weight(1f),
            )
            IconButton(onClick = onRemove) {
                Icon(Icons.Default.Close, contentDescription = "Kilerden çıkar", tint = MaterialTheme.ds.dust)
            }
        }
    }
}
