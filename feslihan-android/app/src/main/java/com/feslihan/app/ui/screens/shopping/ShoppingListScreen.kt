package com.feslihan.app.ui.screens.shopping

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.outlined.Circle
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
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.feslihan.app.data.model.ShoppingItem
import com.feslihan.app.ui.components.FeslihanCard
import com.feslihan.app.ui.components.FeslihanTopBar
import com.feslihan.app.ui.theme.ds

/**
 * Alışveriş Listesi (iOS ShoppingListView). Check/uncheck, remove, quick-add.
 * Checked items drop to the bottom with a strikethrough.
 */
@Composable
fun ShoppingListScreen(onBack: () -> Unit, viewModel: ShoppingListViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var newItem by remember { mutableStateOf("") }

    Scaffold(
        containerColor = MaterialTheme.ds.cream,
        topBar = { FeslihanTopBar(title = "Alışveriş Listesi", onBack = onBack) },
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding).padding(horizontal = 20.dp)) {
            OutlinedTextField(
                value = newItem,
                onValueChange = { newItem = it },
                placeholder = { Text("Malzeme ekle…") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = {
                    viewModel.add(newItem); newItem = ""
                }),
            )

            Box(modifier = Modifier.fillMaxSize()) {
                when {
                    state.isLoading -> CircularProgressIndicator(
                        color = MaterialTheme.ds.ember,
                        modifier = Modifier.align(Alignment.Center),
                    )
                    state.items.isEmpty() -> Text(
                        text = state.error ?: "Liste boş. Malzeme ekleyerek başla.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.ds.smoke,
                        modifier = Modifier.align(Alignment.Center),
                    )
                    else -> {
                        val sorted = state.items.sortedBy { it.isChecked }
                        LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            items(sorted, key = { it.id }) { item ->
                                ShoppingRow(
                                    item = item,
                                    onToggle = { viewModel.toggle(item) },
                                    onRemove = { viewModel.remove(item) },
                                )
                            }
                            item { androidx.compose.foundation.layout.Spacer(Modifier.padding(bottom = 24.dp)) }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ShoppingRow(item: ShoppingItem, onToggle: () -> Unit, onRemove: () -> Unit) {
    FeslihanCard(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onToggle) {
                Icon(
                    imageVector = if (item.isChecked) Icons.Default.CheckCircle else Icons.Outlined.Circle,
                    contentDescription = if (item.isChecked) "İşareti kaldır" else "İşaretle",
                    tint = if (item.isChecked) MaterialTheme.ds.ember else MaterialTheme.ds.dust,
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = item.ingredientName,
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (item.isChecked) MaterialTheme.ds.dust else MaterialTheme.ds.ink,
                    textDecoration = if (item.isChecked) TextDecoration.LineThrough else null,
                )
                item.pantryAlternative?.let {
                    Text(
                        text = "Kilerinde var: $it",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.ds.honeyInk,
                    )
                }
            }
            IconButton(onClick = onRemove) {
                Icon(Icons.Default.Delete, contentDescription = "Sil", tint = MaterialTheme.ds.dust)
            }
        }
    }
}
