package com.feslihan.app.ui.screens.shopping

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
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
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
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.feslihan.app.data.model.ShoppingItem
import com.feslihan.app.ui.components.BackButton
import com.feslihan.app.ui.theme.DisplayXLTextStyle
import com.feslihan.app.ui.theme.ds

/**
 * Alışveriş Listesi (iOS ScrShopping). "Alınacaklar" and "Alınanlar" card
 * sections; circular check toggles, inline add row, and clear-purchased action.
 */
@Composable
fun ShoppingListScreen(onBack: () -> Unit, viewModel: ShoppingListViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var newItem by remember { mutableStateOf("") }

    Scaffold(containerColor = MaterialTheme.ds.cream) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding).padding(horizontal = 22.dp)) {
            Spacer(Modifier.height(6.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                BackButton(onClick = onBack)
                Spacer(Modifier.size(4.dp))
                Text("Alışveriş Listesi", style = DisplayXLTextStyle.copy(fontSize = 28.sp), color = MaterialTheme.ds.ink)
            }
            Spacer(Modifier.height(14.dp))

            when {
                state.isLoading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = MaterialTheme.ds.ember)
                }
                else -> {
                    val toBuy = state.items.filterNot { it.isChecked }
                    val bought = state.items.filter { it.isChecked }
                    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
                        SectionHeader("Alınacaklar", "${toBuy.size} ürün")
                        Card {
                            toBuy.forEachIndexed { i, item ->
                                ShopRow(item, onToggle = { viewModel.toggle(item) })
                                if (i < toBuy.size) Divider()
                            }
                            AddRow(value = newItem, onChange = { newItem = it },
                                onSubmit = { if (newItem.isNotBlank()) { viewModel.add(newItem); newItem = "" } })
                        }

                        if (bought.isNotEmpty()) {
                            Spacer(Modifier.height(22.dp))
                            SectionHeader("Alınanlar", "${bought.size} ürün")
                            Card {
                                bought.forEachIndexed { i, item ->
                                    ShopRow(item, onToggle = { viewModel.toggle(item) })
                                    if (i < bought.size - 1) Divider()
                                }
                            }
                            Text(
                                "Alınanları temizle",
                                style = MaterialTheme.typography.labelLarge,
                                color = MaterialTheme.ds.ember,
                                modifier = Modifier.fillMaxWidth().padding(top = 16.dp).clickable { viewModel.clearChecked() },
                                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                            )
                        }

                        if (state.items.isEmpty()) {
                            Box(Modifier.fillMaxWidth().padding(top = 80.dp), contentAlignment = Alignment.Center) {
                                Text(state.error ?: "Liste boş. Ürün ekleyerek başla.",
                                    style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.smoke)
                            }
                        }
                        Spacer(Modifier.height(24.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun SectionHeader(title: String, count: String) {
    Row(modifier = Modifier.fillMaxWidth().padding(bottom = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(title, style = MaterialTheme.typography.titleLarge.copy(fontSize = 15.sp), color = MaterialTheme.ds.smoke, modifier = Modifier.weight(1f))
        Text(count, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.ds.dust)
    }
}

@Composable
private fun Card(content: @Composable () -> Unit) {
    Column(
        modifier = Modifier.fillMaxWidth()
            .border(1.dp, MaterialTheme.ds.stone, RoundedCornerShape(8.dp))
            .padding(horizontal = 16.dp),
    ) { content() }
}

@Composable
private fun Divider() {
    Box(Modifier.fillMaxWidth().height(1.dp).background(MaterialTheme.ds.stone))
}

@Composable
private fun ShopRow(item: ShoppingItem, onToggle: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().height(48.dp).clickable(onClick = onToggle),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier.size(24.dp)
                .background(if (item.isChecked) MaterialTheme.ds.ember else Color.Transparent, CircleShape)
                .then(if (!item.isChecked) Modifier.border(2.dp, MaterialTheme.ds.stone, CircleShape) else Modifier),
            contentAlignment = Alignment.Center,
        ) {
            if (item.isChecked) Icon(Icons.Default.Check, contentDescription = null, tint = Color.White, modifier = Modifier.size(14.dp))
        }
        Column(modifier = Modifier.weight(1f).padding(start = 13.dp)) {
            Text(
                item.ingredientName,
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold),
                color = if (item.isChecked) MaterialTheme.ds.dust else MaterialTheme.ds.ink,
                textDecoration = if (item.isChecked) TextDecoration.LineThrough else null,
            )
            item.pantryAlternative?.let {
                Text("Kilerinde var: $it", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.ds.honeyInk)
            }
        }
    }
}

@Composable
private fun AddRow(value: String, onChange: (String) -> Unit, onSubmit: () -> Unit) {
    Row(modifier = Modifier.fillMaxWidth().height(48.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier.size(24.dp).border(2.dp, MaterialTheme.ds.stone, CircleShape),
            contentAlignment = Alignment.Center,
        ) { Icon(Icons.Default.Add, contentDescription = null, tint = MaterialTheme.ds.dust, modifier = Modifier.size(14.dp)) }
        Box(modifier = Modifier.weight(1f).padding(start = 13.dp)) {
            if (value.isEmpty()) Text("Ürün ekle…", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.dust)
            BasicTextField(
                value = value, onValueChange = onChange, singleLine = true,
                textStyle = MaterialTheme.typography.bodyMedium.copy(color = MaterialTheme.ds.ink),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = { onSubmit() }),
                cursorBrush = SolidColor(MaterialTheme.ds.ember),
            )
        }
    }
}
